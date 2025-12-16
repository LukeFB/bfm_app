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

  /// Sums the weekly limits from the most recent budget period. Used for
  /// dashboard left-to-spend calculations.
  static Future<double> getTotalWeeklyBudget() async {
    final db = await AppDatabase.instance.database;
    // Always use the most recent budget set (by period_start) so
    // historical rows don’t keep inflating the “weekly budget” on home.
    final latestPeriod = await db.rawQuery(
      'SELECT MAX(period_start) AS latest FROM budgets',
    );
    final period = latestPeriod.first['latest'] as String?;
    if (period == null || period.isEmpty) {
      return 0.0;
    }

    final result = await db.rawQuery(
      'SELECT SUM(weekly_limit) AS total FROM budgets WHERE period_start = ?',
      [period],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
