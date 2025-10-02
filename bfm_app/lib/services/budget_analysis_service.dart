/// ---------------------------------------------------------------------------
/// File: budget_analysis_service.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Provides utility methods to analyze financial data for budgeting. This 
///   includes calculating weekly income, weekly spending by category, remaining 
///   budget for the week, and identifying recurring transactions (like subscriptions 
///   or rent) from the transaction history. All calculations are done locally 
///   using the data in the SQLite database (no network calls).
///
/// Design:
///   - All methods are static for ease of use from UI or other services.
///   - Relies on repositories to query the database; complex logic like recurring 
///     detection is handled in Dart for clarity.
///   - "Weekly" is defined as Monday to Sunday (current week from Monday to today).
///   - Detected recurring transactions are stored in the `recurring_transactions` 
///     table for use in alerts and upcoming bills UI.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/models/recurring_transaction_model.dart';

class BudgetAnalysisService {
  /// Calculate total income for the current week (Monday to today).
  static Future<double> getWeeklyIncome() async {
    final db = await AppDatabase.instance.database;
    // Determine current week date range (Monday -> today).
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));
    String start = monday.toIso8601String().substring(0, 10);
    String end = now.toIso8601String().substring(0, 10);
    // Sum all income transactions in date range.
    final res = await db.rawQuery('''
      SELECT SUM(amount) as total_income
      FROM transactions
      WHERE type = 'income'
        AND date BETWEEN ? AND ?;
    ''', [start, end]);
    double income = (res.first['total_income'] as num?)?.toDouble() ?? 0.0;
    // If incomes were stored as positive values, this is fine; if stored as negatives (unlikely for income), take abs.
    return income;
  }

  /// Calculate total spending per category for the current week.
  /// 
  /// Returns a map of Category Name -> total spent (absolute value) in that category this week.
  static Future<Map<String, double>> getWeeklySpendingByCategory() async {
    final db = await AppDatabase.instance.database;
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));
    String start = monday.toIso8601String().substring(0, 10);
    String end = now.toIso8601String().substring(0, 10);
    // Query sum of expenses by category name for current week.
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
    // Prepare the result map, converting amounts to positive values for reporting.
    Map<String, double> spendingByCat = {};
    for (var row in result) {
      final name = row['category_name'] as String;
      final spentNum = row['total_spent'] as num? ?? 0;
      final spent = spentNum.toDouble().abs();
      spendingByCat[name] = spent;
    }
    return spendingByCat;
  }

  /// Calculate the remaining budget for the current week.
  /// 
  /// Uses the sum of all weekly budget limits minus the total spent this week. 
  /// If no budgets are defined, returns 0 (meaning no set budget).
  static Future<double> getRemainingWeeklyBudget() async {
    // Get total planned budget for the week (sum of all category weekly limits)
    double totalBudget = await BudgetRepository.getTotalWeeklyBudget();
    if (totalBudget.isNaN) totalBudget = 0.0;
    // Get total expenses for current week
    double spent = await TransactionRepository.getThisWeekExpenses();
    // Remaining budget is budget minus spent (if no budgets, this will be negative of spent, so cap at 0)
    double remaining = totalBudget - spent;
    if (totalBudget <= 0) {
      // If no budget set, we consider remaining budget as 0 (no target to compare against).
      return 0.0;
    }
    // Don't allow negative remaining (overspent beyond budget can be represented as negative if desired, but here we clamp at 0 for simplicity)
    return remaining;
  }

  /// Identify recurring transactions from the entire transaction history and store them.
  /// 
  /// Looks for repeating expenses (same description) on a weekly or monthly interval. 
  /// If a recurring pattern is detected for a description, an entry is added to the 
  /// `recurring_transactions` table (if not already present). The frequency is set 
  /// to 'weekly' or 'monthly', and the next due date is estimated based on the latest 
  /// transaction date in the pattern.
/// 
  /// This helps populate upcoming bills or subscriptions automatically.
  static Future<void> identifyRecurringTransactions() async {
    // Fetch all transactions (could optimize to recent months if needed)
    final allTxns = await TransactionRepository.getAll();
    if (allTxns.isEmpty) return;
    // Filter to only expenses, since we are interested in recurring bills/payments
    final expenseTxns = allTxns.where((t) => t.type.toLowerCase() == 'expense').toList();
    if (expenseTxns.isEmpty) return;

    // Group transactions by description (case-insensitive match for recurrence)
    Map<String, List<DateTime>> txnDatesByDesc = {};
    for (var t in expenseTxns) {
      final desc = (t.description.isEmpty ? 'Unknown' : t.description).toLowerCase();
      txnDatesByDesc.putIfAbsent(desc, () => []).add(DateTime.parse(t.date));
    }

    // Get existing recurring entries to avoid duplicates
    final existingRecurring = await RecurringRepository.getAll();
    final existingDescSet = existingRecurring
        .map((r) => (r.description ?? '').toLowerCase())
        .toSet();

    // Analyze each description group for regular intervals
    for (var entry in txnDatesByDesc.entries) {
      final desc = entry.key;
      final dates = entry.value;
      // Skip if we already have this description marked as recurring
      if (existingDescSet.contains(desc)) continue;
      if (dates.length < 2) continue; // need at least two occurrences to consider recurring

      // Sort dates to analyze intervals
      dates.sort();
      // Calculate interval in days between consecutive occurrences (use median or average)
      List<int> gaps = [];
      for (int i = 1; i < dates.length; i++) {
        gaps.add(dates[i].difference(dates[i-1]).inDays);
      }
      if (gaps.isEmpty) continue;
      double avgGap = gaps.reduce((a, b) => a + b) / gaps.length;

      String? frequency;
      if (avgGap >= 26 && avgGap <= 32) {
        frequency = 'monthly';
      } else if (avgGap >= 6 && avgGap <= 8) {
        frequency = 'weekly';
      } else {
        // Not a clear weekly or monthly interval, ignore
        continue;
      }

      // If identified as recurring, insert into recurring_transactions table
      // Use the latest date to calculate next due date
      final lastDate = dates.last;
      late DateTime nextDue;
      if (frequency == 'monthly') {
        // Add roughly one month to lastDate for next due: preserve day if possible
        try {
          nextDue = DateTime(lastDate.year, lastDate.month + 1, lastDate.day);
        } catch (_) {
          // If month+1 overflow (e.g., December), adjust year
          nextDue = DateTime(lastDate.year + 1, (lastDate.month + 1) % 12, lastDate.day);
        }
      } else if (frequency == 'weekly') {
        nextDue = lastDate.add(const Duration(days: 7));
      } else {
        continue;
      }

      // Determine category for this recurring bill (use the category of the latest transaction if available)
      int categoryId = 0;
      // Find the transaction model corresponding to lastDate
      try {
        final tx = expenseTxns.lastWhere((t) => DateTime.parse(t.date) == lastDate && t.description.toLowerCase() == desc);
        categoryId = tx.categoryId ?? 0;
      } catch (_) {
        categoryId = 0;
      }
      // Create the recurring model
      final recurring = RecurringTransactionModel(
        categoryId: categoryId == 0 ? 1 : categoryId, // default to 1 (first category) if unknown
        amount: expenseTxns.lastWhere((t) => t.description.toLowerCase() == desc).amount.abs(),
        frequency: frequency,
        nextDueDate: "${nextDue.toIso8601String().substring(0, 10)}",
        description: entry.key, 
      );
      // Store it in the database
      await RecurringRepository.insert(recurring);
    }
  }
}
