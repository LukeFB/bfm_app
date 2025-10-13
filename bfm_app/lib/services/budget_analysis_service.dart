/// ---------------------------------------------------------------------------
/// File: budget_analysis_service.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Provides budgeting analytics:
///     - Weekly income
///     - Weekly category spending
///     - Remaining weekly budget
///     - Recurring transaction detection
///
/// Notes:
///   - All analysis is local (SQLite).
///   - Recurring detection uses description normalization + amount clustering
///     so that multiple bills from the same payee (e.g. Mum rent vs Mum phone)
///     don’t get merged incorrectly.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/models/recurring_transaction_model.dart';
import 'package:bfm_app/models/budget_suggestion_model.dart';

class BudgetAnalysisService {
  /// Calculate total income for the current week (Monday → today).
  static Future<double> getWeeklyIncome() async { // unused
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start = monday.toIso8601String().substring(0, 10);
    final end = now.toIso8601String().substring(0, 10);

    final res = await db.rawQuery('''
      SELECT SUM(amount) as total_income
      FROM transactions
      WHERE type = 'income'
        AND date BETWEEN ? AND ?;
    ''', [start, end]);

    return (res.first['total_income'] as num?)?.toDouble() ?? 0.0;
  }

  /// Spending totals by category for this week.
  static Future<Map<String, double>> getWeeklySpendingByCategory() async { // unused
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start = monday.toIso8601String().substring(0, 10);
    final end = now.toIso8601String().substring(0, 10);

    final result = await db.rawQuery('''
      SELECT 
        COALESCE(c.name, 'Uncategorized') as category_name,
        SUM(t.amount) as total_spent
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'expense'
        AND t.date BETWEEN ? AND ?
      GROUP BY category_name;
    ''', [start, end]);

    return {
      for (var row in result)
        (row['category_name'] as String): (row['total_spent'] as num? ?? 0).toDouble().abs()
    };
  }

  /// Remaining budget for this week.
  static Future<double> getRemainingWeeklyBudget() async { // unused
    double totalBudget = await BudgetRepository.getTotalWeeklyBudget();
    if (totalBudget.isNaN) totalBudget = 0.0;

    double spent = await TransactionRepository.getThisWeekExpenses();
    final remaining = totalBudget - spent;
    return totalBudget > 0 ? remaining : 0.0;
  }

  /// ---------------------------------------------------------------------------
  /// Identify recurring transactions (weekly + monthly).
  ///
  /// Strategy:
  ///   - Fetch all expenses from DB.
  ///   - Normalize description text to reduce noise (remove numbers, symbols).
  ///   - Group by description, then sub-cluster by amount (so "Mum $50 rent" and
  ///     "Mum $40 phone" don’t merge into one bill).
  ///   - Check date gaps between transactions:
  ///       * Weekly: average gap ~7 days, ≥4 repeats required.
  ///       * Monthly: average gap ~30 days, ≥3 repeats required.
  ///       * Gaps must be consistent (low variance).
  ///   - Save recurring bills into `recurring_transactions` with frequency flag.
  /// ---------------------------------------------------------------------------
  static Future<void> identifyRecurringTransactions() async {
    final allTxns = await TransactionRepository.getAll();
    if (allTxns.isEmpty) return;

    final expenses = allTxns.where((t) => t.type.toLowerCase() == 'expense').toList();
    if (expenses.isEmpty) return;

    // group by category name (if present), else normalized description
    final Map<String, List<dynamic>> groups = {};
    for (var t in expenses) {
      final label = _preferredGroupLabel(
        categoryName: (t as dynamic).categoryName,
        description: (t as dynamic).description,
      );
      groups.putIfAbsent(label, () => []).add(t);
    }

    final existing = await RecurringRepository.getAll();
    final existingKeys = existing
        .map((r) => "${_normalizeText((r.description ?? ''))}-${r.amount.round()}-${r.frequency}")
        .toSet();

    for (var entry in groups.entries) {
      final label = entry.key;
      final txns = entry.value;

      // cluster by similar amount
      final List<List<dynamic>> clusters = [];
      for (var t in txns) {
        bool added = false;
        for (var cluster in clusters) {
          if (_amountsClose(cluster.first.amount, t.amount, pct: 0.05)) {
            cluster.add(t);
            added = true;
            break;
          }
        }
        if (!added) clusters.add([t]);
      }

      // analyze each cluster
      for (var cluster in clusters) {
        if (cluster.length < 2) continue;

        final dates = cluster.map((t) => DateTime.parse(t.date)).toList()..sort();
        final gaps = <int>[];
        for (int i = 1; i < dates.length; i++) {
          gaps.add(dates[i].difference(dates[i - 1]).inDays);
        }
        if (gaps.isEmpty) continue;

        final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
        final varianceOk = gaps.every((g) => (g - avgGap).abs() <= 3);

        String? frequency;
        if (avgGap >= 5 && avgGap <= 9 && cluster.length >= 4 && varianceOk) {
          frequency = 'weekly';
        } else if (avgGap >= 26 && avgGap <= 32 && cluster.length >= 3 && varianceOk) {
          frequency = 'monthly';
        } else {
          continue;
        }

        final lastDate = dates.last;
        final nextDue = frequency == 'weekly'
            ? lastDate.add(const Duration(days: 7))
            : DateTime(lastDate.year, lastDate.month + 1, lastDate.day);

        final avgAmount = cluster.map((t) => t.amount).reduce((a, b) => a + b) / cluster.length;
        final key = "${_normalizeText(label)}-${avgAmount.round()}-$frequency";
        if (existingKeys.contains(key)) continue;

        final recurring = RecurringTransactionModel(
          categoryId: cluster.first.categoryId ?? 1,
          amount: avgAmount.abs(),
          frequency: frequency,
          nextDueDate: nextDue.toIso8601String().substring(0, 10),
          description: label,
        );

        await RecurringRepository.insert(recurring);
      }
    }
  }

