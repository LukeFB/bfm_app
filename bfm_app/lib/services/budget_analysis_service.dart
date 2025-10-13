/// ---------------------------------------------------------------------------
/// File: lib/services/budget_analysis_service.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Provides budgeting analytics:
///     - Weekly income
///     - Weekly category spending
///     - Remaining weekly budget
///     - Recurring transaction detection
///     - Category weekly suggestions for the Budget Build screen:
///         • normal categories
///         • split "Uncategorized" into per-description groups
///
/// Notes:
///   - All analysis is local (SQLite).
///   - Weekly figures are normalised by the **actual data window**
///     (first→last transaction date), via AnalysisUtils.
///   - < minWeekly items are filtered out unless they are recurring.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/budget_suggestion_model.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/utils/analysis_utils.dart';
import 'package:bfm_app/models/recurring_transaction_model.dart';

class BudgetAnalysisService {
  // -------------------- basic helpers (unchanged) --------------------

  static Future<double> getWeeklyIncome() async { // unused
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    String fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    final start = fmt(monday);
    final end = fmt(now);

    final res = await db.rawQuery('''
      SELECT SUM(amount) as total_income
      FROM transactions
      WHERE type = 'income'
        AND date BETWEEN ? AND ?;
    ''', [start, end]);

    return (res.first['total_income'] as num?)?.toDouble() ?? 0.0;
  }

  static Future<Map<String, double>> getWeeklySpendingByCategory() async { // unused
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    String fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    final start = fmt(monday);
    final end = fmt(now);

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

  static Future<double> getRemainingWeeklyBudget() async { // unused
    double totalBudget = await BudgetRepository.getTotalWeeklyBudget();
    if (totalBudget.isNaN) totalBudget = 0.0;
    double spent = await TransactionRepository.getThisWeekExpenses();
    final remaining = totalBudget - spent;
    return totalBudget > 0 ? remaining : 0.0;
  }

  // -------------------- recurring detection (unchanged) --------------------

  static Future<void> identifyRecurringTransactions() async {
    final allTxns = await TransactionRepository.getAll();
    if (allTxns.isEmpty) return;

    final expenses = allTxns.where((t) => t.type.toLowerCase() == 'expense').toList();
    if (expenses.isEmpty) return;

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
        .map((r) {
          final lbl = _normalizeText((r.description ?? ''));
          return "$lbl-${r.amount.round()}-${r.frequency}";
        })
        .toSet();

    for (var entry in groups.entries) {
      final label = entry.key;
      final txns = entry.value;

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

        final nextDueStr =
            "${nextDue.year.toString().padLeft(4, '0')}-${nextDue.month.toString().padLeft(2, '0')}-${nextDue.day.toString().padLeft(2, '0')}";

        final recurring = RecurringTransactionModel(
          categoryId: cluster.first.categoryId ?? 1,
          amount: avgAmount.abs(),
          frequency: frequency,
          nextDueDate: nextDueStr,
          description: label,
        );

        await RecurringRepository.insert(recurring);
      }
    }
  }

  // -------------------- SUGGESTIONS (split Uncategorized) --------------------

  static Future<List<BudgetSuggestionModel>> getCategoryWeeklyBudgetSuggestions({
    double minWeekly = 5.0,
  }) async {
    final db = await AppDatabase.instance.database;

    // Actual data window → normalize to $/week
    final range = await AnalysisUtils.getGlobalDateRange();
    final start = (range['first'] ?? _today());
    final end   = (range['last']  ?? _today());
    final weeks = AnalysisUtils.observedWeeks(range['first'], range['last']);

    // Recurring categories
    final recurring = await RecurringRepository.getAll();
    final recurringCatIds = recurring.map((r) => r.categoryId).toSet();

    // 1) Normal categories (excluding Uncategorized)
    final catRows = await db.rawQuery('''
      SELECT 
        t.category_id AS category_id,
        c.name        AS category_name,
        IFNULL(c.usage_count, 0) AS usage_count,
        COUNT(*) AS tx_count,
        IFNULL(SUM(CASE WHEN t.type='expense' THEN ABS(t.amount) ELSE 0 END), 0) AS total_spent
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE date(t.date) BETWEEN ? AND ?
        AND t.type='expense'
        AND c.name IS NOT NULL
        AND c.name <> 'Uncategorized'
      GROUP BY t.category_id, c.name, c.usage_count
    ''', [start, end]);

    final List<BudgetSuggestionModel> out = [];

    for (final r in catRows) {
      final int? catId = r['category_id'] as int?;
      final String name = (r['category_name'] as String?) ?? 'Unknown';
      final int usageCount = (r['usage_count'] as num?)?.toInt() ?? 0;
      final int txCount = (r['tx_count'] as num?)?.toInt() ?? 0;
      final double totalSpent = (r['total_spent'] as num?)?.toDouble() ?? 0.0;
      final double weeklySuggested = totalSpent / weeks;

      final bool hasRecurring = catId != null && recurringCatIds.contains(catId);
      if (!hasRecurring && weeklySuggested < minWeekly) continue;

      out.add(BudgetSuggestionModel(
        categoryId: catId,
        categoryName: name,
        weeklySuggested: double.parse(weeklySuggested.toStringAsFixed(2)),
        usageCount: usageCount,
        txCount: txCount,
        hasRecurring: hasRecurring,
      ));
    }

    // 2) "Uncategorized by description" groups
    final uncatRows = await db.rawQuery('''
      SELECT 
        t.description AS description,
        COUNT(*)      AS tx_count,
        IFNULL(SUM(ABS(t.amount)), 0) AS total_spent
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.type='expense'
        AND date(t.date) BETWEEN ? AND ?
        AND (t.category_id IS NULL OR c.name IS NULL OR c.name = 'Uncategorized')
      GROUP BY t.description
      HAVING description IS NOT NULL AND TRIM(description) <> ''
      ORDER BY total_spent DESC
    ''', [start, end]);

    for (final r in uncatRows) {
      final desc = (r['description'] as String?)?.trim() ?? '';
      if (desc.isEmpty) continue;

      final txCount = (r['tx_count'] as num?)?.toInt() ?? 0;
      final totalSpent = (r['total_spent'] as num?)?.toDouble() ?? 0.0;
      final double weeklySuggested = totalSpent / weeks;

      if (weeklySuggested < minWeekly) continue;

      out.add(BudgetSuggestionModel(
        categoryId: null,
        categoryName: desc,
        weeklySuggested: double.parse(weeklySuggested.toStringAsFixed(2)),
        usageCount: 0,
        txCount: txCount,
        hasRecurring: false,
        isUncategorizedGroup: true,
        description: desc,
      ));
    }

    // 3) Order: UNCATEGORIZED GROUPS → recurring → usage_count → weekly_suggested
    out.sort((a, b) {
      if (a.isUncategorizedGroup != b.isUncategorizedGroup) {
        // put uncategorized groups first
        return a.isUncategorizedGroup ? -1 : 1;
      }
      if (b.hasRecurring != a.hasRecurring) {
        return (b.hasRecurring ? 1 : 0).compareTo(a.hasRecurring ? 1 : 0);
      }
      if (b.usageCount != a.usageCount) {
        return b.usageCount.compareTo(a.usageCount);
      }
      return b.weeklySuggested.compareTo(a.weeklySuggested);
    });

    return out;
  }

  // -------------------- helpers --------------------

  static String _normalizeText(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

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

  static String _today() {
    final n = DateTime.now();
    return "${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}";
  }
}
