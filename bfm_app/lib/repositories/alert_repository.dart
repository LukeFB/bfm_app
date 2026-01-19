/// ---------------------------------------------------------------------------
/// File: lib/repositories/alert_repository.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Dashboard services and sync jobs when reading/writing alerts.
///
/// Purpose:
///   - Provides simple CRUD helpers around the `alerts` table so callers do not
///     need to reference sqflite directly.
///
/// Inputs:
///   - SQLite maps describing alert text/icon pairs.
///
/// Outputs:
///   - IDs of inserted rows and lists of alert maps.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/alert_model.dart';
import 'package:sqflite/sqflite.dart';

/// Static helpers for alert persistence.
class AlertRepository {
  /// Inserts or replaces an alert row.
  static Future<int> insert(AlertModel alert) async {
    final db = await AppDatabase.instance.database;
    return await db.insert(
      'alerts',
      alert.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<AlertModel>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('alerts');
    return rows.map(AlertModel.fromMap).toList();
  }

  static Future<List<AlertModel>> getActiveRecurring() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'alerts',
      where: 'is_active = 1 AND recurring_transaction_id IS NOT NULL',
    );
    return rows.map(AlertModel.fromMap).toList();
  }

  static Future<void> upsertRecurringAlert({
    required int recurringId,
    required String title,
    String? message,
    String? icon,
    int leadTimeDays = 3,
  }) async {
    final db = await AppDatabase.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    await db.delete(
      'alerts',
      where: 'recurring_transaction_id = ?',
      whereArgs: [recurringId],
    );
    await db.insert(
      'alerts',
      {
        'title': title,
        'message': message,
        'icon': icon,
        'recurring_transaction_id': recurringId,
        'lead_time_days': leadTimeDays,
        'is_active': 1,
        'created_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteByRecurringId(int recurringId) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'alerts',
      where: 'recurring_transaction_id = ?',
      whereArgs: [recurringId],
    );
  }

  static Future<void> deleteAllNotIn(Set<int> recurringIds) async {
    if (recurringIds.isEmpty) {
      final db = await AppDatabase.instance.database;
      await db.delete('alerts', where: 'recurring_transaction_id IS NOT NULL');
      return;
    }
    final placeholders = List.filled(recurringIds.length, '?').join(', ');
    final db = await AppDatabase.instance.database;
    await db.delete(
      'alerts',
      where:
          'recurring_transaction_id IS NOT NULL AND recurring_transaction_id NOT IN ($placeholders)',
      whereArgs: recurringIds.toList(),
    );
  }

  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return await db.delete('alerts', where: 'id = ?', whereArgs: [id]);
  }
}
