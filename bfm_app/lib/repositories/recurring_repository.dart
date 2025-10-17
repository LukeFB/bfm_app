// Author: Luke Fraser-Brown

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/recurring_transaction_model.dart';
import 'package:sqflite/sqflite.dart';

class RecurringRepository {
  static Future<int> insert(RecurringTransactionModel bill) async {
    final db = await AppDatabase.instance.database;
    return await db.insert('recurring_transactions', bill.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
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
}
