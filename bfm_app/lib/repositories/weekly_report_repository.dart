/// ---------------------------------------------------------------------------
/// File: lib/repositories/weekly_report_repository.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Insights service/screens responsible for storing and reading weekly
///     insight snapshots.
///
/// Purpose:
///   - Persists full weekly reports in SQLite and exposes query helpers.
///
/// Inputs:
///   - `WeeklyInsightsReport` instances or week start dates.
///
/// Outputs:
///   - Stored JSON blobs and typed report entries.
/// ---------------------------------------------------------------------------
import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/weekly_report.dart';
import 'package:sqflite/sqflite.dart';

/// Handles persistence of weekly insights report blobs.
class WeeklyReportRepository {
  /// Formats dates to ISO days for consistent keying.
  static String _iso(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// Inserts or replaces the report for the specified week.
  static Future<void> upsert(WeeklyInsightsReport report) async {
    final db = await AppDatabase.instance.database;
    final payload = report.toEncodedJson();
    await db.insert(
      'weekly_reports',
      {
        'week_start': report.weekStartIso,
        'week_end': report.weekEndIso,
        'data': payload,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns every stored report entry ordered by most recent week first.
  static Future<List<WeeklyReportEntry>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'weekly_reports',
      orderBy: 'week_start DESC',
    );
    return rows.map((e) => WeeklyReportEntry.fromMap(e)).toList();
  }

  /// Fetches a single report by its week start date.
  static Future<WeeklyInsightsReport?> getByWeek(DateTime weekStart) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'weekly_reports',
      where: 'week_start = ?',
      whereArgs: [_iso(weekStart)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WeeklyInsightsReport.fromEncodedJson(rows.first['data'] as String);
  }

  /// Clears all weekly reports. Used when disconnecting bank to reset user data.
  static Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('weekly_reports');
  }
}

