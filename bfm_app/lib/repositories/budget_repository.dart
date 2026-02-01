/// ---------------------------------------------------------------------------
/// File: lib/repositories/budget_repository.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Budget build screen, dashboard service, and sync flows.
///
/// Purpose:
///   - Wraps common SQL queries on the `budgets` table behind typed helpers.
///
/// Inputs:
///   - `BudgetModel` objects or simple IDs depending on the action.
///
/// Outputs:
///   - Inserted row IDs, `BudgetModel` lists, and aggregate totals.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/budget_model.dart';
import 'package:sqflite/sqflite.dart';

/// Static helper methods for interacting with stored budgets.
class BudgetRepository {

  /// Removes every budget row. Used when resetting state.
  static Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('budgets');
  }

  /// Inserts/replaces a budget row using the model's map representation.
  static Future<int> insert(BudgetModel budget) async {
    final db = await AppDatabase.instance.database;
    return await db.insert('budgets', budget.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Returns all budget rows as typed models.
  static Future<List<BudgetModel>> getAll() async {
    final db = await AppDatabase.instance.database;
    final result = await db.query('budgets');
    return result.map((e) => BudgetModel.fromMap(e)).toList();
  }

  /// Inserts or updates a budget for a recurring transaction.
  static Future<int> insertOrUpdateRecurring(BudgetModel budget) async {
    final db = await AppDatabase.instance.database;
    final rid = budget.recurringTransactionId;
    if (rid == null) {
      return await insert(budget);
    }
    // Check if we already have a budget for this recurring transaction
    final existing = await db.query(
      'budgets',
      where: 'recurring_transaction_id = ?',
      whereArgs: [rid],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final existingId = existing.first['id'] as int;
      await db.update(
        'budgets',
        budget.toMap(),
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return existingId;
    }
    return await insert(budget);
  }

  /// Deletes budgets associated with a recurring transaction ID.
  static Future<void> deleteByRecurringId(int recurringId) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'budgets',
      where: 'recurring_transaction_id = ?',
      whereArgs: [recurringId],
    );
  }

  /// Clears all non-recurring (category) budgets, preserving subscription and goal budgets.
  static Future<void> clearNonRecurring() async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'budgets',
      where: 'recurring_transaction_id IS NULL AND goal_id IS NULL',
    );
  }

  /// Clears all recurring (subscription) budgets, preserving category budgets.
  static Future<void> clearRecurring() async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'budgets',
      where: 'recurring_transaction_id IS NOT NULL',
    );
  }

  /// Sums the weekly limits from the most recent budget period for NON-GOAL
  /// budgets only. Used for dashboard left-to-spend calculations.
  ///
  /// Goal budgets are handled separately via [getGoalWeeklyBudgetTotal] to
  /// ensure goal contributions reduce left-to-spend independently of the
  /// budget overspend calculation.
  static Future<double> getTotalWeeklyBudget() async {
    final db = await AppDatabase.instance.database;
    // Always use the most recent budget set (by period_start) so
    // historical rows don't keep inflating the "weekly budget" on home.
    // Only include non-goal budgets here.
    final latestPeriod = await db.rawQuery(
      'SELECT MAX(period_start) AS latest FROM budgets WHERE goal_id IS NULL',
    );
    final period = latestPeriod.first['latest'] as String?;
    if (period == null || period.isEmpty) {
      return 0.0;
    }

    final result = await db.rawQuery(
      'SELECT SUM(weekly_limit) AS total FROM budgets WHERE period_start = ? AND goal_id IS NULL',
      [period],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Sums the weekly limits for all goal budgets (regardless of period_start).
  /// Goal contributions should reduce left-to-spend directly without affecting
  /// the budget overspend calculation.
  static Future<double> getGoalWeeklyBudgetTotal() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(weekly_limit) AS total FROM budgets WHERE goal_id IS NOT NULL',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
