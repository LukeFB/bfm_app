// ---------------------------------------------------------------------------
// File: lib/services/dashboard_service.dart
// Author: Luke Fraser-Brown
//
// Called by:
//   - `dashboard_screen.dart`, widgets, and insights flows that need aggregated
//     stats without embedding SQL.
//
// Purpose:
//   - Collects dashboard-specific metrics (weekly spend, income, alerts,
//     featured tips/events) in one place.
//
// Inputs:
//   - Reads directly from SQLite repositories/utilities.
//
// Outputs:
//   - Doubles, strings, and model lists ready for UI consumption.
// ---------------------------------------------------------------------------

import 'dart:math' as math;

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/alert_model.dart';
import 'package:bfm_app/models/event_model.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/recurring_transaction_model.dart';
import 'package:bfm_app/models/tip_model.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/repositories/event_repository.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/repositories/alert_repository.dart';
import 'package:bfm_app/repositories/tip_repository.dart';
import 'package:bfm_app/utils/category_emoji_helper.dart';

/// Aggregates all database work needed to populate the dashboard.
class DashboardService {
  /// Expenses for the current week (Mon to today) across *all* categories.
  /// Kept for backwards compatibility; new discretionary calc excludes budgeted
  /// spend up to the budgeted amount.
  static Future<double> getThisWeekExpenses() async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    String fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    final start = fmt(monday);
    final end = fmt(now);

    final res = await db.rawQuery(
      '''
      SELECT IFNULL(SUM(ABS(amount)),0) AS v
      FROM transactions
      WHERE type='expense'
        AND excluded = 0
        AND date BETWEEN ? AND ?;
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

  /// Upcoming recurring alerts configured by the user.
  static Future<List<String>> getAlerts() async {
    final recurringAlerts = await AlertRepository.getActiveRecurring();
    final manualAlerts = (await AlertRepository.getAll())
        .where((alert) => alert.recurringTransactionId == null && alert.isActive)
        .toList();

    final formattedRecurring = await _formatRecurringAlerts(recurringAlerts);
    final formattedManual = _formatManualAlerts(manualAlerts);

    return [...formattedManual, ...formattedRecurring];
  }

  // ---------------------------------------------------------------------------
  // income & header helpers
  // ---------------------------------------------------------------------------

  /// Formats a DateTime into YYYY-MM-DD for SQL filters.
  static String _fmtDay(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// Weekly income estimated from recurring deposits when available.
  /// Falls back to actual last-week income if no recurring income detected.
  static Future<double> weeklyIncomeLastWeek() async {
    final recurringWeekly = await _recurringIncomeWeeklyAmount();
    if (recurringWeekly > 0) return recurringWeekly;
    return _actualIncomeLastWeek();
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
      WHERE type='income'
        AND excluded = 0
        AND date BETWEEN ? AND ?;
    ''',
      [start, end],
    );

