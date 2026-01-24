/// ---------------------------------------------------------------------------
/// File: lib/services/insights_service.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Insights screens and cron-like jobs that need weekly summaries stored.
///
/// Purpose:
///   - Generates weekly insight reports, stores them, and offers helpers to
///     fetch historical data or inspect a specific week.
///
/// Inputs:
///   - Reads budgets, transactions, goals, and progress logs from repositories.
///
/// Outputs:
///   - `WeeklyInsightsReport` objects and supporting aggregates.
/// ---------------------------------------------------------------------------
import 'dart:math' as math;

import 'package:bfm_app/models/budget_model.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/goal_progress_log.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/models/weekly_report.dart';
import 'package:bfm_app/models/weekly_overview_summary.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/repositories/weekly_report_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';

/// Builds and retrieves weekly insight reports.
class InsightsService {
  /// Creates a report for the current week, persists it, and returns the model.
  static Future<WeeklyInsightsReport> generateWeeklyReport() async {
    final period = _currentWeekPeriod();
    return generateReportForWeek(
      period.start,
      weekEnd: period.end,
      persist: true,
      usePreviousWeekIncome: true,
    );
  }

  /// Builds a weekly report for an arbitrary Monday start date.
  ///
  /// [weekStart] should point to the Monday for the desired week. When
  /// [weekEnd] is omitted the range defaults to a full 7-day window.
  /// Set [usePreviousWeekIncome] to `false` when you want income to reflect the
  /// same week (used by the Monday overview), otherwise it will fall back to
  /// the previous week so the current-week Insights screen doesn’t show partial
  /// income totals.
  static Future<WeeklyInsightsReport> generateReportForWeek(
    DateTime weekStart, {
    DateTime? weekEnd,
    bool persist = true,
    bool usePreviousWeekIncome = true,
  }) async {
    final normalizedStart = _normalizeDay(weekStart);
    final normalizedEnd = _normalizeDay(
      weekEnd ?? normalizedStart.add(const Duration(days: 6)),
    );
    final period = _WeekPeriod(start: normalizedStart, end: normalizedEnd);
    final comparisonPeriod =
        usePreviousWeekIncome ? _previousWeekPeriod(period.start) : period;

    final budgets = await BudgetRepository.getAll();
    final totalBudget =
        budgets.fold<double>(0, (sum, budget) => sum + budget.weeklyLimit);

    final spendMapAll =
        await TransactionRepository.sumExpensesByCategoryBetween(
      period.start,
      period.end,
    );
    final uncategorizedSpendMap =
        await TransactionRepository.sumExpensesByUncategorizedKeyBetween(
      period.start,
      period.end,
    );
    
    // Get all category names to identify the "Uncategorized" category
    final allCategoryNames =
        await CategoryRepository.getNamesByIds(spendMapAll.keys.whereType<int>());
    
    // Find spend assigned to the "Uncategorized" category (has category_id but name is "Uncategorized")
    double uncategorizedCategorySpend = 0.0;
    for (final entry in spendMapAll.entries) {
      if (entry.key == null) continue;
      final catName = allCategoryNames[entry.key];
      if (catName != null) {
        final nameLower = catName.toLowerCase();
        if (nameLower == 'uncategorized' || nameLower == 'uncategorised') {
          uncategorizedCategorySpend += entry.value.abs();
        }
      }
    }
    
    // Combine true uncategorized (null category_id) + "Uncategorized" category spend
    double remainingUncategorized = (spendMapAll[null]?.abs() ?? 0.0) + uncategorizedCategorySpend;
    final totalSpentAll =
        spendMapAll.values.fold<double>(0, (sum, value) => sum + value.abs());
    final actualWeekIncome = await TransactionRepository.sumIncomeBetween(
      period.start,
      period.end,
    );
    final displayIncome = await TransactionRepository.sumIncomeBetween(
      comparisonPeriod.start,
      comparisonPeriod.end,
    );

    final budgetCategoryIds = budgets
        .where((b) => b.categoryId != null)
        .map((b) => b.categoryId!)
        .toSet();
    final budgetCategoryNames =
        await CategoryRepository.getNamesByIds(budgetCategoryIds);
    final goalSpendMap =
        await GoalRepository.weeklyContributionTotals(period.start);

    // Load recurring transactions for budgets that reference them
    final recurringIds = budgets
        .map((b) => b.recurringTransactionId)
        .whereType<int>()
        .toSet();
    final recurringTransactions = await RecurringRepository.getByIds(recurringIds);
    final recurringById = <int, String>{};
    for (final rt in recurringTransactions) {
      if (rt.id != null && rt.description != null) {
        // Normalize the description the same way as uncategorizedSpendMap keys
        recurringById[rt.id!] = rt.description!.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }

    final List<CategoryWeeklySummary> categories = [];
    double budgetSpend = 0;
    double goalBudgetTotal = 0;
    double nonGoalBudgetTotal = 0;

    final uncategorizedKeys = <String>{
      ...budgets
          .map((b) => b.uncategorizedKey)
          .whereType<String>()
          .where((k) => k.isNotEmpty),
      // Also add normalized recurring transaction descriptions as potential keys
      ...recurringById.values,
      ...uncategorizedSpendMap.keys,
    };
    final uncategorizedNames =
        await TransactionRepository.getDisplayNamesForUncategorizedKeys(
      uncategorizedKeys,
      period.start,
      period.end,
    );
    final usedUncategorizedKeys = <String>{};
    var hasUncategorizedCatchAll = false;

    // Group budgets by category/key to avoid double-counting spend
    // Key format: "cat:{id}" for categories, "goal:{id}" for goals, "key:{key}" for uncategorized, "rec:{id}" for recurring
    final groupedBudgets = <String, ({String label, double budgetTotal, double spent, bool isGoal})>{};
    
    for (final budget in budgets) {
      String groupKey;
      String label;
      double spent = 0;
      bool isGoal = false;

      if (budget.categoryId != null) {
        final rawLabel = budgetCategoryNames[budget.categoryId!] ?? 'Category';
        final labelLower = rawLabel.toLowerCase();
        // If linked to "Uncategorized" category but has a recurring transaction,
        // treat it as an uncategorized budget using the recurring transaction's description
        if (labelLower == 'uncategorized' || labelLower == 'uncategorised') {
          if (budget.recurringTransactionId != null) {
            final recurringKey = recurringById[budget.recurringTransactionId!];
            if (recurringKey != null && recurringKey.isNotEmpty) {
              groupKey = 'rec:${budget.recurringTransactionId}';
              label = _uncategorizedDisplayLabel(recurringKey, uncategorizedNames);
              spent = uncategorizedSpendMap[recurringKey] ?? 0.0;
              usedUncategorizedKeys.add(recurringKey);
              remainingUncategorized = math.max(remainingUncategorized - spent, 0.0);
            } else {
              continue; // No description to match
            }
          } else {
            continue; // Skip non-recurring uncategorized category budgets
          }
        } else {
          groupKey = 'cat:${budget.categoryId}';
          label = rawLabel;
          spent = spendMapAll[budget.categoryId]?.abs() ?? 0.0;
        }
      } else if (budget.goalId != null) {
        final rawLabel = (budget.label ?? 'Goal').trim();
        groupKey = 'goal:${budget.goalId}';
        label = rawLabel.isEmpty ? 'Goal' : rawLabel;
        spent = goalSpendMap[budget.goalId!] ?? 0.0;
        isGoal = true;
      } else if (budget.recurringTransactionId != null) {
        // Handle recurring transaction budgets
        final recurringKey = recurringById[budget.recurringTransactionId!];
        if (recurringKey != null && recurringKey.isNotEmpty) {
          groupKey = 'rec:${budget.recurringTransactionId}';
          label = _uncategorizedDisplayLabel(recurringKey, uncategorizedNames);
          spent = uncategorizedSpendMap[recurringKey] ?? 0.0;
          usedUncategorizedKeys.add(recurringKey);
          remainingUncategorized = math.max(remainingUncategorized - spent, 0.0);
        } else {
          // Recurring transaction doesn't have a description, skip
          continue;
        }
      } else {
        label = _uncategorizedLabelForBudget(budget, uncategorizedNames);
        final key = budget.uncategorizedKey;
        if (key != null && key.isNotEmpty) {
          groupKey = 'key:$key';
          // Always use the display label for better names
          label = _uncategorizedDisplayLabel(key, uncategorizedNames);
          spent = uncategorizedSpendMap[key] ?? 0.0;
          usedUncategorizedKeys.add(key);
          remainingUncategorized =
              math.max(remainingUncategorized - spent, 0.0);
        } else {
          // Skip budgets with no specific uncategorized key - they're catch-all placeholders
          final labelLower = label.toLowerCase();
          if (labelLower == 'uncategorized' || 
              labelLower == 'uncategorised' || 
              labelLower == 'other transaction') {
            continue;
          }
          groupKey = 'catch:all';
          spent = remainingUncategorized;
          remainingUncategorized = 0.0;
          hasUncategorizedCatchAll = true;
        }
      }

      // Group budgets: combine budget limits, but keep spent the same (it's the same transactions)
      final existing = groupedBudgets[groupKey];
      if (existing != null) {
        groupedBudgets[groupKey] = (
          label: existing.label,
          budgetTotal: existing.budgetTotal + budget.weeklyLimit,
          spent: existing.spent, // Don't double-count spend
          isGoal: existing.isGoal,
        );
      } else {
        groupedBudgets[groupKey] = (
          label: label,
          budgetTotal: budget.weeklyLimit,
          spent: spent,
          isGoal: isGoal,
        );
      }
    }
    
    // Now create category summaries from grouped data
    for (final entry in groupedBudgets.entries) {
      final data = entry.value;
      categories.add(
        CategoryWeeklySummary(
          label: data.label,
          budget: data.budgetTotal,
          spent: data.spent,
        ),
      );
      budgetSpend += data.spent;

      if (data.isGoal) {
        goalBudgetTotal += data.budgetTotal;
      } else {
        nonGoalBudgetTotal += data.budgetTotal;
      }
    }

    if (!hasUncategorizedCatchAll) {
      double unbudgetedUncategorizedTotal = 0.0;
      for (final entry in uncategorizedSpendMap.entries) {
        if (usedUncategorizedKeys.contains(entry.key)) continue;
        if (entry.value <= 0) continue;
        final label = _uncategorizedDisplayLabel(entry.key, uncategorizedNames);
        categories.add(
          CategoryWeeklySummary(
            label: label,
            budget: 0,
            spent: entry.value,
          ),
        );
        budgetSpend += entry.value;
        unbudgetedUncategorizedTotal += entry.value;
      }
      remainingUncategorized =
          math.max(remainingUncategorized - unbudgetedUncategorizedTotal, 0.0);
      // Only add remainder if it's significant (more than 1 cent to avoid floating point errors)
      if (remainingUncategorized > 0.01) {
        categories.add(
          CategoryWeeklySummary(
            label: 'Other Uncategorized',
            budget: 0,
            spent: remainingUncategorized,
          ),
        );
        budgetSpend += remainingUncategorized;
        remainingUncategorized = 0.0;
      }
    }

    categories.sort((a, b) => b.spent.compareTo(a.spent));

    final topCategories = _mapTopCategories(
      spendMapAll,
      allCategoryNames,
      uncategorizedSpendMap: uncategorizedSpendMap,
      uncategorizedNames: uncategorizedNames,
    );

    final metBudget = totalBudget > 0 ? budgetSpend <= totalBudget : false;
    final hasLeftover = (actualWeekIncome - totalSpentAll) > 0.01;

    const autoCreditEnabled = false;
    final goalOutcomes = await _evaluateGoalProgress(
      weekStart: period.start,
      hasLeftover: hasLeftover,
      autoCreditEnabled: autoCreditEnabled,
    );

    final goalSpend =
        goalSpendMap.values.fold<double>(0, (sum, value) => sum + value);
    double nonGoalSpend = totalSpentAll - goalSpend;
    if (nonGoalSpend.isNaN || nonGoalSpend < 0) nonGoalSpend = 0.0;

    final discretionaryBudget = actualWeekIncome - nonGoalBudgetTotal;
    final discretionaryLeft = discretionaryBudget - nonGoalSpend;

    // Calculate leftToSpend matching the dashboard formula:
    // (income - totalBudgets) - discretionarySpend
    // Where discretionarySpend = overages for budgeted categories + full spend for non-budgeted
    // Use displayIncome (previous week when usePreviousWeekIncome=true) to match dashboard
    final discretionarySpend = await _calculateDiscretionarySpend(
      period.start,
      period.end,
      budgets,
    );
    final leftToSpend = (displayIncome - totalBudget) - discretionarySpend;

    final overviewSummary = WeeklyOverviewSummary(
      weekStart: period.start,
      weekEnd: period.end,
      incomeForWeek: actualWeekIncome,
      nonGoalBudgetTotal: nonGoalBudgetTotal,
      goalBudgetTotal: goalBudgetTotal,
      nonGoalSpend: nonGoalSpend,
      goalSpend: goalSpend,
      discretionaryBudget: discretionaryBudget,
      discretionaryLeft: discretionaryLeft,
      leftToSpend: leftToSpend,
    );

    final report = WeeklyInsightsReport(
      weekStart: period.start,
      weekEnd: period.end,
      categories: categories,
      topCategories: topCategories,
      totalBudget: totalBudget,
      totalSpent: totalSpentAll,
      totalIncome: displayIncome,
      metBudget: metBudget,
      goalOutcomes: goalOutcomes,
      overviewSummary: overviewSummary,
    );

    if (persist) {
      await WeeklyReportRepository.upsert(report);
    }
    return report;
  }

  /// Returns the Monday→today window for the current week.
  static _WeekPeriod _currentWeekPeriod() {
    final now = DateTime.now();
    final today = _normalizeDay(now);
    final start = today.subtract(Duration(days: today.weekday - 1));
    return _WeekPeriod(start: start, end: today);
  }

  /// Returns the full week window preceding `currentWeekStart`.
  static _WeekPeriod _previousWeekPeriod(DateTime currentWeekStart) {
    final end = currentWeekStart.subtract(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 6));
    return _WeekPeriod(start: start, end: end);
  }

