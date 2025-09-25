import 'package:bfm_app/db/app_database.dart';
import 'package:sqflite/sqflite.dart';

class CategoryRepository {
  static Future<int> insert(Map<String, dynamic> category) async {
    final db = await AppDatabase.instance.database;
    return await db.insert('categories', category,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    final db = await AppDatabase.instance.database;
    return await db.query('categories');
  }

  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