    return (res.first['v'] as num?)?.toDouble() ?? 0.0;
  }

  static Future<double> _actualIncomeLastWeek() async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final mondayThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = _fmtDay(mondayThisWeek.subtract(const Duration(days: 7)));
    final end = _fmtDay(mondayThisWeek.subtract(const Duration(days: 1)));

    final res = await db.rawQuery(
      '''
      SELECT IFNULL(SUM(amount),0) AS v
      FROM transactions
      WHERE type='income'
        AND excluded = 0
        AND date BETWEEN ? AND ?;
    ''',
      [start, end],
    );
    return (res.first['v'] as num?)?.toDouble() ?? 0.0;
  }

  static Future<double> _recurringIncomeWeeklyAmount() async {
    final recurring = await RecurringRepository.getAll();
    if (recurring.isEmpty) return 0.0;

    double total = 0.0;
    for (final r in recurring) {
      if (r.transactionType.toLowerCase() != 'income') continue;
      total += _weeklyAmountFromRecurring(r);
    }
    return total;
  }

  static double _weeklyAmountFromRecurring(RecurringTransactionModel r) {
    final freq = r.frequency.toLowerCase();
    if (freq == 'weekly') return r.amount;
    if (freq == 'monthly') return r.amount / 4.33;
    return 0.0;
  }

  static String _recurringDisplayName(
    RecurringTransactionModel recurring,
    Map<int, String> categoryNames,
  ) {
    final descFirstWord = _firstWord(recurring.description);
    if (descFirstWord.isNotEmpty) return descFirstWord;

    final categoryLabel = categoryNames[recurring.categoryId];
    final categoryFirstWord = _firstWord(categoryLabel);
    if (categoryFirstWord.isNotEmpty &&
        categoryFirstWord.toLowerCase() != 'uncategorized') {
      return categoryFirstWord;
    }
    return 'Subscription';
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
    String fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    final start = fmt(monday);
    final end = fmt(now);

    final budgets = await _latestBudgetsByCategory();

    // Spend grouped by category for the week
    final rows = await db.rawQuery(
      '''
      SELECT category_id, SUM(ABS(amount)) AS spent
      FROM transactions
      WHERE type='expense'
        AND excluded = 0
        AND date BETWEEN ? AND ?
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

  static Future<List<String>> _formatRecurringAlerts(
    List<AlertModel> activeAlerts,
  ) async {
    if (activeAlerts.isEmpty) return const [];

    final recurringIds = activeAlerts
        .map((a) => a.recurringTransactionId)
        .whereType<int>()
        .toSet();
    if (recurringIds.isEmpty) return const [];

    final recurringList = await RecurringRepository.getByIds(recurringIds);
    final recurringMap = <int, RecurringTransactionModel>{};
    for (final r in recurringList) {
      final id = r.id;
      if (id != null) recurringMap[id] = r;
    }

    final categoryNames = await CategoryRepository.getNamesByIds(
      recurringMap.values.map((r) => r.categoryId),
    );
    final emojiHelper = await CategoryEmojiHelper.ensureLoaded();

    final now = DateTime.now();
    final alerts = <String>[];
    for (final alert in activeAlerts) {
      final rid = alert.recurringTransactionId;
      if (rid == null) continue;
      final recurring = recurringMap[rid];
      if (recurring == null) continue;

      DateTime due;
      try {
        due = DateTime.parse(recurring.nextDueDate);
      } catch (_) {
        continue;
      }

      final days = due.difference(now).inDays;
      if (days < 0 || days > alert.leadTimeDays) continue;

      final desc = alert.title.trim().isEmpty
          ? _recurringDisplayName(recurring, categoryNames)
          : alert.title.trim();
      final rawCategory = categoryNames[recurring.categoryId] ?? '';
      final emojiSource = rawCategory.trim().isNotEmpty
          ? rawCategory
          : (recurring.description ?? desc);
      final prefix = emojiHelper?.emojiForName(emojiSource) ??
          CategoryEmojiHelper.defaultEmoji;
      final dueLabel = _dueLabel(due);
      final amountLabel = _currency(recurring.amount);
      final freqLabel = recurring.frequency.toLowerCase() == 'monthly'
          ? 'monthly'
          : 'weekly';
      alerts.add('$prefix $desc · $dueLabel · $amountLabel / $freqLabel');
    }

    return alerts;
  }

  static List<String> _formatManualAlerts(List<AlertModel> manualAlerts) {
    if (manualAlerts.isEmpty) return const [];
    manualAlerts.sort((a, b) {
      final ad = a.dueDate ?? DateTime.tryParse(a.createdAt ?? '') ?? DateTime.now();
      final bd = b.dueDate ?? DateTime.tryParse(b.createdAt ?? '') ?? DateTime.now();
      return ad.compareTo(bd);
    });

    return manualAlerts.map((alert) {
      final icon = alert.icon ?? '⏰';
      final dueDate = alert.dueDate;
      String dueLabel;
      if (dueDate != null) {
        dueLabel = _dueLabel(dueDate);
      } else {
        dueLabel = alert.message?.trim().isNotEmpty == true
            ? alert.message!.trim()
            : 'Reminder saved';
      }
      final amountLabel =
          alert.amount != null ? ' · ${_currency(alert.amount!)}' : '';
      final note = alert.message?.trim();
      final noteLabel =
          (note != null && note.isNotEmpty && dueDate == null) ? ' · $note' : '';
      return '$icon ${alert.title} · $dueLabel$amountLabel$noteLabel';
    }).toList();
  }

  static String _currency(double value) {
    final decimals = value.abs() >= 100 ? 0 : 2;
    return '\$${value.toStringAsFixed(decimals)}';
  }

  static String _dueLabel(DateTime due) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDue = DateTime(due.year, due.month, due.day);
    final delta = normalizedDue.difference(normalizedToday).inDays;
    if (delta < 0) {
      return 'Overdue';
    } else if (delta == 0) {
      return 'Due today';
    } else if (delta == 1) {
      return 'Due tomorrow';
    }
    return 'Due in $delta days';
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

  static String _firstWord(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final match = RegExp(r'\S+').stringMatch(trimmed);
    return match ?? '';
  }
}
