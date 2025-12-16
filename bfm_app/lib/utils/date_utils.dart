/// ---------------------------------------------------------------------------
/// File: lib/utils/date_utils.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Widgets and services that need lightweight date formatting without
///     dragging in intl.
///
/// Purpose:
///   - Groups the tiny helpers so UI files stay readable.
///
/// Inputs:
///   - ISO date strings passed in by callers.
///
/// Outputs:
///   - Readable labels safe for UI rendering.
///
/// Notes:
///   - Keep this file tiny; larger formatting logic belongs in dedicated libs.
/// ---------------------------------------------------------------------------

/// Simple namespace for hand-written date helpers.
class DateUtilsBFM {
  /// Turns an ISO `YYYY-MM-DD` string into a 3-letter weekday label used in the
  /// UI. Parsing failures fall back to the input so we never throw while drawing.
  static String weekdayLabel(String ymd) {
    try {
      final d = DateTime.parse(ymd);
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[d.weekday - 1];
    } catch (_) {
      return ymd;
    }
  }
}
