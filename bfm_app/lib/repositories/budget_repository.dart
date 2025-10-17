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
    final result =
        await db.rawQuery('SELECT SUM(weekly_limit) as total FROM budgets');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
