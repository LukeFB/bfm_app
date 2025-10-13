import 'package:bfm_app/db/app_database.dart';
import 'package:sqflite/sqflite.dart';

class TestDataService {
  static Future<void> addTestData() async {
    final db = await AppDatabase.instance.database;

    // Add categories
    await db.insert('categories', {
      'id': 1,
      'name': 'Groceries',
      'icon': 'shopping_cart',
      'color': '#FF8C00'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('categories', {
      'id': 2,
      'name': 'Transport',
      'icon': 'directions_bus',
      'color': '#005494'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('categories', {
      'id': 3,
      'name': 'Entertainment',
      'icon': 'movie',
      'color': '#FF1493'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Add budgets
    await db.insert('budgets', {
      'category_id': 1,
      'weekly_limit': 50.0,
      'period_start': '2025-10-13',
      'period_end': '2025-10-19'
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('budgets', {
      'category_id': 2,
      'weekly_limit': 30.0,
      'period_start': '2025-10-13',
      'period_end': '2025-10-19'
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('budgets', {
      'category_id': 3,
      'weekly_limit': 20.0,
      'period_start': '2025-10-13',
      'period_end': '2025-10-19'
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
