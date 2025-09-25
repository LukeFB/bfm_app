import 'package:bfm_app/db/app_database.dart';
import 'package:sqflite/sqflite.dart';

class AlertRepository {
  static Future<int> insert(Map<String, dynamic> alert) async {
    final db = await AppDatabase.instance.database;
    return await db.insert('alerts', alert,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    final db = await AppDatabase.instance.database;
    return await db.query('alerts');
  }

  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return await db.delete('alerts', where: 'id = ?', whereArgs: [id]);
  }
}
