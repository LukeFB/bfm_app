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

  static Future<void> update(AlertModel alert) async {
    if (alert.id == null) {
      throw ArgumentError('Cannot update alert without an id');
    }
    final db = await AppDatabase.instance.database;
    await db.update(
      'alerts',
      alert.toMap(),
      where: 'id = ?',
      whereArgs: [alert.id],
    );
  }

  static Future<List<AlertModel>> getAll() async {
    final db = await AppDatabase.instance.database;
    // Sort by due_date ascending, with nulls at the end
    final rows = await db.rawQuery('''
      SELECT * FROM alerts
      ORDER BY 
        CASE WHEN due_date IS NULL THEN 1 ELSE 0 END,
        due_date ASC
    ''');
    return rows.map(AlertModel.fromMap).toList();
  }

  static Future<List<AlertModel>> getActiveRecurring() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'alerts',
      where: "is_active = 1 AND recurring_transaction_id IS NOT NULL AND type = ?",
      whereArgs: [AlertType.recurring],
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
      where: "recurring_transaction_id = ? AND type = ?",
      whereArgs: [recurringId, AlertType.recurring],
    );
    await db.insert(
      'alerts',
      {
        'title': title,
        'message': message,
        'icon': icon,
        'recurring_transaction_id': recurringId,
        'amount': null,
        'due_date': null,
        'lead_time_days': leadTimeDays,
        'is_active': 1,
        'type': AlertType.recurring,
        'created_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes only recurring-type alerts for a given recurring transaction.
  /// Cancel-subscription alerts are preserved.
  static Future<void> deleteByRecurringId(int recurringId) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'alerts',
      where: "recurring_transaction_id = ? AND type = ?",
      whereArgs: [recurringId, AlertType.recurring],
    );
  }

  /// Deletes ALL alerts (recurring + cancel) for a given recurring transaction.
  /// Used by the subscriptions screen to ensure a clean slate before
  /// re-creating the correct alert type based on the user's selection.
  static Future<void> deleteAllAlertsByRecurringId(int recurringId) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'alerts',
      where: "recurring_transaction_id = ?",
      whereArgs: [recurringId],
    );
  }

  static Future<void> deleteAllNotIn(Set<int> recurringIds) async {
    final db = await AppDatabase.instance.database;
    if (recurringIds.isEmpty) {
      await db.delete(
        'alerts',
        where: "recurring_transaction_id IS NOT NULL AND type = ?",
        whereArgs: [AlertType.recurring],
      );
      return;
    }
    final placeholders = List.filled(recurringIds.length, '?').join(', ');
    await db.delete(
      'alerts',
      where:
          "recurring_transaction_id IS NOT NULL AND type = ? AND recurring_transaction_id NOT IN ($placeholders)",
      whereArgs: [AlertType.recurring, ...recurringIds.toList()],
    );
  }

  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return await db.delete('alerts', where: 'id = ?', whereArgs: [id]);
  }

  /// Creates a "cancel this subscription" alert tied to a recurring transaction.
  /// Skips creation if one already exists for the same recurring ID.
  static Future<int> insertCancelSubscription({
    required int recurringId,
    required String title,
    String? icon,
    double? amount,
  }) async {
    final db = await AppDatabase.instance.database;
    // Avoid duplicates
    final existing = await db.query(
      'alerts',
      where: "recurring_transaction_id = ? AND type = ?",
      whereArgs: [recurringId, AlertType.cancelSubscription],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as int;

    return await db.insert(
      'alerts',
      {
        'title': title,
        'message': 'Consider cancelling this subscription to save money.',
        'icon': icon,
        'recurring_transaction_id': recurringId,
        'amount': amount,
        'type': AlertType.cancelSubscription,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Marks a cancel-subscription alert as completed (done / cancelled by user).
  static Future<void> markCompleted(int alertId) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'alerts',
      {
        'completed_at': DateTime.now().toIso8601String(),
        'is_active': 0,
      },
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  /// Returns active cancel-subscription alerts that haven't been completed.
  static Future<List<AlertModel>> getActiveCancelAlerts() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'alerts',
      where: "type = ? AND is_active = 1 AND completed_at IS NULL",
      whereArgs: [AlertType.cancelSubscription],
    );
    return rows.map(AlertModel.fromMap).toList();
  }

  /// Clears all alerts. Used when disconnecting bank to reset user data.
  static Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('alerts');
  }
}
