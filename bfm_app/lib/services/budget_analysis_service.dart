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
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/models/recurring_transaction_model.dart';
import 'package:bfm_app/utils/description_normalizer.dart';

/// Houses all budget-related analytics (recurring detection + suggestions).
class BudgetAnalysisService {

  // -------------------- recurring detection --------------------

  /// Walks through local transactions, groups similar merchants/amounts, and
  /// creates recurring transaction entries when the cadence looks weekly or
  /// monthly. Keeps detection local so we don't hit backend APIs.
  static Future<void> identifyRecurringTransactions() async {
    final allTxns = await TransactionRepository.getAll(includeExcluded: false);
    if (allTxns.isEmpty) return;

    final now = DateTime.now();
    final firstOfThisMonth = DateTime(now.year, now.month, 1);
    final detectionWindowStart =
        DateTime(firstOfThisMonth.year, firstOfThisMonth.month - 3, 1);

    bool withinWindow(TransactionModel txn) {
      final date = DateTime.tryParse(txn.date);
      if (date == null) return false;
      return !date.isBefore(detectionWindowStart) && date.isBefore(now);
    }

    final expenses = allTxns
        .where((t) => t.type.toLowerCase() == 'expense' && withinWindow(t))
        .toList();
    final incomes = allTxns
        .where((t) => t.type.toLowerCase() == 'income' && withinWindow(t))
        .toList();

    await _identifyRecurringClusters(expenses, transactionType: 'expense', now: now);
    await _identifyRecurringClusters(incomes, transactionType: 'income', now: now);
  }

  // -------------------- SUGGESTIONS --------------------

