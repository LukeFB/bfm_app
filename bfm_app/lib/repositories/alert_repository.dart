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
import 'package:sqflite/sqflite.dart';

/// Static helpers for alert persistence.
class AlertRepository {
  /// Inserts or replaces an alert row.
  static Future<int> insert(Map<String, dynamic> alert) async {
    final db = await AppDatabase.instance.database;
    return await db.insert('alerts', alert,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Returns every alert row for display.
  static Future<List<Map<String, dynamic>>> getAll() async {
    final db = await AppDatabase.instance.database;
    return await db.query('alerts');
  }

  /// Deletes a single alert by primary key.
  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return await db.delete('alerts', where: 'id = ?', whereArgs: [id]);
  }
}
