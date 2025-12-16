/// ---------------------------------------------------------------------------
/// File: lib/services/dashboard_service.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `dashboard_screen.dart`, widgets, and insights flows that need aggregated
///     stats without embedding SQL.
///
/// Purpose:
///   - Collects dashboard-specific metrics (weekly spend, income, alerts,
///     featured tips/events) in one place.
///
/// Inputs:
///   - Reads directly from SQLite repositories/utilities.
///
/// Outputs:
///   - Doubles, strings, and model lists ready for UI consumption.
/// ---------------------------------------------------------------------------

import 'dart:math' as math;

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/event_model.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/tip_model.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/event_repository.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/tip_repository.dart';

/// Aggregates all database work needed to populate the dashboard.
class DashboardService {
  /// Expenses for the current week (Mon to today) across *all* categories.
  /// Kept for backwards compatibility; new discretionary calc excludes budgeted
  /// spend up to the budgeted amount.
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

  /// Formats a DateTime into YYYY-MM-DD for SQL filters.
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

  /// Expenses for this week that should reduce "Left to spend".
  ///
  /// Logic:
  /// - Identify the latest budget period (by period_start) and load budgets.
  /// - For budgeted categories, only count *overages* (amount above budget).
  /// - For non-budgeted or uncategorised expenses, count the full amount.
  static Future<double> discretionarySpendThisWeek() async {
    final db = await AppDatabase.instance.database;

    // Resolve current week window (Mon → today)
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    String _fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    final start = _fmt(monday);
    final end = _fmt(now);

    final budgets = await _latestBudgetsByCategory();

    // Spend grouped by category for the week
    final rows = await db.rawQuery(
      '''
      SELECT category_id, SUM(ABS(amount)) AS spent
      FROM transactions
      WHERE type='expense' AND date BETWEEN ? AND ?
      GROUP BY category_id;
      ''',
      [start, end],
    );

    double discretionary = 0.0;
    for (final row in rows) {
      final spent = (row['spent'] as num?)?.toDouble() ?? 0.0;
      final dynamic catRaw = row['category_id'];
      final int? catId = (catRaw is int)
          ? catRaw
          : int.tryParse(catRaw?.toString() ?? '');

      if (catId == null || !budgets.containsKey(catId)) {
        discretionary += spent; // non-budgeted or uncategorised
      } else {
        final over = math.max(spent - (budgets[catId] ?? 0.0), 0.0);
        discretionary += over;
      }
    }

    return discretionary;
  }

  /// Discretionary weekly budget shown in the header:
  /// lastWeekIncome − sum(weekly budgets).
  static Future<double> getDiscretionaryWeeklyBudget() async {
    final lastWeekIncome = await weeklyIncomeLastWeek();
    final budgetsSum = await BudgetRepository.getTotalWeeklyBudget();
    final safeBudgets = budgetsSum.isNaN ? 0.0 : budgetsSum;
    return lastWeekIncome - safeBudgets;
  }

  /// Fetches the currently featured tip from the repository.
  static Future<TipModel?> getFeaturedTip() {
    return TipRepository.getFeatured();
  }

  /// Returns upcoming events ordered by soonest first.
  static Future<List<EventModel>> getUpcomingEvents({int limit = 5}) {
    return EventRepository.getUpcoming(limit: limit);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Latest budget set keyed by category_id.
  static Future<Map<int, double>> _latestBudgetsByCategory() async {
    final db = await AppDatabase.instance.database;

    final latest = await db.rawQuery(
      'SELECT MAX(period_start) AS period FROM budgets',
    );
    final period = latest.first['period'] as String?;
    if (period == null || period.isEmpty) return {};

    final rows = await db.rawQuery(
      '''
      SELECT category_id, SUM(weekly_limit) AS total_limit
      FROM budgets
      WHERE period_start = ?
      GROUP BY category_id;
      ''',
      [period],
    );

    final map = <int, double>{};
    for (final row in rows) {
      final dynamic catRaw = row['category_id'];
      final int? catId = (catRaw is int)
          ? catRaw
          : int.tryParse(catRaw?.toString() ?? '');
      if (catId == null) continue;
      final limit = (row['total_limit'] as num?)?.toDouble() ?? 0.0;
      map[catId] = limit;
    }
    return map;
  }
}
