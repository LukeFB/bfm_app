/// ---------------------------------------------------------------------------
/// File: lib/repositories/goal_repository.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Encapsulates all SQLite interactions for goals, their mirrored budgets,
///   and weekly progress logs.
///
/// Called by:
///   `goals_screen.dart`, `dashboard_service.dart`, and `insights_service.dart`
///   whenever goals need to be persisted or summarised.
///
/// Inputs / Outputs:
///   Accepts `GoalModel` instances and raw ids. Returns primary keys, lists of
///   models, progress logs, or aggregate maps suitable for analytics.
/// ---------------------------------------------------------------------------

import 'dart:math' as math;

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/goal_progress_log.dart';
import 'package:sqflite/sqflite.dart';

/// Handles CRUD + progress tracking for goals.
class GoalRepository {
  /// Inserts the goal, then ensures there is a matching budget row so the
  /// budget builder reflects the weekly contribution. Returns the new id.
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

  /// Returns all goals sorted latest-first so the UI can show newest entries on
  /// top without extra work.
  static Future<List<GoalModel>> getAll() async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      'goals',
      orderBy: 'id DESC',
    );
    return result.map((e) => GoalModel.fromMap(e)).toList();
  }

  /// Updates the goal row (requires an id) and resyncs the mirrored budget so
  /// weekly contribution changes flow through.
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

  /// Deletes the goal plus any linked budgets inside a single transaction so
  /// we never leave orphaned budget rows behind.
  static Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('budgets', where: 'goal_id = ?', whereArgs: [id]);
      await txn.delete('goals', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Ensures there is exactly one budget row per goal with a non-zero weekly
  /// contribution. Removes the budget when the contribution is zero/invalid.
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

  /// Applies a manual contribution to a goal:
  /// - Caps the applied value to the remaining goal amount.
  /// - Updates saved_amount.
  /// - Inserts a progress-log entry tagged as manual.
  /// Returns the applied amount so callers can show confirmation.
  static Future<double> addManualContribution(
      GoalModel goal, double amount) async {
    if (goal.id == null) {
      throw ArgumentError('Goal must have an id');
    }
    final db = await AppDatabase.instance.database;
    return await db.transaction((txn) async {
      final rows = await txn.query(
        'goals',
        columns: ['amount', 'saved_amount'],
        where: 'id = ?',
        whereArgs: [goal.id],
        limit: 1,
      );
      if (rows.isEmpty) return 0.0;
      final total = (rows.first['amount'] as num?)?.toDouble() ?? goal.amount;
      final saved =
          (rows.first['saved_amount'] as num?)?.toDouble() ?? goal.savedAmount;
      final contribution = amount.isNaN ? 0.0 : amount.abs();
      if (contribution <= 0) return 0.0;
      final remaining = math.max(total - saved, 0.0);
      final applied = math.min(contribution, remaining);
      if (applied <= 0) return 0.0;

      await txn.rawUpdate(
        '''
        UPDATE goals
        SET saved_amount = saved_amount + ?
        WHERE id = ?
        ''',
        [applied, goal.id],
      );

      final weekKey = _mondayIso(DateTime.now());
      await _upsertGoalProgressAmount(
        txn,
        goal.id!,
        weekKey,
        applied,
        status: 'manual',
        note: 'Manual contribution',
      );

      return applied;
    });
  }

  /// Returns the YYYY-MM-DD string for the Monday of `reference`.
  static String _mondayIso(DateTime reference) {
    final monday = reference.subtract(Duration(days: reference.weekday - 1));
    return "${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";
  }

  /// Formats a DateTime as YYYY-MM-DD.
  static String _isoDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// Fetches a single progress log row for a given goal + week if it exists.
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

  /// Records the weekly outcome for a goal.
  /// - Optionally credits a positive amount (capped to remaining goal balance).
  /// - Writes or updates the log row with a status + note.
  /// Returns the resulting log so UI can render status immediately.
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
      final existing = await _fetchGoalProgressRow(txn, goalId, weekKey);

      double creditedAmount = 0.0;
      if (credited && amount > 0) {
        final remaining = goal.amount - goal.savedAmount;
        final cappedRemaining = remaining <= 0 ? 0.0 : remaining;
        final alreadyCredited =
            (existing?['amount'] as num?)?.toDouble() ?? 0.0;
        if (cappedRemaining > 0 && alreadyCredited < amount) {
          creditedAmount = amount - alreadyCredited;
          if (creditedAmount > cappedRemaining) {
            creditedAmount = cappedRemaining;
          }
          if (creditedAmount < 0) creditedAmount = 0.0;
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
          await _upsertGoalProgressAmount(
            txn,
            goalId,
            weekKey,
            creditedAmount,
            status: 'credited',
            note: note,
          );
        }
      }

      if (existing == null && creditedAmount == 0.0) {
        await txn.insert('goal_progress_log', {
          'goal_id': goalId,
          'week_start': weekKey,
          'status': credited ? 'skipped' : 'pending',
          'amount': 0.0,
          'note': note,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final row = await _fetchGoalProgressRow(txn, goalId, weekKey);
      return GoalProgressLog.fromMap(row!);
    });
  }

  /// Aggregates contribution totals for every goal for a specific week.
  /// Useful for dashboards that need quick per-goal bars without extra SQL.
  static Future<Map<int, double>> weeklyContributionTotals(
      DateTime weekStart) async {
    final db = await AppDatabase.instance.database;
    final weekKey = _mondayIso(weekStart);
    final rows = await db.rawQuery(
      '''
      SELECT goal_id, SUM(amount) AS total
      FROM goal_progress_log
      WHERE week_start = ?
      GROUP BY goal_id
      ''',
      [weekKey],
    );
    final Map<int, double> result = {};
    for (final row in rows) {
      final goalId = row['goal_id'] as int?;
      if (goalId == null) continue;
      result[goalId] = (row['total'] as num?)?.toDouble() ?? 0.0;
    }
    return result;
  }

  /// Internal helper to fetch a single log row for update/insert decisions.
  static Future<Map<String, dynamic>?> _fetchGoalProgressRow(
      DatabaseExecutor db, int goalId, String weekKey) async {
    final rows = await db.query(
      'goal_progress_log',
      where: 'goal_id = ? AND week_start = ?',
      whereArgs: [goalId, weekKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Inserts or updates a progress log row by adding `delta` to the stored
  /// amount. Keeps status/note in sync so downstream views stay accurate.
  static Future<void> _upsertGoalProgressAmount(
    DatabaseExecutor db,
    int goalId,
    String weekKey,
    double delta, {
    String status = 'manual',
    String? note,
  }) async {
    if (delta <= 0) return;
    final existing = await _fetchGoalProgressRow(db, goalId, weekKey);
    final now = DateTime.now().toIso8601String();
    if (existing == null) {
      await db.insert('goal_progress_log', {
        'goal_id': goalId,
        'week_start': weekKey,
        'status': status,
        'amount': delta,
        'note': note,
        'created_at': now,
      });
    } else {
      final current = (existing['amount'] as num?)?.toDouble() ?? 0.0;
      final update = <String, Object?>{
        'amount': current + delta,
      };
      if (status.isNotEmpty) update['status'] = status;
      if (note != null) update['note'] = note;
      await db.update(
        'goal_progress_log',
        update,
        where: 'goal_id = ? AND week_start = ?',
        whereArgs: [goalId, weekKey],
      );
    }
  }
}
