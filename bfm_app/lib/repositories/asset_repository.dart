/// ---------------------------------------------------------------------------
/// File: lib/repositories/asset_repository.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   - CRUD operations for user-entered assets.
///   - Used by SavingsService to calculate total asset value.
///
/// Called by:
///   - `SavingsService` for loading assets.
///   - `SavingsScreen` for add/edit/delete operations.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/asset_model.dart';

/// Repository for managing user assets.
class AssetRepository {
  /// Retrieves all assets ordered by value descending.
  static Future<List<AssetModel>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'assets',
      orderBy: 'value DESC',
    );
    return rows.map((row) => AssetModel.fromMap(row)).toList();
  }

  /// Retrieves assets grouped by category.
  static Future<Map<AssetCategory, List<AssetModel>>> getGroupedByCategory() async {
    final assets = await getAll();
    final grouped = <AssetCategory, List<AssetModel>>{};
    for (final asset in assets) {
      grouped.putIfAbsent(asset.category, () => []).add(asset);
    }
    return grouped;
  }

  /// Gets the total value of all assets.
  static Future<double> getTotalValue() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(value), 0) as total FROM assets',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Inserts a new asset.
  static Future<int> insert(AssetModel asset) async {
    final db = await AppDatabase.instance.database;
    return await db.insert('assets', asset.toMap());
  }

  /// Updates an existing asset.
  static Future<int> update(AssetModel asset) async {
    if (asset.id == null) return 0;
    final db = await AppDatabase.instance.database;
    return await db.update(
      'assets',
      asset.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [asset.id],
    );
  }

  /// Deletes an asset by ID.
  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return await db.delete(
      'assets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Gets a single asset by ID.
  static Future<AssetModel?> getById(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'assets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AssetModel.fromMap(rows.first);
  }
}
