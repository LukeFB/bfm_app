/// ---------------------------------------------------------------------------
/// File: lib/repositories/referral_repository.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Content sync service and referral screens when showing support options.
///
/// Purpose:
///   - Stores backend referral resources locally and filters them for UI.
///
/// Inputs:
///   - `ReferralModel` lists from the API and optional filters for queries.
///
/// Outputs:
///   - SQLite rows plus typed model lists.
/// ---------------------------------------------------------------------------
import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/referral_model.dart';
import 'package:sqflite/sqflite.dart';

/// Handles replacing and querying referral rows.
class ReferralRepository {
  /// Replaces backend-managed referral rows inside a transaction to keep the
  /// table in sync with the latest payload.
  static Future<void> replaceWithBackend(List<ReferralModel> referrals) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('referrals', where: 'backend_id IS NOT NULL');
      final nowIso = DateTime.now().toIso8601String();
      for (final referral in referrals) {
        final data = referral.toMap();
        data['synced_at'] = nowIso;
        await txn.insert(
          'referrals',
          data,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Returns active referrals filtered by optional region/category.
  static Future<List<ReferralModel>> getActive({
    int limit = 20,
    String? region,
    String? category,
  }) async {
    final db = await AppDatabase.instance.database;
    final where = StringBuffer('is_active = 1');
    final whereArgs = <dynamic>[];

    if (region != null && region.trim().isNotEmpty) {
      where.write(' AND region LIKE ?');
      whereArgs.add('%$region%');
    }

    if (category != null && category.trim().isNotEmpty) {
      where.write(' AND category LIKE ?');
      whereArgs.add('%$category%');
    }

    final rows = await db.query(
      'referrals',
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map(ReferralModel.fromMap).toList();
  }
}
