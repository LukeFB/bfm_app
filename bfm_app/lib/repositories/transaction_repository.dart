import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:sqflite/sqflite.dart';

class TransactionRepository {
  static Future<int> insert(TransactionModel txn) async { // unused
    final db = await AppDatabase.instance.database;
    return await db.insert(
      'transactions',
      txn.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<TransactionModel>> getRecent(int limit) async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      'transactions',
      orderBy: 'date DESC',
      limit: limit,
    );
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  static Future<List<TransactionModel>> getAll({int? categoryId}) async {
    final db = await AppDatabase.instance.database;
    List<Map<String, dynamic>> result;

    if (categoryId != null) {
      result = await db.query(
        'transactions',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'date DESC',
      );
    } else {
      result = await db.query('transactions', orderBy: 'date DESC');
    }

    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Income – Expenses
  static Future<double> getprofit() async { // unused
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('''
      SELECT 
        (SELECT IFNULL(SUM(amount), 0) FROM transactions WHERE type = 'income') -
        (SELECT IFNULL(SUM(amount), 0) FROM transactions WHERE type = 'expense')
        AS balance
    ''');
    return (result.first['balance'] as num?)?.toDouble() ?? 0.0;
  }

  /// Totals grouped by category (expenses only)
  static Future<Map<String, double>> getCategoryTotals() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('''
      SELECT c.name as category, SUM(t.amount) as total
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'expense'
      GROUP BY c.name
    ''');

    Map<String, double> totals = {};
    for (var row in result) {
      final key = (row['category'] as String?) ?? 'Uncategorized';
      totals[key] = (row['total'] as num?)?.toDouble().abs() ?? 0.0;
    }
    return totals;
  }

  /// Expenses for the current week (Mon → today)
  static Future<double> getThisWeekExpenses() async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();

    // Monday of the current week
    final startOfWeek =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

    String fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    final start = fmt(startOfWeek);
    final end = fmt(now);

    final res = await db.rawQuery('''
      SELECT SUM(amount) AS spent
      FROM transactions
      WHERE type = 'expense'
        AND date BETWEEN ? AND ?
    ''', [start, end]);

    final raw = (res.isNotEmpty ? res.first['spent'] : null);
    final value = (raw is num) ? raw.toDouble() : 0.0;
    return value.abs();
  }

  /// Insert transactions from Akahu API payload
  /// - Ensures categories exist (by enriched name) and assigns category_id
  /// - Triggers maintain categories.usage_count
  static Future<void> insertFromAkahu(List<Map<String, dynamic>> items) async {
    final db = await AppDatabase.instance.database;
    final batch = db.batch();

    for (var item in items) {
      // Use the model’s translator
      final txn = TransactionModel.fromAkahu(item);

      // Ensure category exists (by name from enrichment), get id
      int? categoryId;
      final catName = txn.categoryName?.trim();
      if (catName != null && catName.isNotEmpty) {
        final akahuCategoryId = (item['category'] is Map<String, dynamic>)
            ? ((item['category'] as Map<String, dynamic>)['_id'] ??
                (item['category'] as Map<String, dynamic>)['id']) as String?
            : null;

        categoryId = await CategoryRepository.ensureByName(
          catName,
          akahuCategoryId: akahuCategoryId,
        );
      } else {
        categoryId = await CategoryRepository.ensureByName('Uncategorized');
      }

      final map = txn.toDbMap();
      map['category_id'] = categoryId;
      map['category_name'] = catName ?? 'Uncategorized';

      batch.insert(
        'transactions',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  static Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete("transactions");
  }
}
