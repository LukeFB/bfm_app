/// ---------------------------------------------------------------------------
/// File: lib/repositories/transaction_repository.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Sync flows, analytics services, dashboards, and transaction screens.
///
/// Purpose:
///   - Centralises all reads/writes for the `transactions` table plus helper
///     aggregations for weekly spend, category totals, etc.
///
/// Inputs:
///   - Raw Akahu payloads, manual `TransactionModel` instances, date ranges.
///
/// Outputs:
///   - Persisted rows, typed transaction lists, and aggregate maps/doubles.
///
/// Notes:
///   - Keep heavy transforms here so UI/services stay light.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:sqflite/sqflite.dart';

/// Data access helpers for the `transactions` table plus related analytics.
class TransactionRepository {

  /// Returns the latest `limit` transactions ordered by date descending.
  static Future<List<TransactionModel>> getRecent(int limit) async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      'transactions',
      orderBy: 'date DESC',
      limit: limit,
    );
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  /// Returns every transaction, optionally filtered by category id.
  static Future<List<TransactionModel>> getAll({
    int? categoryId,
    bool includeExcluded = true,
  }) async {
    final db = await AppDatabase.instance.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    if (categoryId != null) {
      whereClauses.add('category_id = ?');
      whereArgs.add(categoryId);
    }
    if (!includeExcluded) {
      whereClauses.add('excluded = 0');
    }
    final result = await db.query(
      'transactions',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereClauses.isEmpty ? null : whereArgs,
      orderBy: 'date DESC',
    );

    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  /// Deletes a transaction by primary key.
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
        AND t.excluded = 0
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
        AND excluded = 0
    ''', [start, end]);

    final raw = (res.isNotEmpty ? res.first['spent'] : null);
    final value = (raw is num) ? raw.toDouble() : 0.0;
    return value.abs();
  }

  /// Sums expenses grouped by category between the provided dates. Returns a
  /// map keyed by category id (nullable for uncategorized).
  /// Excludes transfers (type = 'transfer').
  static Future<Map<int?, double>> sumExpensesByCategoryBetween(
      DateTime start, DateTime end) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT category_id, ABS(SUM(amount)) AS spent
      FROM transactions
      WHERE type = 'expense'
        AND excluded = 0
        AND date BETWEEN ? AND ?
      GROUP BY category_id
    ''', [_iso(start), _iso(end)]);
    final map = <int?, double>{};
    for (final row in rows) {
      final catId = row['category_id'] as int?;
      final spent = (row['spent'] as num?)?.toDouble() ?? 0.0;
      map[catId] = spent;
    }
    return map;
  }

  /// Totals income transactions between the provided dates.
  /// Excludes transfers (type = 'transfer').
  static Future<double> sumIncomeBetween(
      DateTime start, DateTime end) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT SUM(amount) AS income
      FROM transactions
      WHERE type = 'income'
        AND excluded = 0
        AND date BETWEEN ? AND ?
    ''', [_iso(start), _iso(end)]);
    final value = rows.isNotEmpty ? rows.first['income'] : null;
    return (value is num) ? value.toDouble() : 0.0;
  }

  /// Returns transactions between the provided dates sorted by newest first.
  /// Excludes transfers (type = 'transfer') by default.
  static Future<List<TransactionModel>> getBetween(
      DateTime start, DateTime end, {bool excludeTransfers = true}) async {
    final db = await AppDatabase.instance.database;
    if (excludeTransfers) {
      final rows = await db.query(
        'transactions',
        where: "date BETWEEN ? AND ? AND type != 'transfer'",
        whereArgs: [_iso(start), _iso(end)],
        orderBy: 'date DESC',
      );
      return rows.map((e) => TransactionModel.fromMap(e)).toList();
    }
    final rows = await db.query(
      'transactions',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [_iso(start), _iso(end)],
      orderBy: 'date DESC',
    );
    return rows.map((e) => TransactionModel.fromMap(e)).toList();
  }

  /// Insert transactions from Akahu API payload
  /// - Ensures categories exist (by enriched name) and assigns category_id
  /// - Triggers maintain categories.usage_count
  static Future<void> insertFromAkahu(List<Map<String, dynamic>> items) async {
    await upsertFromAkahu(items);
  }

  /// Writes Akahu payloads to SQLite, ensuring categories exist and batching
  /// inserts for speed. Replaces matching rows by `akahu_hash`.
  static Future<void> upsertFromAkahu(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final db = await AppDatabase.instance.database;

    final transactions = <TransactionModel>[];
    final hashes = <String>[];
    for (final item in items) {
      final txn = TransactionModel.fromAkahu(item);
      transactions.add(txn);
      final hash = txn.akahuHash?.trim();
      if (hash != null && hash.isNotEmpty) {
        hashes.add(hash);
      }
    }

    final existingExcludedByHash = <String, int>{};
    if (hashes.isNotEmpty) {
      final unique = hashes.toSet().toList();
      const chunkSize = 400;
      for (var i = 0; i < unique.length; i += chunkSize) {
        final end = (i + chunkSize) > unique.length ? unique.length : (i + chunkSize);
        final chunk = unique.sublist(i, end);
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = await db.rawQuery(
          'SELECT akahu_hash, excluded FROM transactions WHERE akahu_hash IN ($placeholders)',
          chunk,
        );
        for (final row in rows) {
          final hash = row['akahu_hash'] as String?;
          if (hash == null) continue;
          final excludedFlag = _boolFromDb(row['excluded']) ? 1 : 0;
          existingExcludedByHash[hash] = excludedFlag;
        }
      }
    }

    final batch = db.batch();

    for (var i = 0; i < transactions.length; i++) {
      final txn = transactions[i];
      final item = items[i];
      final categoryId = await _resolveCategoryId(item, txn);
      final map = txn.toDbMap();
      map['category_id'] = categoryId;
      map['category_name'] = txn.categoryName ?? 'Uncategorized';
      final hash = txn.akahuHash;
      if (hash != null && existingExcludedByHash.containsKey(hash)) {
        map['excluded'] = existingExcludedByHash[hash];
      }
      batch.insert(
        'transactions',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Persists a manually created transaction (usually from admin/debug tools).
  /// When the model has an existing id, replaces that row; otherwise inserts new.
  static Future<int> insertManual(TransactionModel model) async {
    final db = await AppDatabase.instance.database;
    return await db.insert(
      'transactions',
      model.toDbMap(includeId: true),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ensures there is a category row for the given transaction and returns its
  /// id. Falls back to "Uncategorized" when no name exists.
  static Future<int> _resolveCategoryId(
    Map<String, dynamic> raw,
    TransactionModel txn,
  ) async {
    final catName = txn.categoryName?.trim();
    if (catName == null || catName.isEmpty) {
      return CategoryRepository.ensureByName('Uncategorized');
    }

    // Extract Akahu category ID from nested object or flat field
    String? akahuCategoryId;
    for (final key in ['category', 'akahu_category']) {
      final rawCat = raw[key];
      if (rawCat is Map<String, dynamic>) {
        akahuCategoryId =
            (rawCat['_id'] ?? rawCat['id'] ?? rawCat['akahu_id'])?.toString();
        if (akahuCategoryId != null) break;
      }
    }
    akahuCategoryId ??= raw['category_id']?.toString();

    return CategoryRepository.ensureByName(
      catName,
      akahuCategoryId: akahuCategoryId,
    );
  }

  /// Removes every transaction row. Intended for debug resets.
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
      WHERE type='expense'
        AND excluded = 0
        AND category_id IS NULL
      GROUP BY description
      ORDER BY COUNT(*) DESC
      LIMIT ?
    ''', [limit]);
    return res.map((e) => (e['description'] as String?) ?? '').toList();
  }

  /// Toggles whether a transaction should be ignored by spend calculations.
  static Future<void> setExcluded({
    required int id,
    required bool excluded,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'transactions',
      {'excluded': excluded ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static bool _boolFromDb(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      return normalized == '1' ||
          normalized == 'true' ||
          normalized == 'yes';
    }
    return false;
  }

  /// Local normaliser (kept in sync with analysis) that lowercases and collapses
  /// whitespace while preserving digits for accurate grouping.
  static String _normalizeText(String raw) {
    return raw
        .toLowerCase()
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

  /// Formats a DateTime as YYYY-MM-DD so SQL comparisons stay consistent.
  static String _iso(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// Expense totals grouped by normalized uncategorized key (description).
  /// Includes both truly uncategorized (null category_id) and transactions
  /// assigned to the "Uncategorized" category.
  /// Transfers are already excluded by type = 'expense' filter.
  static Future<Map<String, double>> sumExpensesByUncategorizedKeyBetween(
      DateTime start, DateTime end) async {
    final db = await AppDatabase.instance.database;
    // Query for both null category_id AND transactions in the "Uncategorized" category
    final rows = await db.rawQuery('''
      SELECT t.description, t.amount
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'expense'
        AND t.excluded = 0
        AND t.date BETWEEN ? AND ?
        AND (t.category_id IS NULL OR LOWER(c.name) IN ('uncategorized', 'uncategorised'))
    ''', [_iso(start), _iso(end)]);
    final map = <String, double>{};
    for (final row in rows) {
      final desc = (row['description'] as String?) ?? '';
      var key = _normalizeText(desc);
      // Use a placeholder key for empty descriptions so they're still tracked
      if (key.isEmpty) key = '_unnamed_transaction';
      final amount = (row['amount'] as num?)?.toDouble().abs() ?? 0.0;
      map[key] = (map[key] ?? 0) + amount;
    }
    return map;
  }

  /// Friendly descriptions for uncategorized keys within the provided range.
  /// Includes both truly uncategorized (null category_id) and transactions
  /// assigned to the "Uncategorized" category.
  /// Transfers are already excluded by type = 'expense' filter.
  static Future<Map<String, String>> getDisplayNamesForUncategorizedKeys(
    Set<String> keys,
    DateTime start,
    DateTime end,
  ) async {
    if (keys.isEmpty) return const {};
    final db = await AppDatabase.instance.database;
    // Query for both null category_id AND transactions in the "Uncategorized" category
    final rows = await db.rawQuery('''
      SELECT t.description
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'expense'
        AND t.excluded = 0
        AND t.date BETWEEN ? AND ?
        AND (t.category_id IS NULL OR LOWER(c.name) IN ('uncategorized', 'uncategorised'))
      ORDER BY t.date DESC
    ''', [_iso(start), _iso(end)]);
    final result = <String, String>{};
    // Handle the unnamed transaction placeholder
    if (keys.contains('_unnamed_transaction')) {
      result['_unnamed_transaction'] = 'Unnamed Transaction';
    }
    for (final row in rows) {
      final desc = (row['description'] as String?) ?? '';
      if (desc.trim().isEmpty) continue;
      final key = _normalizeText(desc);
      if (keys.contains(key) && !result.containsKey(key)) {
        result[key] = desc;
        if (result.length == keys.length) break;
      }
    }
    return result;
  }

  /// Returns true when at least one non-excluded transaction exists for `day`.
  static Future<bool> hasTransactionsOn(DateTime day) async {
    final db = await AppDatabase.instance.database;
    final normalized = DateTime(day.year, day.month, day.day);
    final target = _iso(normalized);
    final rows = await db.rawQuery(
      '''
      SELECT 1
      FROM transactions
      WHERE date = ?
        AND excluded = 0
      LIMIT 1
      ''',
      [target],
    );
    return rows.isNotEmpty;
  }

  /// Returns true when at least one non-excluded transaction exists between
  /// [start] and [end] (inclusive).
  static Future<bool> hasTransactionsBetween(DateTime start, DateTime end) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT 1
      FROM transactions
      WHERE date BETWEEN ? AND ?
        AND excluded = 0
      LIMIT 1
      ''',
      [_iso(start), _iso(end)],
    );
    return rows.isNotEmpty;
  }
}
