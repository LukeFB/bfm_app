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

class BudgetAnalysisService {
  /// Calculate total income for the current week (Monday → today).
  static Future<double> getWeeklyIncome() async {
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
  static Future<Map<String, double>> getWeeklySpendingByCategory() async {
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
  static Future<double> getRemainingWeeklyBudget() async {
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
  ///
  /// Why:
  ///   - Prevents false positives from grocery/fuel/coffee spends.
  ///   - Ensures only true repeating obligations appear in Alerts / Budgets.
  /// ---------------------------------------------------------------------------
  static Future<void> identifyRecurringTransactions() async {
    final allTxns = await TransactionRepository.getAll();
    if (allTxns.isEmpty) return;

    // --- Step 1: only expenses are considered recurring ---
    final expenses = allTxns.where((t) => t.type.toLowerCase() == 'expense').toList();
    if (expenses.isEmpty) return;

    // --- Step 2: group by normalized description ---
    final Map<String, List<dynamic>> groups = {};
    for (var t in expenses) {
      final norm = _normalizeDesc(t.description.isEmpty ? 'unknown' : t.description);
      groups.putIfAbsent(norm, () => []).add(t);
    }

    // --- Step 3: avoid inserting duplicates ---
    final existing = await RecurringRepository.getAll();
    final existingKeys = existing
        .map((r) => "${_normalizeDesc(r.description ?? '')}-${r.amount.round()}-${r.frequency}")
        .toSet();

    // --- Step 4: process each description group ---
    for (var entry in groups.entries) {
      final desc = entry.key;
      final txns = entry.value;

      // --- Step 4a: cluster by similar amount ---
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

      // --- Step 4b: analyze each cluster ---
      for (var cluster in clusters) {
        if (cluster.length < 2) continue;

        // Sort by date
        final dates = cluster.map((t) => DateTime.parse(t.date)).toList()..sort();

        // Compute day gaps
        final gaps = <int>[];
        for (int i = 1; i < dates.length; i++) {
          gaps.add(dates[i].difference(dates[i - 1]).inDays);
        }
        if (gaps.isEmpty) continue;

        // Average + variance check
        final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
        final varianceOk = gaps.every((g) => (g - avgGap).abs() <= 3);

        String? frequency;

        // --- Weekly rule: 5–9 days, ≥4 repeats ---
        if (avgGap >= 5 && avgGap <= 9 && cluster.length >= 4 && varianceOk) {
          frequency = 'weekly';
        }
        // --- Monthly rule: 26–32 days, ≥ 3 repeats ---
        else if (avgGap >= 26 && avgGap <= 32 && cluster.length >= 2 && varianceOk) {
          frequency = 'monthly';
        } else {
          continue; // Not consistent enough → skip
        }

        // --- Step 4c: compute next due date ---
        final lastDate = dates.last;
        final nextDue = frequency == 'weekly'
            ? lastDate.add(const Duration(days: 7))
            : DateTime(lastDate.year, lastDate.month + 1, lastDate.day);

        // Average amount across this cluster
        final avgAmount = cluster.map((t) => t.amount).reduce((a, b) => a + b) / cluster.length;

        // Unique key to avoid duplicates
        final key = "$desc-${avgAmount.round()}-$frequency";
        if (existingKeys.contains(key)) continue;

        // --- Step 4d: insert recurring model ---
        final recurring = RecurringTransactionModel(
          categoryId: cluster.first.categoryId ?? 1,
          amount: avgAmount.abs(),
          frequency: frequency,
          nextDueDate: nextDue.toIso8601String().substring(0, 10),
          description: desc,
        );

        await RecurringRepository.insert(recurring);
      }
    }
  }

  /// Normalize descriptions (lowercase, strip digits/symbols, trim spaces).
  static String _normalizeDesc(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), '') // keep only letters/spaces
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// True if amounts are “close enough” (±pct%).
  static bool _amountsClose(double a, double b, {double pct = 0.05}) {
    if (a == 0 || b == 0) return false;
    final diff = (a - b).abs();
    return diff <= (a.abs() * pct);
  }
}