  /// Windowed weekly income (normalized). // unused
  static Future<double> getWindowedWeeklyIncome({int lookbackDays = 60}) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final start = _fmtDay(now.subtract(Duration(days: lookbackDays)));
    final end = _fmtDay(now);
    final res = await db.rawQuery('''
      SELECT IFNULL(SUM(CASE WHEN type='income' THEN amount ELSE 0 END), 0) AS total
      FROM transactions
      WHERE date BETWEEN ? AND ?;
    ''', [start, end]);
    final total = (res.first['total'] as num?)?.toDouble() ?? 0.0;
    // Use observed window, not the nominal lookback, to avoid under/over scaling
    return total / 4.33; // coarse average weeks in a month
  }

  /// ---------------------------------------------------------------------------
  /// Category weekly budget suggestions (ordered).
  ///
  /// Purpose:
  ///   Calculates normalized weekly expenditure per category and returns a
  ///   typed list of suggestions to populate the "Build Budget" screen.
  ///
  /// Normalisation fix:
  ///   We divide by *observed* days per category:
  ///     weeks = max(1, (last_date - first_date + 1) / 7)
  ///   This avoids halving when we only have ~1 month of data.
  ///
  /// Filtering:
  ///   Exclude categories < [minWeekly] unless they have recurring.
  /// ---------------------------------------------------------------------------
  static Future<List<BudgetSuggestionModel>> getCategoryWeeklyBudgetSuggestions({
    int lookbackDays = 60,
    double minWeekly = 5.0,
  }) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final start = _fmtDay(now.subtract(Duration(days: lookbackDays)));
    final end = _fmtDay(now);

    final rows = await db.rawQuery('''
      SELECT 
        t.category_id AS category_id,
        COALESCE(c.name, 'Uncategorized') AS category_name,
        IFNULL(c.usage_count, 0) AS usage_count,
        COUNT(*) AS tx_count,
        IFNULL(SUM(CASE WHEN t.type='expense' THEN ABS(t.amount) ELSE 0 END), 0) AS total_spent,
        MIN(date(t.date)) AS first_date,
        MAX(date(t.date)) AS last_date
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE date(t.date) BETWEEN ? AND ?
        AND t.type='expense'
      GROUP BY t.category_id, c.name, c.usage_count
    ''', [start, end]);

    final recurring = await RecurringRepository.getAll();
    final recurringCatIds = recurring.map((r) => r.categoryId).toSet();

    final list = <BudgetSuggestionModel>[];
    for (final r in rows) {
      final int? catId = r['category_id'] as int?;
      final String name = (r['category_name'] as String?) ?? 'Uncategorized';
      final int usageCount = (r['usage_count'] as num?)?.toInt() ?? 0;
      final int txCount = (r['tx_count'] as num?)?.toInt() ?? 0;
      final double totalSpent = (r['total_spent'] as num?)?.toDouble() ?? 0.0;

      // observed window per category
      final first = r['first_date'] as String?;
      final last  = r['last_date'] as String?;
      int days = 7; // at least a week to avoid dividing by very small numbers
      if (first != null && last != null && first.isNotEmpty && last.isNotEmpty) {
        try {
          final d1 = DateTime.parse(first);
          final d2 = DateTime.parse(last);
          days = (d2.difference(d1).inDays + 1).clamp(7, 365);
        } catch (_) {}
      }
      final weeks = (days / 7.0).clamp(1.0, 52.0);
      final weekly = totalSpent / weeks;

      final bool hasRecurring = catId != null && recurringCatIds.contains(catId);
      final bool isUncategorized = catId == null;
      final double priority = (hasRecurring ? 1e6 : 0) + (usageCount * 1e3) + weekly;

      // Filter out tiny budgets unless recurring
      if (!hasRecurring && weekly < minWeekly) continue;

      list.add(BudgetSuggestionModel(
        categoryId: catId,
        categoryName: name,
        weeklySuggested: double.parse(weekly.toStringAsFixed(2)),
        usageCount: usageCount,
        txCount: txCount,
        hasRecurring: hasRecurring,
        isUncategorized: isUncategorized,
        priorityScore: priority,
      ));
    }

    list.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    return list;
  }

  /// Backwards-compat alias.
  static Future<List<BudgetSuggestionModel>> getCategoryWeeklySuggestions({
    int lookbackDays = 60,
    double minWeekly = 5.0,
  }) {
    return getCategoryWeeklyBudgetSuggestions(
      lookbackDays: lookbackDays,
      minWeekly: minWeekly,
    );
  }

  // helpers
  static String _normalizeText(String raw) => raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _preferredGroupLabel({String? categoryName, required String description}) {
    final cat = (categoryName ?? '').trim();
    if (cat.isNotEmpty) return cat;
    return _normalizeText(description.isEmpty ? 'unknown' : description);
  }

  static bool _amountsClose(double a, double b, {double pct = 0.05}) {
    if (a == 0 || b == 0) return false;
    final diff = (a - b).abs();
    return diff <= (a.abs() * pct);
  }

  static String _fmtDay(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
}
