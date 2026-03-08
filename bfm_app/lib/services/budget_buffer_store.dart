// ---------------------------------------------------------------------------
// File: lib/services/budget_buffer_store.dart
// Author: Luke Fraser-Brown
//
// Purpose:
//   Tracks per-budget buffer amounts — money put aside from weekly surpluses
//   for each individual budget. When a budget has leftover, the surplus is
//   added to that budget's buffer. If a budget is overspent, its buffer
//   absorbs the cost. If a buffer goes negative, app savings cover it.
//
// Called by:
//   - `weekly_overview_sheet.dart` to process weekly buffer contributions
//   - `budgets_screen.dart` to display per-budget buffer balances
//   - `context_builder.dart` to include buffer data in chatbot context
// ---------------------------------------------------------------------------

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent store for per-budget buffer balances.
class BudgetBufferStore {
  static const _prefsBuffersKey = 'budget_buffer_map';
  static const _prefsLastContribsKey = 'budget_buffer_last_contribs';
  static const _prefsLastWeekKey = 'budget_buffer_last_week';

  /// Returns per-budget buffer amounts keyed by budget label.
  static Future<Map<String, double>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsBuffersKey);
    if (json == null) return {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  /// Returns last week's per-budget contributions (can be negative).
  static Future<Map<String, double>> getLastContributions() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsLastContribsKey);
    if (json == null) return {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  /// Returns the week start date string of the last processed contribution.
  static Future<String?> getLastProcessedWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsLastWeekKey);
  }

  /// Applies per-budget weekly contributions. Each entry: positive = surplus
  /// added, negative = overspend drawn from that budget's buffer. If a
  /// budget's buffer goes negative, [onNegative] is called with that
  /// individual deficit so the caller can withdraw from app savings.
  static Future<Map<String, double>> applyWeeklyContributions({
    required Map<String, double> contributions,
    required String weekStart,
    Future<double> Function(double deficit)? onNegative,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getAll();
    final updated = <String, double>{};

    for (final entry in contributions.entries) {
      final label = entry.key;
      final contrib = entry.value;
      var balance = (current[label] ?? 0.0) + contrib;
      if (balance < 0 && onNegative != null) {
        await onNegative(balance.abs());
        balance = 0.0;
      }
      updated[label] = balance.clamp(0.0, double.infinity);
    }

    // Carry forward any existing buffers not in this week's contributions
    for (final entry in current.entries) {
      if (!updated.containsKey(entry.key)) {
        updated[entry.key] = entry.value;
      }
    }

    await prefs.setString(_prefsBuffersKey, jsonEncode(updated));
    await prefs.setString(_prefsLastContribsKey, jsonEncode(contributions));
    await prefs.setString(_prefsLastWeekKey, weekStart);
    return updated;
  }

  /// Clears all buffer data.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsBuffersKey);
    await prefs.remove(_prefsLastContribsKey);
    await prefs.remove(_prefsLastWeekKey);
  }
}
