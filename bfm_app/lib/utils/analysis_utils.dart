/// ---------------------------------------------------------------------------
/// File: lib/utils/analysis_utils.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `budget_analysis_service.dart`, dashboards, and any widget needing
///     canonical transaction ranges for normalising weekly spend.
///
/// Purpose:
///   - Wraps bits of SQL needed by analytics flows so the logic stays testable
///     and we keep week calculations consistent across services.
///
/// Inputs:
///   - Relies on `AppDatabase` transactions table plus provided ISO date strings.
///
/// Outputs:
///   - Map objects describing min/max transaction dates and derived week counts.
///
/// Notes:
///   - Keep these helpers pure/static so they can be reused anywhere without
///     pulling extra dependencies into widgets.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';

/// Shared analytics helpers for looking up transaction spans and normalised
/// week counts.
class AnalysisUtils {
  /// Runs a tiny aggregate query to fetch the earliest and latest transaction
  /// dates so callers can normalise spending windows. Returns both values as a
  /// simple map with nullable ISO strings.
  static Future<Map<String, String?>> getGlobalDateRange() async {
    final db = await AppDatabase.instance.database;
    final res = await db.rawQuery('''
      SELECT MIN(date) AS first, MAX(date) AS last
      FROM transactions
      WHERE excluded = 0
    ''');
    if (res.isEmpty) return {'first': null, 'last': null};
    return {
      'first': res.first['first'] as String?,
      'last':  res.first['last']  as String?,
    };
  }

  /// Takes the raw `first`/`last` ISO strings and turns them into an observed
  /// week span. Handles empty strings, parse failures, and clamps the value to
  /// sane bounds so downstream maths never blows up.
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