  /// Reads every stored report entry for history views.
  static Future<List<WeeklyReportEntry>> getSavedReports() async {
    return WeeklyReportRepository.getAll();
  }

  /// Returns all transactions in the week following `weekStart`.
  static Future<List<TransactionModel>> getTransactionsForWeek(
      DateTime weekStart) async {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 6));
    return TransactionRepository.getBetween(start, end);
  }

  /// Determines per-goal outcomes for the week, optionally crediting
  /// contributions when there is leftover cash.
  static Future<List<GoalWeeklyOutcome>> _evaluateGoalProgress({
    required DateTime weekStart,
    required bool hasLeftover,
    required bool autoCreditEnabled,
  }) async {
    final goals = await GoalRepository.getAll();
    if (goals.isEmpty) return const [];

    final logs = <int, GoalProgressLog>{};
    for (final goal in goals) {
      final id = goal.id;
      if (id == null) continue;
      final shouldCredit = autoCreditEnabled &&
          hasLeftover &&
          goal.weeklyContribution > 0 &&
          !goal.isComplete;
      final log = await GoalRepository.recordWeeklyOutcome(
        goal: goal,
        weekStart: weekStart,
        credited: shouldCredit,
        amount: shouldCredit ? goal.weeklyContribution : 0,
        note: shouldCredit
            ? 'Budgets met – contribution applied.'
            : 'Automatic goal contributions are disabled. Update goals manually if needed.',
      );
      logs[id] = log;
    }

    final refreshed = await GoalRepository.getAll();
    final refreshedMap = <int, GoalModel>{};
    for (final goal in refreshed) {
      if (goal.id != null) {
        refreshedMap[goal.id!] = goal;
      }
    }

    final outcomes = <GoalWeeklyOutcome>[];
    for (final original in goals) {
      final id = original.id;
      if (id == null) continue;
      final log = logs[id];
      final displayGoal = refreshedMap[id] ?? original;
      outcomes.add(
        GoalWeeklyOutcome(
          goal: displayGoal,
          credited: log?.credited ?? false,
          amountDelta: log?.amount ?? 0,
          message: _goalMessage(
            displayGoal,
            log,
            hasLeftover,
            autoCreditEnabled,
          ),
        ),
      );
    }
    return outcomes;
  }

  /// Converts the spend map into sorted summaries for the report.
  static List<CategoryWeeklySummary> _mapTopCategories(
    Map<int?, double> spendMap,
    Map<int, String> categoryNames, {
    Map<String, double> uncategorizedSpendMap = const {},
    Map<String, String> uncategorizedNames = const {},
  }) {
    final list = <CategoryWeeklySummary>[];
    final uncategorizedTotal = spendMap[null]?.abs() ?? 0.0;
    double uncategorizedMapped = 0.0;
    // Track spend from the "Uncategorized" category to merge with true uncategorized
    double uncategorizedCategorySpend = 0.0;
    spendMap.forEach((categoryId, spent) {
      if (categoryId == null) return;
      final rawLabel = categoryNames[categoryId] ?? 'Category';
      final labelLower = rawLabel.toLowerCase();
      // Skip the "Uncategorized" category - its spend will be merged into uncategorized items
      if (labelLower == 'uncategorized' || labelLower == 'uncategorised') {
        uncategorizedCategorySpend += spent.abs();
        return;
      }
      list.add(CategoryWeeklySummary(
        label: rawLabel,
        budget: spent.abs(),
        spent: spent.abs(),
      ));
    });
    for (final entry in uncategorizedSpendMap.entries) {
      if (entry.value <= 0) continue;
      list.add(
        CategoryWeeklySummary(
          label: _uncategorizedDisplayLabel(entry.key, uncategorizedNames),
          budget: entry.value.abs(),
          spent: entry.value.abs(),
        ),
      );
      uncategorizedMapped += entry.value.abs();
    }
    // Combine true uncategorized + "Uncategorized" category spend
    final totalUncategorizedRemaining = uncategorizedTotal + uncategorizedCategorySpend;
    final uncategorizedRemaining =
        math.max(totalUncategorizedRemaining - uncategorizedMapped, 0.0);
    // Only add remainder if it's significant (more than 1 cent to avoid floating point errors)
    if (uncategorizedRemaining > 0.01) {
      list.add(CategoryWeeklySummary(
        label: 'Other Transactions',
        budget: uncategorizedRemaining,
        spent: uncategorizedRemaining,
      ));
    }
    list.sort((a, b) => b.spent.compareTo(a.spent));
    return list;
  }

  /// Builds a friendly message explaining the credit outcome for a goal.
  static String _goalMessage(GoalModel goal, GoalProgressLog? log,
      bool hasLeftover, bool autoCreditEnabled) {
    if (goal.isComplete) {
      return "${goal.name} is already complete!";
    }
    if (log != null && log.credited && log.amount > 0) {
      return "Congrats! \$${log.amount.toStringAsFixed(2)} added to ${goal.name}.";
    }
    if (!autoCreditEnabled) {
      return "Automatic contributions are turned off. Manage ${goal.name} manually.";
    }
    if (!hasLeftover) {
      return "${goal.name} wasn't topped up because no money was left over.";
    }
    if (goal.weeklyContribution <= 0) {
      return "Set a weekly contribution to grow ${goal.name}.";
    }
    return "No contribution was applied to ${goal.name} this week.";
  }

  /// Calculates discretionary spend matching the dashboard formula:
  /// - For budgeted categories: only count overages (spend - budget, if > 0)
  /// - For non-budgeted/uncategorized: count full amount
  static Future<double> _calculateDiscretionarySpend(
    DateTime start,
    DateTime end,
    List<BudgetModel> budgets,
  ) async {
    // Build a map of category_id -> weekly budget limit
    final budgetsByCategory = <int, double>{};
    for (final budget in budgets) {
      final catId = budget.categoryId;
      if (catId != null) {
        budgetsByCategory[catId] =
            (budgetsByCategory[catId] ?? 0.0) + budget.weeklyLimit;
      }
    }

    // Get spend grouped by category for the period
    final spendByCategory =
        await TransactionRepository.sumExpensesByCategoryBetween(start, end);

    double discretionary = 0.0;
    for (final entry in spendByCategory.entries) {
      final catId = entry.key;
      final spent = entry.value.abs();

      if (catId == null || !budgetsByCategory.containsKey(catId)) {
        // Non-budgeted or uncategorized: count full amount
        discretionary += spent;
      } else {
        // Budgeted category: only count overage
        final budget = budgetsByCategory[catId] ?? 0.0;
        final overage = math.max(spent - budget, 0.0);
        discretionary += overage;
      }
    }

    return discretionary;
  }

}

