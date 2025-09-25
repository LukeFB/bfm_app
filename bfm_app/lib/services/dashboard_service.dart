/// ---------------------------------------------------------------------------
/// File: dashboard_service.dart
/// Author: Luke Fraser-Brown
/// Description:
///   Service layer responsible for aggregating dashboard-specific data
///   from the database. This keeps DB logic out of the UI layer and makes
///   the DashboardScreen much more readable.
///
/// Design decisions:
///   - All methods are static: this avoids needing to instantiate the
///     service and matches the "utility" nature of these loaders.
///   - Each method encapsulates a specific query or aggregation, instead
///     of scattering raw SQL through the UI.
///   - This layer converts "raw DB rows" into strongly typed Dart values.
///
/// Future scope:
///   - Could evolve into an injected repository pattern (e.g. using Riverpod).
///   - Could add caching or offline-first logic here.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/recurring_transaction_model.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';

class DashboardService {
  /// Safely fetches the total weekly budget.
  ///
  /// Wraps `getTotalWeeklyBudget()` but ensures we never return NaN,
  /// which can occur if no budgets are defined yet.
  static Future<double> getTotalWeeklyBudgetSafe() async {
    final total = await BudgetRepository.getTotalWeeklyBudget();
    return total.isNaN ? 0.0 : total;
  }

  /// Calculates the total expenses for the current week.
  ///
  /// - Defines "week" as Monday → today (inclusive).
  /// - Builds formatted YYYY-MM-DD strings for querying.
  /// - Queries the `transactions` table for type='expense'.
  /// - Returns the absolute value of spend (never negative).
  static Future<double> getThisWeekExpenses() async {
    return TransactionRepository.getThisWeekExpenses();
  }

  /// Retrieves the user’s primary goal (if any).
  ///
  /// Strategy: returns the first goal in the table.
  /// In future this may evolve to:
  ///   - Prioritize "active" goals.
  ///   - Or select the goal with nearest due_date.
  static Future<GoalModel?> getPrimaryGoal() async {
    final goals = await GoalRepository.getAll();
    return goals.isEmpty ? null : goals.first;
  }

  /// Fetches alerts for upcoming recurring bills within 7 days.
  ///
  /// - Queries the `recurring_transactions` table.
  /// - Compares `next_due_date` with today and "today + 7".
  /// - Generates human-readable alert strings.
  /// - Returns a few hard-coded fallback alerts if none are found.
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
        continue; // skip invalid dates
      }

      final days = due.difference(today).inDays;
      if (days >= 0 && due.isBefore(soon)) {
        alerts.add("⚠️ $desc (\$${amt.toStringAsFixed(0)}) due in $days day${days == 1 ? '' : 's'}");
      }
    }
    return alerts;
  }
}
