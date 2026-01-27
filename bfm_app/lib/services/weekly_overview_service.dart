/// ---------------------------------------------------------------------------
/// File: lib/services/weekly_overview_service.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Determines when the Monday weekly overview should appear and prepares the
///   payload (insights report + goal list) for the UI to render.
///
/// Called by:
///   `dashboard_screen.dart` once the dashboard data finishes loading.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/weekly_report.dart';
import 'package:bfm_app/models/weekly_overview_summary.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/weekly_report_repository.dart';
import 'package:bfm_app/services/insights_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bundle of data required to render the weekly overview sheet.
class WeeklyOverviewPayload {
  final DateTime weekStart;
  final WeeklyInsightsReport report;
  final WeeklyOverviewSummary summary;
  final List<GoalModel> goals;

  const WeeklyOverviewPayload({
    required this.weekStart,
    required this.report,
    required this.summary,
    required this.goals,
  });

  DateTime get weekEnd => summary.weekEnd;
}

/// Entry point for determining if/when to show the Monday weekly overview.
class WeeklyOverviewService {
  static const _prefsLastWeekKey = 'weekly_overview_last_week';

  /// Returns a payload when all trigger conditions are met, otherwise null.
  static Future<WeeklyOverviewPayload?> buildPayloadIfEligible() async {
    if (!await _shouldTrigger()) return null;
    final targetWeekStart = _previousWeekStart(DateTime.now());
    return _buildPayloadForWeek(targetWeekStart);
  }

  /// Builds a payload for the prior week regardless of trigger rules.
  static Future<WeeklyOverviewPayload?> buildPayloadForLastWeek() async {
    final targetWeekStart = _previousWeekStart(DateTime.now());
    return _buildPayloadForWeek(targetWeekStart);
  }

  /// Saves a weekly report to persist for streak tracking.
  /// Call this when the user finishes the weekly overview to record the
  /// "left to spend" value for budget streak calculations.
  static Future<void> saveReport(WeeklyInsightsReport report) async {
    await WeeklyReportRepository.upsert(report);
  }

  /// Records that the overview for the provided week has been surfaced.
  static Future<void> markOverviewHandled(DateTime weekStart) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLastWeekKey, _iso(weekStart));
  }

  /// Resets the "last shown" marker (useful for QA or debugging).
  static Future<void> resetLastShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLastWeekKey);
  }

  static Future<bool> _shouldTrigger() async {
    final prefs = await SharedPreferences.getInstance();
    final bankConnected = prefs.getBool('bank_connected') ?? false;
    if (!bankConnected) return false;

    final today = DateTime.now();
    if (today.weekday != DateTime.monday) return false;

    // Check for any transactions in the current week (Mon-Sun).
    // Bank transactions often have dates from when the purchase was made,
    // not when they post/sync, so checking for "transactions dated Monday"
    // would miss purchases made over the weekend that sync on Monday.
    final mondayThisWeek = DateTime(today.year, today.month, today.day);
    final sundayThisWeek = mondayThisWeek.add(const Duration(days: 6));
    final hasCurrentWeekTxn =
        await TransactionRepository.hasTransactionsBetween(mondayThisWeek, sundayThisWeek);
    if (!hasCurrentWeekTxn) return false;

    final targetWeekStart = _previousWeekStart(today);
    final lastShownIso = prefs.getString(_prefsLastWeekKey);
    if (lastShownIso == _iso(targetWeekStart)) return false;

    return true;
  }

  static Future<WeeklyOverviewPayload?> _buildPayloadForWeek(
      DateTime weekStart) async {
    final report = await InsightsService.generateReportForWeek(
      weekStart,
      persist: true,
      usePreviousWeekIncome: false,
    );
    final summary = report.overviewSummary;
    if (summary == null) return null;
    // Only include savings goals (not recovery) for the regular contribution section
    // Recovery goals are loaded separately in the WeeklyOverviewSheet
    final goals = (await GoalRepository.getSavingsGoals())
        .where((goal) => !goal.isComplete)
        .toList();
    return WeeklyOverviewPayload(
      weekStart: weekStart,
      report: report,
      summary: summary,
      goals: goals,
    );
  }

  static DateTime _previousWeekStart(DateTime reference) {
    final normalized = DateTime(reference.year, reference.month, reference.day);
    final mondayThisWeek =
        normalized.subtract(Duration(days: normalized.weekday - DateTime.monday));
    return mondayThisWeek.subtract(const Duration(days: 7));
  }

  static String _iso(DateTime day) =>
      "${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
}