/// Convenience date tuple capturing a week’s start/end bounds.
class _WeekPeriod {
  final DateTime start;
  final DateTime end;
  const _WeekPeriod({required this.start, required this.end});
}

DateTime _normalizeDay(DateTime input) =>
    DateTime(input.year, input.month, input.day);

String _uncategorizedLabelForBudget(
  BudgetModel budget,
  Map<String, String> nameByKey,
) {
  final custom = (budget.label ?? '').trim();
  final customLower = custom.toLowerCase();
  if (custom.isNotEmpty && 
      customLower != 'uncategorized' && 
      customLower != 'uncategorised') {
    return custom;
  }
  final key = budget.uncategorizedKey;
  if (key != null && key.isNotEmpty) {
    final keyLower = key.trim().toLowerCase();
    // Skip if the key itself is just "uncategorized"
    if (keyLower != 'uncategorized' && keyLower != 'uncategorised') {
      final friendly = nameByKey[key];
      if (friendly != null && friendly.trim().isNotEmpty) {
        final friendlyLower = friendly.trim().toLowerCase();
        if (friendlyLower != 'uncategorized' && friendlyLower != 'uncategorised') {
          return friendly.trim();
        }
      }
      // Fall back to title-casing the key itself
      final words = key.trim().split(' ');
      final titled = words.map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');
      if (titled.isNotEmpty) {
        return titled;
      }
    }
  }
  return 'Other Transaction';
}

String _uncategorizedDisplayLabel(
  String key,
  Map<String, String> nameByKey,
) {
  // Handle the unnamed transaction placeholder
  if (key == '_unnamed_transaction') {
    return 'Unnamed Transaction';
  }
  final friendly = nameByKey[key];
  if (friendly != null && friendly.trim().isNotEmpty) {
    final friendlyLower = friendly.trim().toLowerCase();
    // Don't return "Uncategorized" as a label - use a more descriptive fallback
    if (friendlyLower != 'uncategorized' && friendlyLower != 'uncategorised') {
      return friendly.trim();
    }
  }
  // Fall back to the key itself (now preserves original description) if no mapping found
  if (key.trim().isNotEmpty) {
    final keyLower = key.trim().toLowerCase();
    // Skip if the key itself is just "uncategorized"
    if (keyLower != 'uncategorized' && keyLower != 'uncategorised') {
      // Title case the key for display
      final words = key.trim().split(' ');
      final titled = words.map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');
      return titled;
    }
  }
  return 'Other Transaction';
}