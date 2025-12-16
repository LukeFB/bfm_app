/// ---------------------------------------------------------------------------
/// File: lib/repositories/category_repository.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Handles CRUD and lookup helpers for the categories table.
///
/// Called by:
///   `transaction_repository.dart`, `budget_build_screen.dart`,
///   and `insights_service.dart`.
///
/// Inputs / Outputs:
///   Works directly with raw maps so callers can submit partial data and get
///   back ids or query results.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// Thin repository around the `categories` table.
class CategoryRepository {
  /// Inserts a category map. Uses `OR IGNORE` so re-inserting an existing name
  /// does not reset usage statistics.
  static Future<int> insert(Map<String, dynamic> category) async {
    final db = await AppDatabase.instance.database;
    // Use IGNORE so we don't reset usage_count on name conflicts
    return await db.insert(
      'categories',
      category,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Returns every category row as-is.
  static Future<List<Map<String, dynamic>>> getAll() async {
    final db = await AppDatabase.instance.database;
    return await db.query('categories');
  }

  /// Removes a category by id. Returns number of rows deleted.
  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  /// Ensures a row exists for [name] (case-insensitive) and returns its id.
  /// Also backfills Akahu metadata and icon/color if provided later.
  static Future<int> ensureByName(
    String name, {
    String? akahuCategoryId,
    String? icon,
    String? color,
  }) async {
    name = name.trim().isEmpty ? 'Uncategorized' : name.trim();
    final db = await AppDatabase.instance.database;

    final existing = await db.query(
      'categories',
      where: 'name COLLATE NOCASE = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      // optionally update metadata we just learned
      final updateMap = <String, Object?>{};
      if (akahuCategoryId != null) updateMap['akahu_category_id'] = akahuCategoryId;
      if (icon != null) updateMap['icon'] = icon;
      if (color != null) updateMap['color'] = color;
      if (updateMap.isNotEmpty) {
        updateMap['last_used_at'] = DateTime.now().toIso8601String();
        await db.update('categories', updateMap, where: 'id = ?', whereArgs: [id]);
      }
      return id;
    }

    final id = await db.insert('categories', {
      'name': name,
      'icon': icon,
      'color': color,
      'akahu_category_id': akahuCategoryId,
      'usage_count': 0,
      'first_seen_at': DateTime.now().toIso8601String(),
      'last_used_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    if (id == 0) {
      final again = await db.query(
        'categories',
        where: 'name COLLATE NOCASE = ?',
        whereArgs: [name],
        limit: 1,
      );
      return again.first['id'] as int;
    }
    return id;
  }

  /// Returns a map of id -> name for the provided ids. Useful for analytics
  /// that already have numeric foreign keys.
  static Future<Map<int, String>> getNamesByIds(Iterable<int> ids) async {
    final unique = ids.toSet();
    if (unique.isEmpty) return {};
    final db = await AppDatabase.instance.database;
    final placeholders = List.filled(unique.length, '?').join(',');
    final rows = await db.query(
      'categories',
      columns: ['id', 'name'],
      where: 'id IN ($placeholders)',
      whereArgs: unique.toList(),
    );
    final map = <int, String>{};
    for (final row in rows) {
      final id = row['id'] as int?;
      final name = row['name'] as String?;
      if (id != null && name != null) {
        map[id] = name;
      }
    }
    return map;
  }

  /// Returns categories sorted by usage_count desc then name asc.
  static Future<List<Map<String, dynamic>>> getAllOrderedByUsage({int? limit}) async {
    final db = await AppDatabase.instance.database;
    return await db.query(
      'categories',
      orderBy: 'usage_count DESC, name ASC',
      limit: limit,
    );
  }

  /// Increments `usage_count` and updates `last_used_at`. Called whenever we
  /// categorise a transaction or detect recurring usage.
  static Future<void> incrementUsage(int id, {int by = 1}) async {
    final db = await AppDatabase.instance.database;
    await db.rawUpdate('''
      UPDATE categories
      SET usage_count = IFNULL(usage_count, 0) + ?,
          last_used_at = ?
      WHERE id = ?
    ''', [by, DateTime.now().toIso8601String(), id]);
  }
}
