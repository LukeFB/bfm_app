import 'package:shared_preferences/shared_preferences.dart';
import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/budget_model.dart';

/// Persists the Buxly Buffer recovery budget — a hidden budget that reserves
/// weekly income to pay back a negative non-essential buffer over N weeks.
///
/// The budget is stored in the `budgets` table with a special label so it
/// counts toward total weekly budgets (reducing "Left to spend") but is
/// filtered out on the Budgets screen.
class BuxlyBufferBudgetStore {
  static const bufferBudgetLabel = '__buxly_buffer_budget__';
  static const _keyWeeks = 'buxly_buffer_budget_weeks';

  static Future<int?> getWeeks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyWeeks);
  }

  /// Saves the buffer budget with [weeks] and [weeklyAmount] into both
  /// SharedPreferences (weeks) and the budgets table (amount).
  static Future<void> save({
    required int weeks,
    required double weeklyAmount,
  }) async {
    if (weeks <= 0 || weeklyAmount <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyWeeks, weeks);

    final periodStart = await _getLatestPeriodStart();
    final db = await AppDatabase.instance.database;

    await db.delete('budgets',
        where: 'label = ?', whereArgs: [bufferBudgetLabel]);

    await db.insert(
      'budgets',
      BudgetModel(
        label: bufferBudgetLabel,
        weeklyLimit: weeklyAmount,
        periodStart: periodStart,
      ).toMap(),
    );
  }

  /// Removes the buffer budget from both SharedPreferences and the DB.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyWeeks);

    final db = await AppDatabase.instance.database;
    await db.delete('budgets',
        where: 'label = ?', whereArgs: [bufferBudgetLabel]);
  }

  /// Returns the existing buffer budget row, or null if none.
  static Future<BudgetModel?> getExisting() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('budgets',
        where: 'label = ?', whereArgs: [bufferBudgetLabel], limit: 1);
    if (rows.isEmpty) return null;
    return BudgetModel.fromMap(rows.first);
  }

  /// Uses the latest existing budget period so the buffer budget is included
  /// in `getTotalWeeklyBudget()`. Falls back to the current Monday.
  static Future<String> _getLatestPeriodStart() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      "SELECT MAX(period_start) AS latest FROM budgets "
      "WHERE label IS NULL OR label != ?",
      [bufferBudgetLabel],
    );
    final latest = result.first['latest'] as String?;
    if (latest != null && latest.isNotEmpty) return latest;

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return "${monday.year}-${monday.month.toString().padLeft(2, '0')}"
        "-${monday.day.toString().padLeft(2, '0')}";
  }
}
