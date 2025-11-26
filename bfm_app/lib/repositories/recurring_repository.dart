// Author: Luke Fraser-Brown

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/recurring_transaction_model.dart';
import 'package:sqflite/sqflite.dart';

class RecurringRepository {
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

  static Future<List<RecurringTransactionModel>> getAll() async {
    final db = await AppDatabase.instance.database;
    final result = await db.query('recurring_transactions');
    return result.map((e) => RecurringTransactionModel.fromMap(e)).toList();
  }

  static Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('recurring_transactions');
  }

  static String? _normalizedDescription(String? value) {
    if (value == null) return null;
    final trimmed = value.trim().toLowerCase();
    return trimmed.isEmpty ? null : trimmed;
  }
}
