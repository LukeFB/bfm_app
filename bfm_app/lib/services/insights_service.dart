import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/goal_progress_log.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/models/weekly_report.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/weekly_report_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';

class InsightsService {
  static Future<WeeklyInsightsReport> generateWeeklyReport() async {
    final period = _lastCompletedWeek();
    final budgets = await BudgetRepository.getAll();

    final categoryBudgets = <int, double>{};
    for (final budget in budgets) {
      if (budget.categoryId == null) continue;
      categoryBudgets[budget.categoryId!] =
          (categoryBudgets[budget.categoryId!] ?? 0) + budget.weeklyLimit;
    }

    final spendMapAll =
        await TransactionRepository.sumExpensesByCategoryBetween(
      period.start,
      period.end,
    );
    final spendMap = Map<int?, double>.from(spendMapAll);
    final categoryIds = {
      ...categoryBudgets.keys,
      ...spendMapAll.keys.whereType<int>(),
    };
    final categoryNames =
        await CategoryRepository.getNamesByIds(categoryIds);
    final totalIncome =
        await TransactionRepository.sumIncomeBetween(period.start, period.end);

    final List<CategoryWeeklySummary> categories = [];
    double totalBudget = 0;
    double totalSpent = 0;

    categoryBudgets.forEach((categoryId, budget) {
      final spent = spendMap.remove(categoryId) ?? 0.0;
      final label = categoryNames[categoryId] ?? 'Category';
      categories.add(CategoryWeeklySummary(
        label: label,
        budget: budget,
        spent: spent,
      ));
      totalBudget += budget;
      totalSpent += spent;
    });

    categories.sort((a, b) => b.spent.compareTo(a.spent));

    final topCategories = _mapTopCategories(
      spendMapAll,
      categoryNames,
    );

    final metBudget =
        totalBudget > 0 ? (totalSpent <= (totalBudget + 0.01)) : false;
    final hasLeftover = (totalIncome - totalSpent) > 0.01;

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
      totalSpent: totalSpent,
      totalIncome: totalIncome,
      metBudget: metBudget,
      goalOutcomes: goalOutcomes,
    );
    await WeeklyReportRepository.upsert(report);
    return report;
  }

  static _WeekPeriod _lastCompletedWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mondayThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final start = mondayThisWeek.subtract(const Duration(days: 7));
    final end = mondayThisWeek.subtract(const Duration(days: 1));
    return _WeekPeriod(start: start, end: end);
  }

  static Future<List<WeeklyReportEntry>> getSavedReports() async {
    return WeeklyReportRepository.getAll();
  }

  static Future<List<TransactionModel>> getTransactionsForWeek(
      DateTime weekStart) async {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 6));
    return TransactionRepository.getBetween(start, end);
  }

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

class _WeekPeriod {
  final DateTime start;
  final DateTime end;
  const _WeekPeriod({required this.start, required this.end});
}

