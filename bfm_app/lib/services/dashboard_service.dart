/// ---------------------------------------------------------------------------
/// File: dashboard_service.dart
/// Author: Luke Fraser-Brown
/// Description:
///   Service layer responsible for aggregating dashboard-specific data
///   from the database. This keeps DB logic out of the UI layer and makes
///   the DashboardScreen much more readable.
///
/// Update:
///   - Weekly budget header now uses LAST WEEK'S income instead of this week.
///   - Adds weeklyIncomeLastWeek().
///   - Adds getDiscretionaryWeeklyBudget() = lastWeekIncome - budgets.
///   - Adds discretionarySpendThisWeek() helper.
///   - Keeps original functions for compatibility.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/event_model.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/tip_model.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/event_repository.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/tip_repository.dart';

class DashboardService {
  /// Expenses for the current week (Mon to today).
  static Future<double> getThisWeekExpenses() async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    String _fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    final start = _fmt(monday);
    final end = _fmt(now);

    final res = await db.rawQuery(
      '''
      SELECT IFNULL(SUM(ABS(amount)),0) AS v
      FROM transactions
      WHERE type='expense' AND date BETWEEN ? AND ?;
    ''',
      [start, end],
    );

    return (res.first['v'] as num?)?.toDouble() ?? 0.0;
  }

  /// Retrieves the user’s primary goal (if any).
  static Future<GoalModel?> getPrimaryGoal() async {
    final goals = await GoalRepository.getAll();
    return goals.isEmpty ? null : goals.first;
  }

  /// Upcoming recurring alerts (unchanged).
  static Future<List<String>> getAlerts() async {
    final db = await AppDatabase.instance.database;
    final today = DateTime.now();
    final soon = today.add(const Duration(days: 7));
    final rows = await db.query(
      'recurring_transactions',
      columns: ['description', 'next_due_date', 'amount'],
    );

    final List<String> alerts = [];
    for (final r in rows) {
      final desc = (r['description'] ?? 'Bill') as String;
      final amt = (r['amount'] is num) ? (r['amount'] as num).toDouble() : 0.0;
      final dueStr = r['next_due_date'] as String?;
      if (dueStr == null || dueStr.trim().isEmpty) continue;

      DateTime? due;
      try {
        due = DateTime.parse(dueStr);
      } catch (_) {
        continue;
      }

      final days = due.difference(today).inDays;
      if (days >= 0 && due.isBefore(soon)) {
        alerts.add(
          "⚠️ $desc (\$${amt.toStringAsFixed(0)}) due in $days day${days == 1 ? '' : 's'}",
        );
      }
    }
    return alerts;
  }

  // ---------------------------------------------------------------------------
  // income & header helpers
  // ---------------------------------------------------------------------------

  static String _fmtDay(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// Income for last week (Mon→Sun).
  /// Example: if today is Wed, 16 Oct, last week = Mon 7 Oct → Sun 13 Oct.
  static Future<double> weeklyIncomeLastWeek() async {
    final db = await AppDatabase.instance.database;

    final now = DateTime.now();
    final mondayThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = _fmtDay(mondayThisWeek.subtract(const Duration(days: 7)));
    final end = _fmtDay(
      mondayThisWeek.subtract(const Duration(days: 1)),
    ); // Sunday

    final res = await db.rawQuery(
      '''
      SELECT IFNULL(SUM(amount),0) AS v
      FROM transactions
      WHERE type='income' AND date BETWEEN ? AND ?;
    ''',
      [start, end],
    );

    // Income should be positive already; keep as-is.
    return (res.first['v'] as num?)?.toDouble() ?? 0.0;
  }

  /// Income for this week (Mon to today).
  /// Not used by header anymore as dont know what day user gets income.
  static Future<double> weeklyIncomeThisWeek() async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start = _fmtDay(monday);
    final end = _fmtDay(now);

    final res = await db.rawQuery(
      '''
      SELECT IFNULL(SUM(amount),0) AS v
      FROM transactions
      WHERE type='income' AND date BETWEEN ? AND ?;
    ''',
      [start, end],
    );

    return (res.first['v'] as num?)?.toDouble() ?? 0.0;
  }

  /// Expenses for this week — used for "Left to spend".
  static Future<double> discretionarySpendThisWeek() => getThisWeekExpenses();

  /// Discretionary weekly budget shown in the header:
  /// lastWeekIncome − sum(weekly budgets).
  static Future<double> getDiscretionaryWeeklyBudget() async {
    final lastWeekIncome = await weeklyIncomeLastWeek();
    final budgetsSum = await BudgetRepository.getTotalWeeklyBudget();
    final safeBudgets = budgetsSum.isNaN ? 0.0 : budgetsSum;
    return lastWeekIncome - safeBudgets;
  }

  static Future<TipModel?> getFeaturedTip() {
    return TipRepository.getFeatured();
  }

  static Future<List<EventModel>> getUpcomingEvents({int limit = 5}) {
    return EventRepository.getUpcoming(limit: limit);
  }
}
