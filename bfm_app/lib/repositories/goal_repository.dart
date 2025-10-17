// Author: Luke Fraser-Brown

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:sqflite/sqflite.dart';

class GoalRepository {
  static Future<int> insert(GoalModel goal) async {
    final db = await AppDatabase.instance.database;
    return await db.insert('goals', goal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<GoalModel>> getAll() async {
    final db = await AppDatabase.instance.database;
    final result = await db.query('goals');
    return result.map((e) => GoalModel.fromMap(e)).toList();
  }

  static Future<int> update(int id, Map<String, dynamic> values) async {
    final db = await AppDatabase.instance.database;
    return await db
        .update('goals', values, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }
}
