import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/weekly_report.dart';
import 'package:sqflite/sqflite.dart';

class WeeklyReportRepository {
  static String _iso(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

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

  static Future<List<WeeklyReportEntry>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'weekly_reports',
      orderBy: 'week_start DESC',
    );
    return rows.map((e) => WeeklyReportEntry.fromMap(e)).toList();
  }

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
}

