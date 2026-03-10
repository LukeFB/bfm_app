/// Shared formatting and parsing utilities used across multiple screens.

const List<String> kMonthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats a date as "DD Mon YYYY", e.g. "05 Mar 2026".
String friendlyDate(DateTime date) {
  final month = kMonthAbbreviations[date.month - 1];
  final day = date.day.toString().padLeft(2, '0');
  return '$day $month ${date.year}';
}

/// Short date label, e.g. "Mar 5".
String shortDate(DateTime date) {
  return '${kMonthAbbreviations[date.month - 1]} ${date.day}';
}

/// Formats a currency value, omitting decimals for amounts >= $100.
String formatCurrency(double value) {
  final decimals = value.abs() >= 100 ? 0 : 2;
  return '\$${value.toStringAsFixed(decimals)}';
}

/// Parses a user-entered currency string into a double, stripping non-numeric
/// characters. Returns 0 for empty or unparseable input.
double parseCurrency(String raw) {
  if (raw.trim().isEmpty) return 0.0;
  final sanitized = raw.replaceAll(RegExp(r'[^0-9\.\-]'), '');
  final value = double.tryParse(sanitized);
  if (value == null || value.isNaN || value.isInfinite) return 0.0;
  return value;
}

/// Returns the ISO date string for Monday of the current week.
String currentMondayIso() {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final month = monday.month.toString().padLeft(2, '0');
  final day = monday.day.toString().padLeft(2, '0');
  return '${monday.year}-$month-$day';
}
