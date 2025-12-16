/// ---------------------------------------------------------------------------
/// File: lib/repositories/recurring_repository.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Budget analysis service and insights flows for recurring bill tracking.
///
/// Purpose:
///   - Stores and retrieves recurring transaction heuristics.
///
/// Inputs:
///   - `RecurringTransactionModel` objects and optional description keys.
///
/// Outputs:
///   - Inserted IDs plus typed lists of recurring entries.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/recurring_transaction_model.dart';
import 'package:sqflite/sqflite.dart';

/// CRUD helpers for the `recurring_transactions` table.
class RecurringRepository {
  /// Upserts a recurring bill based on lowercased description + frequency so
  /// duplicates collapse into a single row.
  static Future<int> insert(RecurringTransactionModel bill) async {
    final db = await AppDatabase.instance.database;
    final descKey = _normalizedDescription(bill.description);
    final freqKey = bill.frequency.trim().toLowerCase();
    final payload = {
      'category_id': bill.categoryId,
      'amount': bill.amount,
      'frequency': freqKey,
      'next_due_date': bill.nextDueDate,
      'description': bill.description?.trim(),
    };
    final nowIso = DateTime.now().toIso8601String();

    if (descKey != null) {
      final existing = await db.query(
        'recurring_transactions',
        columns: ['id'],
        where: 'LOWER(description) = ? AND LOWER(frequency) = ?',
        whereArgs: [descKey, freqKey],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final id = existing.first['id'] as int;
        await db.update(
          'recurring_transactions',
          {
            ...payload,
            'updated_at': nowIso,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await db.delete(
          'recurring_transactions',
          where: 'LOWER(description) = ? AND LOWER(frequency) = ? AND id <> ?',
          whereArgs: [descKey, freqKey, id],
        );
        return id;
      }
    }

    return await db.insert(
      'recurring_transactions',
      {
        ...payload,
        'created_at': nowIso,
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns every stored recurring transaction as domain models.
  static Future<List<RecurringTransactionModel>> getAll() async {
    final db = await AppDatabase.instance.database;
    final result = await db.query('recurring_transactions');
    return result.map((e) => RecurringTransactionModel.fromMap(e)).toList();
  }

  /// Removes all recurring rows (used for debug resets).
  static Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('recurring_transactions');
  }

  /// Shared helper to normalise strings for case-insensitive comparisons.
  static String? _normalizedDescription(String? value) {
    if (value == null) return null;
    final trimmed = value.trim().toLowerCase();
    return trimmed.isEmpty ? null : trimmed;
  }
}
