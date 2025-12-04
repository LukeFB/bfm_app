import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/event_model.dart';
import 'package:sqflite/sqflite.dart';

class EventRepository {
  static Future<void> replaceWithBackend(List<EventModel> events) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('events', where: 'backend_id IS NOT NULL');
      final nowIso = DateTime.now().toIso8601String();
      for (final event in events) {
        final data = event.toMap();
        data['synced_at'] = nowIso;
        await txn.insert(
          'events',
          data,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<List<EventModel>> getUpcoming({int limit = 5}) async {
    final db = await AppDatabase.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    final rows = await db.query(
      'events',
      where: 'end_date IS NOT NULL AND end_date >= ?',
      whereArgs: [nowIso],
      orderBy: 'end_date ASC',
      limit: limit,
    );
    return rows.map(EventModel.fromMap).toList();
  }

  static Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('events');
  }
}
