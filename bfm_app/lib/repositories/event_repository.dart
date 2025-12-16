/// ---------------------------------------------------------------------------
/// File: lib/repositories/event_repository.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Content sync service and dashboard when showing training/events.
///
/// Purpose:
///   - Handles replacing and querying events stored locally.
///
/// Inputs:
///   - `EventModel` lists from the backend or query limits.
///
/// Outputs:
///   - Stored rows inside SQLite and typed lists for consumers.
/// ---------------------------------------------------------------------------
import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/event_model.dart';
import 'package:sqflite/sqflite.dart';

/// Provides transactional helpers for the `events` table.
class EventRepository {
  /// Wipes existing backend-backed rows and re-inserts the provided list inside
  /// one transaction so the dashboard always sees a coherent dataset.
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

  /// Returns future events ordered by end date.
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

  /// Removes every event row, used for logout/debug flows.
  static Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('events');
  }
}
