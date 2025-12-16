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
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/goal_progress_log.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/models/weekly_report.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/weekly_report_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';

/// Builds and retrieves weekly insight reports.
class InsightsService {
  /// Creates a report for the current week, persists it, and returns the model.
  static Future<WeeklyInsightsReport> generateWeeklyReport() async {
    final period = _currentWeekPeriod();
    final lastWeek = _previousWeekPeriod(period.start);
    final budgets = await BudgetRepository.getAll();
    final totalBudget =
        budgets.fold<double>(0, (sum, budget) => sum + budget.weeklyLimit);

    final spendMapAll =
        await TransactionRepository.sumExpensesByCategoryBetween(
      period.start,
      period.end,
    );
    final totalSpentAll =
        spendMapAll.values.fold<double>(0, (sum, value) => sum + value.abs());
    final currentWeekIncome = await TransactionRepository.sumIncomeBetween(
      period.start,
      period.end,
    );
    final lastWeekIncome = await TransactionRepository.sumIncomeBetween(
      lastWeek.start,
      lastWeek.end,
    );

    final budgetCategoryIds = budgets
        .where((b) => b.categoryId != null)
        .map((b) => b.categoryId!)
        .toSet();
    final budgetCategoryNames =
        await CategoryRepository.getNamesByIds(budgetCategoryIds);
    final allCategoryNames =
        await CategoryRepository.getNamesByIds(spendMapAll.keys.whereType<int>());
    final goalSpendMap =
        await GoalRepository.weeklyContributionTotals(period.start);

    final List<CategoryWeeklySummary> categories = [];
    double budgetSpend = 0;

    for (final budget in budgets) {
      String label;
      double spent = 0;

      if (budget.categoryId != null) {
        label = budgetCategoryNames[budget.categoryId!] ?? 'Category';
        spent = spendMapAll[budget.categoryId]?.abs() ?? 0.0;
      } else if (budget.goalId != null) {
        final rawLabel = (budget.label ?? 'Goal').trim();
        label = rawLabel.isEmpty ? 'Goal' : rawLabel;
        spent = goalSpendMap[budget.goalId!] ?? 0.0;
      } else {
        label = 'Budget';
      }

      categories.add(
        CategoryWeeklySummary(
          label: label,
          budget: budget.weeklyLimit,
          spent: spent,
        ),
      );
      budgetSpend += spent;
    }

    categories.sort((a, b) => b.spent.compareTo(a.spent));

    final topCategories = _mapTopCategories(
      spendMapAll,
      allCategoryNames,
    );

    final metBudget = totalBudget > 0 ? budgetSpend <= totalBudget : false;
    final hasLeftover = (currentWeekIncome - totalSpentAll) > 0.01;

    final goalOutcomes = await _evaluateGoalProgress(
      weekStart: period.start,
      hasLeftover: hasLeftover,
    );

    final report = WeeklyInsightsReport(
      weekStart: period.start,
      weekEnd: period.end,
      categories: categories,
      topCategories: topCategories,
      totalBudget: totalBudget,
      totalSpent: totalSpentAll,
      totalIncome: lastWeekIncome,
      metBudget: metBudget,
      goalOutcomes: goalOutcomes,
    );
    await WeeklyReportRepository.upsert(report);
    return report;
  }

  /// Returns the Monday→today window for the current week.
  static _WeekPeriod _currentWeekPeriod() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
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
  }) async {
    final goals = await GoalRepository.getAll();
    if (goals.isEmpty) return const [];

    final logs = <int, GoalProgressLog>{};
    for (final goal in goals) {
      final id = goal.id;
      if (id == null) continue;
      final shouldCredit =
          hasLeftover && goal.weeklyContribution > 0 && !goal.isComplete;
      final log = await GoalRepository.recordWeeklyOutcome(
        goal: goal,
        weekStart: weekStart,
        credited: shouldCredit,
        amount: goal.weeklyContribution,
        note: shouldCredit
            ? 'Budgets met – contribution applied.'
            : 'Budgets not met or contribution disabled.',
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
          message: _goalMessage(displayGoal, log, hasLeftover),
        ),
      );
    }
    return outcomes;
  }

  /// Converts the spend map into sorted summaries for the report.
  static List<CategoryWeeklySummary> _mapTopCategories(
    Map<int?, double> spendMap,
    Map<int, String> categoryNames,
  ) {
    final list = <CategoryWeeklySummary>[];
    spendMap.forEach((categoryId, spent) {
      final label = categoryId == null
          ? 'Uncategorized'
          : (categoryNames[categoryId] ?? 'Category');
      list.add(CategoryWeeklySummary(
        label: label,
        budget: spent.abs(),
        spent: spent.abs(),
      ));
    });
    list.sort((a, b) => b.spent.compareTo(a.spent));
    return list;
  }

  /// Builds a friendly message explaining the credit outcome for a goal.
  static String _goalMessage(
      GoalModel goal, GoalProgressLog? log, bool hasLeftover) {
    if (goal.isComplete) {
      return "${goal.name} is already complete!";
    }
    if (log != null && log.credited && log.amount > 0) {
      return "Congrats! \$${log.amount.toStringAsFixed(2)} added to ${goal.name}.";
    }
    if (!hasLeftover) {
      return "${goal.name} wasn't topped up because no money was left over.";
    }
    if (goal.weeklyContribution <= 0) {
      return "Set a weekly contribution to grow ${goal.name}.";
    }
    return "No contribution was applied to ${goal.name} this week.";
  }

}

/// Convenience date tuple capturing a week’s start/end bounds.
class _WeekPeriod {
  final DateTime start;
  final DateTime end;
  const _WeekPeriod({required this.start, required this.end});
}

