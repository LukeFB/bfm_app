/// ---------------------------------------------------------------------------
/// File: lib/models/weekly_overview_summary.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Captures the budget-vs-spend aggregates that power the Monday weekly
///   overview modal (weekly budget excluding goals, left to spend, etc).
///
/// Called by:
///   `insights_service.dart` when generating reports and
///   `weekly_overview_service.dart` for UI payloads.
/// ---------------------------------------------------------------------------

/// Summary metrics for a completed budgeting week (Mon → Sun).
class WeeklyOverviewSummary {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double incomeForWeek;
  final double nonGoalBudgetTotal;
  final double goalBudgetTotal;
  final double nonGoalSpend;
  final double goalSpend;
  final double discretionaryBudget;
  final double discretionaryLeft;

  /// Left to spend: (income - totalBudgets) - discretionarySpend
  /// Matches the dashboard calculation for consistency.
  final double leftToSpend;

  const WeeklyOverviewSummary({
    required this.weekStart,
    required this.weekEnd,
    required this.incomeForWeek,
    required this.nonGoalBudgetTotal,
    required this.goalBudgetTotal,
    required this.nonGoalSpend,
    required this.goalSpend,
    required this.discretionaryBudget,
    required this.discretionaryLeft,
    required this.leftToSpend,
  });

  /// Convenience getter used by UI chips.
  double get weeklyBudget => discretionaryBudget;

  /// Serialises the summary to JSON for persistence inside reports.
  Map<String, dynamic> toJson() => {
        'weekStart': _fmtDay(weekStart),
        'weekEnd': _fmtDay(weekEnd),
        'incomeForWeek': incomeForWeek,
        'nonGoalBudgetTotal': nonGoalBudgetTotal,
        'goalBudgetTotal': goalBudgetTotal,
        'nonGoalSpend': nonGoalSpend,
        'goalSpend': goalSpend,
        'discretionaryBudget': discretionaryBudget,
        'discretionaryLeft': discretionaryLeft,
        'leftToSpend': leftToSpend,
      };

  /// Rebuilds the summary from stored JSON.
  factory WeeklyOverviewSummary.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String? value) =>
        value == null || value.isEmpty ? DateTime.now() : DateTime.parse(value);
    return WeeklyOverviewSummary(
      weekStart: parseDate(json['weekStart'] as String?),
      weekEnd: parseDate(json['weekEnd'] as String?),
      incomeForWeek: (json['incomeForWeek'] as num?)?.toDouble() ?? 0.0,
      nonGoalBudgetTotal:
          (json['nonGoalBudgetTotal'] as num?)?.toDouble() ?? 0.0,
      goalBudgetTotal: (json['goalBudgetTotal'] as num?)?.toDouble() ?? 0.0,
      nonGoalSpend: (json['nonGoalSpend'] as num?)?.toDouble() ?? 0.0,
      goalSpend: (json['goalSpend'] as num?)?.toDouble() ?? 0.0,
      discretionaryBudget:
          (json['discretionaryBudget'] as num?)?.toDouble() ?? 0.0,
      discretionaryLeft:
          (json['discretionaryLeft'] as num?)?.toDouble() ?? 0.0,
      leftToSpend: (json['leftToSpend'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static String _fmtDay(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
}
