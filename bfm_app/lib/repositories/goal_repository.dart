// Author: Luke Fraser-Brown

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/goal_progress_log.dart';
import 'package:sqflite/sqflite.dart';

class GoalRepository {
  static Future<int> insert(GoalModel goal) async {
    final db = await AppDatabase.instance.database;
    return await db.transaction((txn) async {
      final id = await txn.insert('goals', goal.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      final goalWithId = goal.copyWith(id: id);
      await _syncGoalBudget(txn, goalWithId);
      return id;
    });
  }

  static Future<List<GoalModel>> getAll() async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      'goals',
      orderBy: 'id DESC',
    );
    return result.map((e) => GoalModel.fromMap(e)).toList();
  }

  static Future<void> update(GoalModel goal) async {
    if (goal.id == null) {
      throw ArgumentError('Cannot update goal without an id');
    }
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.update('goals', goal.toMap(),
          where: 'id = ?', whereArgs: [goal.id]);
      await _syncGoalBudget(txn, goal);
    });
  }

  static Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('budgets', where: 'goal_id = ?', whereArgs: [id]);
      await txn.delete('goals', where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<void> _syncGoalBudget(
      DatabaseExecutor db, GoalModel goal) async {
    if (goal.id == null) return;
    final safeContribution = goal.weeklyContribution.isNaN ||
            goal.weeklyContribution < 0
        ? 0.0
        : goal.weeklyContribution;
    if (safeContribution <= 0) {
      await db.delete('budgets', where: 'goal_id = ?', whereArgs: [goal.id]);
      return;
    }

    final now = DateTime.now();
    final periodStart = _mondayIso(now);
    final label = goal.name.trim().isEmpty ? 'Goal' : goal.name.trim();
    final values = <String, dynamic>{
      'goal_id': goal.id,
      'category_id': null,
      'label': label,
      'weekly_limit': safeContribution,
      'period_start': periodStart,
      'period_end': null,
      'updated_at': now.toIso8601String(),
    };

    final existing = await db.query(
      'budgets',
      where: 'goal_id = ?',
      whereArgs: [goal.id],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert('budgets', values,
          conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.update('budgets', values,
          where: 'goal_id = ?', whereArgs: [goal.id]);
    }
  }

  static Future<double> addManualContribution(
      GoalModel goal, double amount) async {
    if (goal.id == null) {
      throw ArgumentError('Goal must have an id');
    }
    final contribution = amount.isNaN ? 0.0 : amount.abs();
    if (contribution <= 0) return 0.0;
    double remaining = goal.amount - goal.savedAmount;
    if (remaining < 0) remaining = 0;
    final applied = remaining <= 0
        ? 0.0
        : contribution > remaining
            ? remaining
            : contribution;
    if (applied <= 0) return 0.0;
    final db = await AppDatabase.instance.database;
    await db.rawUpdate(
      '''
      UPDATE goals
      SET saved_amount = saved_amount + ?
      WHERE id = ?
      ''',
      [applied, goal.id],
    );
    return applied;
  }

  static String _mondayIso(DateTime reference) {
    final monday = reference.subtract(Duration(days: reference.weekday - 1));
    return "${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";
  }

  static String _isoDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  static Future<GoalProgressLog?> getProgressLogForWeek(
      int goalId, DateTime weekStart) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'goal_progress_log',
      where: 'goal_id = ? AND week_start = ?',
      whereArgs: [goalId, _isoDate(weekStart)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GoalProgressLog.fromMap(rows.first);
  }

  static Future<GoalProgressLog> recordWeeklyOutcome({
    required GoalModel goal,
    required DateTime weekStart,
    required bool credited,
    required double amount,
    String? note,
  }) async {
    if (goal.id == null) {
      throw ArgumentError('Goal must have an id to record progress');
    }
    final goalId = goal.id!;
    final db = await AppDatabase.instance.database;
    final weekKey = _isoDate(weekStart);
    return await db.transaction((txn) async {
      final existing = await txn.query(
        'goal_progress_log',
        where: 'goal_id = ? AND week_start = ?',
        whereArgs: [goalId, weekKey],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return GoalProgressLog.fromMap(existing.first);
      }

      double creditedAmount = 0.0;
      if (credited && amount > 0) {
        final remaining = goal.amount - goal.savedAmount;
        final cappedRemaining = remaining <= 0 ? 0.0 : remaining;
        if (cappedRemaining <= 0) {
          creditedAmount = 0.0;
        } else {
          creditedAmount = amount;
          if (creditedAmount > cappedRemaining) {
            creditedAmount = cappedRemaining;
          }
          if (creditedAmount < 0) {
            creditedAmount = 0.0;
          }
        }
        if (creditedAmount > 0) {
          await txn.rawUpdate(
            '''
            UPDATE goals
            SET saved_amount = saved_amount + ?
            WHERE id = ?
            ''',
            [creditedAmount, goalId],
          );
        }
      }

      final status = credited && creditedAmount > 0 ? 'credited' : 'skipped';
      final id = await txn.insert(
        'goal_progress_log',
        {
          'goal_id': goalId,
          'week_start': weekKey,
          'status': status,
          'amount': creditedAmount,
          'note': note,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      final row = id > 0
          ? await txn.query(
              'goal_progress_log',
              where: 'id = ?',
              whereArgs: [id],
              limit: 1,
            )
          : await txn.query(
              'goal_progress_log',
              where: 'goal_id = ? AND week_start = ?',
              whereArgs: [goalId, weekKey],
              limit: 1,
            );

      return GoalProgressLog.fromMap(row.first);
    });
  }
}
