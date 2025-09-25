/// ---------------------------------------------------------------------------
/// File: date_utils.dart
/// Author: Luke Fraser-Brown
/// Description:
///   Centralizes small date/time helper functions that are reused in UI.
///   Keeps the main screens clean of low-level formatting logic.
/// ---------------------------------------------------------------------------

class DateUtilsBFM {
  /// Returns a short weekday label (e.g. "Mon", "Tue").
  ///
  /// Input: date string in ISO format ("YYYY-MM-DD").
  /// If parsing fails, returns the original string to avoid runtime errors.
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