  /// Builds weekly budget suggestions for normal categories plus grouped
  /// uncategorized descriptions. Normalises spend to actual available weeks and
  /// boosts recurring categories even if they spend below `minWeekly`.
  static Future<List<BudgetSuggestionModel>> getCategoryWeeklyBudgetSuggestions({
    double minWeekly = 5.0,
  }) async {
    final db = await AppDatabase.instance.database;

    // normalize to $/week
    final today = DateTime.now();
    final firstOfThisMonth = DateTime(today.year, today.month, 1);
    final prevMonthStart =
        DateTime(firstOfThisMonth.year, firstOfThisMonth.month - 1, 1);
    final prevMonthEnd = firstOfThisMonth.subtract(const Duration(days: 1));
    final start = _formatDate(prevMonthStart);
    final end = _formatDate(prevMonthEnd);
    final weeks = ((prevMonthEnd.difference(prevMonthStart).inDays + 1) / 7)
        .clamp(1, double.infinity) as double;

    // Recurring categories
    final recurring = await RecurringRepository.getAll();
    final recurringCatIds = recurring
        .where((r) => r.transactionType == 'expense')
        .map((r) => r.categoryId)
        .toSet();

    // Normal categories (excluding Uncategorized)
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
        AND t.excluded = 0
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

    // Uncategorized by description groups
    final uncatRows = await db.rawQuery('''
      SELECT 
        t.description AS description,
        COUNT(*)      AS tx_count,
        IFNULL(SUM(ABS(t.amount)), 0) AS total_spent
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.type='expense'
        AND date(t.date) BETWEEN ? AND ?
        AND t.excluded = 0
        AND (t.category_id IS NULL OR c.name IS NULL OR c.name = 'Uncategorized')
      GROUP BY t.description
      HAVING description IS NOT NULL AND TRIM(description) <> ''
      ORDER BY tx_count DESC, total_spent DESC
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

    // Order: UNCATEGORIZED GROUPS then recurring setected then usage_count then weekly_suggested
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

  /// Lowercases and strips punctuation so description groupings stay stable.
  static String _normalizeText(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Builds a grouping key that includes both category and description so we
  /// don't double-count the same merchant across categories (or vice versa).
  static String _recurringGroupKey(TransactionModel txn) {
    final categoryRaw = (txn.categoryName ?? '').trim();
    final normalizedCat = _normalizeText(categoryRaw);
    final catKey = normalizedCat.isEmpty ? 'uncategorized' : normalizedCat;

    final merchantLabel =
        DescriptionNormalizer.normalizeMerchant(txn.merchantName, txn.description);
    final descKey = merchantLabel.isEmpty ? catKey : merchantLabel;
    return '$catKey::$descKey';
  }

  /// Returns true when two amounts are within the provided percentage, used to
  /// cluster recurring expenses with similar values.
  static bool _amountsClose(double a, double b, {double pct = 0.05}) {
    if (a == 0 || b == 0) return false;
    final diff = (a - b).abs();
    return diff <= (a.abs() * pct);
  }

  static String _formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  static bool _hasRecentWeeklyPattern(List<DateTime> dates, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final mondayThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final windowStart = mondayThisWeek.subtract(const Duration(days: 7 * 3));
    final relevant = dates
        .where((d) => !d.isBefore(windowStart) && d.isBefore(mondayThisWeek))
        .toList()
      ..sort();
    if (relevant.length < 3) return false;
    for (var i = 1; i < relevant.length; i++) {
      final gap = relevant[i].difference(relevant[i - 1]).inDays.abs();
      if (gap < 5 || gap > 9) {
        return false;
      }
    }
    return true;
  }

  static bool _hasRecentMonthlyPattern(List<DateTime> dates, DateTime now) {
    final firstOfThisMonth = DateTime(now.year, now.month, 1);
    final windowStart =
        DateTime(firstOfThisMonth.year, firstOfThisMonth.month - 3, 1);
    final relevant = dates
        .where((d) => !d.isBefore(windowStart) && d.isBefore(firstOfThisMonth))
        .toList()
      ..sort();
    if (relevant.length < 3) return false;
    for (var i = 1; i < relevant.length; i++) {
      final gap = relevant[i].difference(relevant[i - 1]).inDays.abs();
      if (gap < 25 || gap > 35) {
        return false;
      }
    }
    return true;
  }

  static DateTime _predictMonthlyDueDate(
    List<DateTime> dates,
    DateTime lastOccurrence,
  ) {
    final preferredDay = _commonDayOfMonth(dates);
    final nextMonth = DateTime(lastOccurrence.year, lastOccurrence.month + 1, 1);
    final daysInNextMonth = _daysInMonth(nextMonth.year, nextMonth.month);
    final day = preferredDay > daysInNextMonth ? daysInNextMonth : preferredDay;
    return DateTime(nextMonth.year, nextMonth.month, day);
  }

  static int _commonDayOfMonth(List<DateTime> dates) {
    final counts = <int, int>{};
    for (final d in dates) {
      counts.update(d.day, (value) => value + 1, ifAbsent: () => 1);
    }
    counts.removeWhere((key, value) => value == 0);
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        return a.key.compareTo(b.key);
      });
    return sorted.isEmpty ? dates.last.day : sorted.first.key;
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// Shared recurring logic for both expenses and income streams.
  static Future<void> _identifyRecurringClusters(
    List<TransactionModel> txns, {
    required String transactionType,
    required DateTime now,
  }) async {
    if (txns.isEmpty) return;

    final Map<String, List<TransactionModel>> groups = {};
    for (final t in txns) {
      final key = _recurringGroupKey(t);
      groups.putIfAbsent(key, () => []).add(t);
    }

    for (final grouped in groups.values) {

      final List<List<TransactionModel>> clusters = [];
      for (final txn in grouped) {
        bool added = false;
        for (final cluster in clusters) {
          if (_amountsClose(cluster.first.amount, txn.amount, pct: 0.05)) {
            cluster.add(txn);
            added = true;
            break;
          }
        }
        if (!added) clusters.add([txn]);
      }

      for (final cluster in clusters) {
        if (cluster.length < 2) continue;

        final today = DateTime(now.year, now.month, now.day);
        final dates = cluster
            .map((t) => DateTime.parse(t.date))
            .where((d) => d.isBefore(today))
            .toList()
          ..sort();
        if (dates.length < 2) continue;

        String? frequency;
        if (_hasRecentWeeklyPattern(dates, now)) {
          frequency = 'weekly';
        } else if (_hasRecentMonthlyPattern(dates, now)) {
          frequency = 'monthly';
        } else {
          continue;
        }

        final avgAmount =
            cluster.map((t) => t.amount).reduce((a, b) => a + b) / cluster.length;
        if (frequency == 'monthly' && avgAmount.abs() < 10) {
          continue;
        }

        final lastDate = dates.last;
        DateTime nextDue;
        if (frequency == 'weekly') {
          nextDue = lastDate.add(const Duration(days: 7));
        } else {
          nextDue = _predictMonthlyDueDate(dates, lastDate);
        }
        final nextDueStr =
            "${nextDue.year.toString().padLeft(4, '0')}-${nextDue.month.toString().padLeft(2, '0')}-${nextDue.day.toString().padLeft(2, '0')}";

        final firstDesc = cluster.first.description.trim();
        String friendlyDesc;
        if (firstDesc.isNotEmpty) {
          friendlyDesc = firstDesc;
        } else {
          final catName = (cluster.first.categoryName ?? '').trim();
          friendlyDesc = catName.isNotEmpty ? catName : 'Recurring $transactionType';
        }

        final recurring = RecurringTransactionModel(
          categoryId: cluster.first.categoryId ?? 1,
          amount: avgAmount.abs(),
          frequency: frequency,
          nextDueDate: nextDueStr,
          description: friendlyDesc,
          transactionType: transactionType,
        );

        await RecurringRepository.insert(recurring);
      }
    }
  }
}
