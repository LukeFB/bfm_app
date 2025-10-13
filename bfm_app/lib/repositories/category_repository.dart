//FIle: category_repository.dart
// Author: Luke Fraser-Brown

import 'package:bfm_app/db/app_database.dart';
import 'package:sqflite/sqflite.dart';

class CategoryRepository {
  static Future<int> insert(Map<String, dynamic> category) async {
    final db = await AppDatabase.instance.database;
    // Use IGNORE so we don't reset usage_count on name conflicts
    return await db.insert(
      'categories',
      category,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    final db = await AppDatabase.instance.database;
    return await db.query('categories');
  }

  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  /// Ensure a row exists for [name]. Returns the category id.
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

  /// Categories ordered by popularity, then name.
  static Future<List<Map<String, dynamic>>> getAllOrderedByUsage({int? limit}) async {
    final db = await AppDatabase.instance.database;
    return await db.query(
      'categories',
      orderBy: 'usage_count DESC, name ASC',
      limit: limit,
    );
  }

  /// Increment usage_count when a transaction is categorised.
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
