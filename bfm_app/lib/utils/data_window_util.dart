/// ---------------------------------------------------------------------------
/// File: lib/utils/data_window_util.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Services like `budget_analysis_service.dart` when normalising spend.
///
/// Purpose:
///   - Reads the transaction table once and derives a safe date window so we
///     can express totals per-week without guessing.
///
/// Inputs:
///   - `AppDatabase` transactions table. No external parameters required.
///
/// Outputs:
///   - Tuple containing start/end ISO strings plus derived day/week spans.
///
/// Notes:
///   - Using the actual window avoids overstating weekly spend when the dataset
///     is short, and keeps the logic reusable across screens.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';

/// Wraps raw database lookups for transaction windows.
class DataWindowUtil {
  /// Formats a DateTime into `YYYY-MM-DD` so analytics stay ISO-friendly.
  static String _fmt(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// Queries the DB for the first/last transaction dates, falls back to "now"
  /// when empty, clamps the day span, and returns pre-formatted values plus the
  /// derived week count. Callers use this to scale totals to per-week numbers.
  static Future<({String start, String end, int days, double weeks})>
      getTransactionDateWindow() async {
    final db = await AppDatabase.instance.database;
    final row = (await db.rawQuery(
      'SELECT MIN(date) AS start, MAX(date) AS end FROM transactions WHERE excluded = 0',
    ))
        .first;

    final now = DateTime.now();
    final startStr = (row['start'] as String?) ?? _fmt(now);
    final endStr   = (row['end']   as String?) ?? _fmt(now);

    DateTime parse(String s) { try { return DateTime.parse(s); } catch (_) { return now; } }

    final start = parse(startStr);
    final end   = parse(endStr);
    final int days  = ((end.difference(start).inDays).abs() + 1).clamp(1, 3650);
    final double weeks = days / 7.0;
    return (start: _fmt(start), end: _fmt(end), days: days, weeks: weeks < 1.0 ? 1.0 : weeks);
  }
}
