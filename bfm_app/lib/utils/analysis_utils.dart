/// ---------------------------------------------------------------------------
/// File: analysis_utils.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Small helpers used across analytics screens:
///     - Global date range for transactions (min/max).
///     - Safe week span calculation.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';

class AnalysisUtils {
  /// Returns { 'first': 'YYYY-MM-DD'?, 'last': 'YYYY-MM-DD'? }
  static Future<Map<String, String?>> getGlobalDateRange() async {
    final db = await AppDatabase.instance.database;
    final res = await db.rawQuery('''
      SELECT MIN(date) AS first, MAX(date) AS last FROM transactions
    ''');
    if (res.isEmpty) return {'first': null, 'last': null};
    return {
      'first': res.first['first'] as String?,
      'last':  res.first['last']  as String?,
    };
  }

  /// Weeks spanned by [first..last], clamped to [1, 52].
  static double observedWeeks(String? first, String? last) {
    if (first == null || last == null || first.isEmpty || last.isEmpty) return 1.0;
    try {
      final d1 = DateTime.parse(first);
      final d2 = DateTime.parse(last);
      final days = (d2.difference(d1).inDays + 1).clamp(7, 365);
      return (days / 7.0).clamp(1.0, 52.0);
    } catch (_) {
      return 1.0;
    }
  }
}
