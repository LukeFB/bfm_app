// Author: Luke Fraser-Brown

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:sqflite/sqflite.dart';

class TransactionRepository {

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

  /// Expenses for the current week (Mon to today)
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
      final txn = TransactionModel.fromAkahu(item);

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

  // ---------------------------------------------------------------------------
  // inline categorisation helpers
  // ---------------------------------------------------------------------------

  /// Update all uncategorized expenses with an exact description match.
  static Future<int> updateUncategorizedByDescription(String description, int categoryId) async {
    final db = await AppDatabase.instance.database;
    return await db.update(
      'transactions',
      {'category_id': categoryId},
      where: "type='expense' AND category_id IS NULL AND description = ?",
      whereArgs: [description],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Fetch all distinct descriptions present in uncategorized expenses
  static Future<List<String>> getDistinctUncategorizedDescriptions({int limit = 200}) async {
    final db = await AppDatabase.instance.database;
    final res = await db.rawQuery('''
      SELECT description
      FROM transactions
      WHERE type='expense' AND category_id IS NULL
      GROUP BY description
      ORDER BY COUNT(*) DESC
      LIMIT ?
    ''', [limit]);
    return res.map((e) => (e['description'] as String?) ?? '').toList();
  }

  // Local normaliser (kept in sync with analysis)
  static String _normalizeText(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Bulk-categorise uncategorized expenses that match a **normalized
  /// description key**. Does not touch already-categorised rows.
  static Future<void> updateUncategorizedByDescriptionKey(
    String normalizedDescriptionKey,
    int newCategoryId,
  ) async {
    final db = await AppDatabase.instance.database;

    // Get name for backfill
    String? catName;
    final cat = await db.query(
      'categories',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [newCategoryId],
      limit: 1,
    );
    if (cat.isNotEmpty) catName = cat.first['name'] as String?;

    // Pull uncategorized expenses and match by normalized description
    final rows = await db.query(
      'transactions',
      columns: ['id', 'description'],
      where: "type = 'expense' AND category_id IS NULL",
    );

    final idsToUpdate = <int>[];
    for (final r in rows) {
      final id = r['id'] as int?;
      final desc = (r['description'] as String? ?? '');
      final key = _normalizeText(desc);
      if (id != null && key == normalizedDescriptionKey) {
        idsToUpdate.add(id);
      }
    }
    if (idsToUpdate.isEmpty) return;

    final batch = db.batch();
    for (final id in idsToUpdate) {
      batch.update(
        'transactions',
        {
          'category_id': newCategoryId,
          if (catName != null) 'category_name': catName,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }
}
