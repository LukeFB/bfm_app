// Author: Luke Fraser-Brown

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/budget_model.dart';
import 'package:sqflite/sqflite.dart';

class BudgetRepository {

  static Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('budgets');
  }

  static Future<int> insert(BudgetModel budget) async {
    final db = await AppDatabase.instance.database;
    return await db.insert('budgets', budget.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<BudgetModel>> getAll() async {
    final db = await AppDatabase.instance.database;
    final result = await db.query('budgets');
    return result.map((e) => BudgetModel.fromMap(e)).toList();
  }

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
