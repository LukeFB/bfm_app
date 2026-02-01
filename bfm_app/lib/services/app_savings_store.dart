/// ---------------------------------------------------------------------------
/// File: lib/services/app_savings_store.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Tracks "app savings" - money the user has saved by staying under budget
///   each week. This is separate from goals/accounts and represents the
///   cumulative benefit of using the app's budgeting features.
///
/// Called by:
///   - `weekly_overview_sheet.dart` to add savings when user has leftover money
///   - `savings_screen.dart` to display total app savings
///   - Recovery goal logic to use savings before creating debt
/// ---------------------------------------------------------------------------

import 'package:shared_preferences/shared_preferences.dart';

/// Tracks cumulative savings achieved through the app's budgeting system.
class AppSavingsStore {
  static const _prefsTotalKey = 'app_savings_total';
  static const _prefsHistoryKey = 'app_savings_history';

  /// Returns the total amount saved via the app.
  static Future<double> getTotal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_prefsTotalKey) ?? 0.0;
  }

  /// Adds to the savings total.
  /// Returns the new total.
  static Future<double> add(double amount) async {
    if (amount <= 0) return getTotal();
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getDouble(_prefsTotalKey) ?? 0.0;
    final newTotal = current + amount;
    await prefs.setDouble(_prefsTotalKey, newTotal);
    await _recordHistory(prefs, amount, 'add');
    return newTotal;
  }

  /// Withdraws from savings (e.g., to cover a deficit).
  /// Returns the amount actually withdrawn (may be less than requested if insufficient).
  static Future<double> withdraw(double amount) async {
    if (amount <= 0) return 0.0;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getDouble(_prefsTotalKey) ?? 0.0;
    final withdrawn = amount.clamp(0.0, current);
    final newTotal = current - withdrawn;
    await prefs.setDouble(_prefsTotalKey, newTotal);
    if (withdrawn > 0) {
      await _recordHistory(prefs, withdrawn, 'withdraw');
    }
    return withdrawn;
  }

  /// Sets the total directly (use sparingly, mainly for testing/debugging).
  static Future<void> setTotal(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsTotalKey, amount.clamp(0.0, double.infinity));
  }

  /// Clears all savings (for testing/debugging).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsTotalKey);
    await prefs.remove(_prefsHistoryKey);
  }

  /// Records a history entry for tracking contributions/withdrawals.
  static Future<void> _recordHistory(
    SharedPreferences prefs,
    double amount,
    String type,
  ) async {
    final history = prefs.getStringList(_prefsHistoryKey) ?? [];
    final entry =
        '${DateTime.now().toIso8601String()}|$type|${amount.toStringAsFixed(2)}';
    history.add(entry);
    // Keep last 52 entries (roughly a year of weekly entries)
    if (history.length > 52) {
      history.removeAt(0);
    }
    await prefs.setStringList(_prefsHistoryKey, history);
  }

  /// Gets savings history entries.
  /// Each entry is a map with 'date', 'type' ('add' or 'withdraw'), and 'amount'.
  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_prefsHistoryKey) ?? [];
    return history.map((entry) {
      final parts = entry.split('|');
      if (parts.length != 3) return <String, dynamic>{};
      return {
        'date': DateTime.tryParse(parts[0]),
        'type': parts[1],
        'amount': double.tryParse(parts[2]) ?? 0.0,
      };
    }).where((e) => e.isNotEmpty).toList();
  }
}
