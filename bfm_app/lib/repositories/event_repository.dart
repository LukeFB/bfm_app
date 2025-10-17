// Author: Luke Fraser-Brown

import 'package:bfm_app/db/app_database.dart';
import 'package:sqflite/sqflite.dart';

class EventRepository {
  static Future<int> insert(Map<String, dynamic> event) async {
    final db = await AppDatabase.instance.database;
    return await db.insert('events', event,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    final db = await AppDatabase.instance.database;
    return await db.query('events');
  }

  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }
}
