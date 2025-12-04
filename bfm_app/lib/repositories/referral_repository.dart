import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/referral_model.dart';
import 'package:sqflite/sqflite.dart';

class ReferralRepository {
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
