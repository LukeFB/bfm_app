/// ---------------------------------------------------------------------------
/// File: lib/services/budget_streak_service.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Calculates budget streak data from stored weekly reports - counts
///   consecutive weeks where the user had money "left to spend" and sums
///   the total saved across those weeks.
///
/// Called by:
///   `dashboard_service.dart` and `dashboard_screen.dart` for streak display.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/repositories/weekly_report_repository.dart';

/// Holds calculated streak data for dashboard display.
class BudgetStreakData {
  /// Number of consecutive weeks the user met their budget.
  final int streakWeeks;

  /// Total amount saved across those streak weeks (sum of "left to spend").
  final double totalSaved;

  const BudgetStreakData({
    required this.streakWeeks,
    required this.totalSaved,
  });

  /// Default empty state when no streak data is available.
  static const empty = BudgetStreakData(streakWeeks: 0, totalSaved: 0);
}

/// Calculates budget streak metrics from weekly report history.
class BudgetStreakService {
  /// Calculates the current budget streak and total saved.
  ///
  /// A streak week is one where `discretionaryLeft` > 0 in the weekly overview.
  /// Counts backwards from most recent week until finding a week where
  /// the user went over budget.
  static Future<BudgetStreakData> calculateStreak() async {
    final reports = await WeeklyReportRepository.getAll();
    if (reports.isEmpty) {
      return BudgetStreakData.empty;
    }

    int streakCount = 0;
    double totalSaved = 0.0;

    // Reports are ordered by week_start DESC (most recent first)
    for (final entry in reports) {
      final summary = entry.report.overviewSummary;
      if (summary == null) continue;

      // Check if user had money left to spend (met their budget)
      final leftToSpend = summary.discretionaryLeft;
      if (leftToSpend > 0) {
        streakCount++;
        totalSaved += leftToSpend;
      } else {
        // Streak broken - stop counting
        break;
      }
    }

    return BudgetStreakData(
      streakWeeks: streakCount,
      totalSaved: totalSaved,
    );
  }
}
