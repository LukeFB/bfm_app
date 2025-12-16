/// ---------------------------------------------------------------------------
/// File: lib/repositories/tip_repository.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Content sync service and dashboard service.
///
/// Purpose:
///   - Persists CMS-provided tips and exposes a helper to fetch the featured one.
///
/// Inputs:
///   - Lists of `TipModel` instances or query parameters.
///
/// Outputs:
///   - SQLite rows and optionally a single featured tip.
/// ---------------------------------------------------------------------------
import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/tip_model.dart';
import 'package:sqflite/sqflite.dart';

/// Data access helper for the `tips` table.
class TipRepository {
  /// Replaces backend-managed tips inside a transaction.
  static Future<void> replaceWithBackend(List<TipModel> tips) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('tips', where: 'backend_id IS NOT NULL');
      final nowIso = DateTime.now().toIso8601String();
      for (final tip in tips) {
        final data = tip.toMap();
        data['synced_at'] = nowIso;
        await txn.insert(
          'tips',
          data,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Returns the most relevant active tip ordered by expiry/updated date.
  static Future<TipModel?> getFeatured() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'tips',
      where: 'is_active = 1',
      orderBy: 'expires_at ASC, updated_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return TipModel.fromMap(rows.first);
  }
}
