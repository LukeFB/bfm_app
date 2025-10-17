/// ---------------------------------------------------------------------------
/// File: lib/utils/data_window_util.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Utility to compute the effective data window from the transactions table
///   (first/last transaction date), and derive the number of weeks for
///   normalising totals to $/week.
///
/// Returns:
///   - start: 'YYYY-MM-DD'
///   - end:   'YYYY-MM-DD'
///   - days:  inclusive day span (>= 1)
///   - weeks: max(1.0, days / 7.0)
///
/// Notes:
///   - Using the actual window avoids over/under-estimating weekly spend when
///     you only have ~1 month of data.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';

class DataWindowUtil {
  static String _fmt(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  static Future<({String start, String end, int days, double weeks})>
      getTransactionDateWindow() async {
    final db = await AppDatabase.instance.database;
    final row = (await db.rawQuery('SELECT MIN(date) AS start, MAX(date) AS end FROM transactions')).first;

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
