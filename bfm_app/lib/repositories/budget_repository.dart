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

  static Future<double> getLeftToSpend(int categoryId) async { // unused
    final db = await AppDatabase.instance.database;

    // Weekly limit
    final limitResult = await db.query(
      'budgets',
      columns: ['weekly_limit'],
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
    if (limitResult.isEmpty) return 0.0;
    double weeklyLimit = (limitResult.first['weekly_limit'] as num).toDouble();

    // Start and end of current week
    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    String start = startOfWeek.toIso8601String().substring(0, 10);
    String end = now.toIso8601String().substring(0, 10);

    // Spent this week
    final spentResult = await db.rawQuery('''
      SELECT SUM(amount) as spent
      FROM transactions
      WHERE category_id = ?
        AND type = 'expense'
        AND date BETWEEN ? AND ?
    ''', [categoryId, start, end]);

    double spent =
        (spentResult.first['spent'] as num?)?.toDouble().abs() ?? 0.0;

    return weeklyLimit - spent;
  }

  static Future<Map<String, dynamic>> getMonthlySummary( // unused
      int year, int month) async {
    final db = await AppDatabase.instance.database;

    String start =
        DateTime(year, month, 1).toIso8601String().substring(0, 10);
    String end =
        DateTime(year, month + 1, 1).toIso8601String().substring(0, 10);

    // Spent
    final spentResult = await db.rawQuery('''
      SELECT SUM(amount) as spent
      FROM transactions
      WHERE type = 'expense'
        AND date BETWEEN ? AND ?
    ''', [start, end]);

    double spent =
        (spentResult.first['spent'] as num?)?.toDouble().abs() ?? 0.0;

    // Budget
    final budgetResult = await db.rawQuery('''
      SELECT SUM(weekly_limit) as budget
      FROM budgets
      WHERE date(period_start) BETWEEN ? AND ?
         OR date(period_end) BETWEEN ? AND ?
    ''', [start, end, start, end]);

    double budget =
        (budgetResult.first['budget'] as num?)?.toDouble() ?? 0.0;

    return {"budget": budget, "spent": spent, "left": budget - spent};
  }
}
