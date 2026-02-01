/// ---------------------------------------------------------------------------
/// File: lib/services/income_settings_store.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Manages user preference for income calculation mode (regular vs non-regular)
///   and handles auto-detection of income regularity from transaction history.
///
/// Called by:
///   - `dashboard_service.dart` when calculating weekly income
///   - `settings_screen.dart` for the income type toggle
///   - `bank_service.dart` for auto-detection after initial sync
/// ---------------------------------------------------------------------------

import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user has regular (predictable) or non-regular (variable) income.
enum IncomeType {
  /// Regular income: uses last week's income as the estimate.
  regular,

  /// Non-regular income: uses average weekly income over the last 4 weeks.
  nonRegular,
}

/// Persists and retrieves income calculation preferences.
class IncomeSettingsStore {
  static const _incomeTypeKey = 'income_type';
  static const _autoDetectedKey = 'income_type_auto_detected';

  /// Returns the current income type preference.
  /// Defaults to [IncomeType.regular] if not set.
  static Future<IncomeType> getIncomeType() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_incomeTypeKey);
    if (value == 'nonRegular') return IncomeType.nonRegular;
    return IncomeType.regular;
  }

  /// Persists the user's income type preference.
  static Future<void> setIncomeType(IncomeType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _incomeTypeKey,
      type == IncomeType.nonRegular ? 'nonRegular' : 'regular',
    );
  }

  /// Returns true if the income type was auto-detected (not manually set).
  static Future<bool> wasAutoDetected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoDetectedKey) ?? false;
  }

  /// Marks that the income type was auto-detected.
  static Future<void> markAutoDetected(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoDetectedKey, value);
  }

  /// Clears all income settings (used when disconnecting bank).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_incomeTypeKey);
    await prefs.remove(_autoDetectedKey);
  }

  /// Analyzes transaction history to determine if income is regular or not.
  ///
  /// Detects non-regular income if:
  /// - Any week in the last 4 weeks had zero income (missed week)
  /// - Any week had income less than 50% of the average (much lower than normal)
  ///
  /// Returns the detected [IncomeType] and saves it to preferences.
  static Future<IncomeType> detectAndSetIncomeType() async {
    final weeklyIncomes = await _getWeeklyIncomesForLastMonth();

    // If we don't have enough data, default to regular
    if (weeklyIncomes.isEmpty) {
      await setIncomeType(IncomeType.regular);
      await markAutoDetected(true);
      return IncomeType.regular;
    }

    // Calculate average (excluding zero weeks for the comparison threshold)
    final nonZeroIncomes = weeklyIncomes.where((i) => i > 0).toList();
    if (nonZeroIncomes.isEmpty) {
      // No income at all - default to regular
      await setIncomeType(IncomeType.regular);
      await markAutoDetected(true);
      return IncomeType.regular;
    }

    final average =
        nonZeroIncomes.reduce((a, b) => a + b) / nonZeroIncomes.length;
    final threshold = average * 0.5; // 50% of average

    // Check for missed weeks (zero income) or much lower than normal
    bool hasIrregularity = false;
    for (final income in weeklyIncomes) {
      if (income == 0) {
        // Missed week
        hasIrregularity = true;
        break;
      }
      if (income < threshold) {
        // Much lower than normal (less than 50% of average)
        hasIrregularity = true;
        break;
      }
    }

    final detectedType =
        hasIrregularity ? IncomeType.nonRegular : IncomeType.regular;
    await setIncomeType(detectedType);
    await markAutoDetected(true);
    return detectedType;
  }

  /// Returns weekly income totals for the last 4 complete weeks.
  /// Each entry represents total income for one Monday-Sunday period.
  static Future<List<double>> _getWeeklyIncomesForLastMonth() async {
    final now = DateTime.now();
    // Start from the Monday of the current week
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));

    final weeklyIncomes = <double>[];

    // Get income for each of the last 4 complete weeks
    for (int weeksBack = 1; weeksBack <= 4; weeksBack++) {
      final weekStart = currentMonday.subtract(Duration(days: 7 * weeksBack));
      final weekEnd = weekStart.add(const Duration(days: 6));

      final income = await TransactionRepository.sumIncomeBetween(
        weekStart,
        weekEnd,
      );
      weeklyIncomes.add(income);
    }

    return weeklyIncomes;
  }
}
