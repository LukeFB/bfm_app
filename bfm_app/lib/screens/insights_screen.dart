/// ---------------------------------------------------------------------------
/// File: lib/screens/insights_screen.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `/insights` route from the bottom navigation.
///
/// Purpose:
///   - Shows the weekly insights report, top categories, goal outcomes, and
///     historical reports.
///
/// Inputs:
///   - `InsightsService` data (current report + history).
///
/// Outputs:
///   - Rich cards and charts summarising weekly performance.
/// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';

import 'package:bfm_app/models/weekly_report.dart';
import 'package:bfm_app/services/insights_service.dart';
import 'package:bfm_app/widgets/weekly_report_widgets.dart';

/// Screen for viewing weekly insights snapshots.
class InsightsScreen extends StatefulWidget {
  /// When true, the screen is embedded in MainShell.
  final bool embedded;

  const InsightsScreen({super.key, this.embedded = false});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

/// Internal container bundling the latest report plus saved history.
class _InsightsPayload {
  final WeeklyInsightsReport currentReport;
  final List<WeeklyReportEntry> history;
  const _InsightsPayload({required this.currentReport, required this.history});
  
  /// All reports: current week first, then history (most recent first)
  List<WeeklyInsightsReport> get allReports {
    final reports = <WeeklyInsightsReport>[currentReport];
    for (final entry in history) {
      // Avoid duplicating the current week if it's already in history
      if (entry.report.weekStartIso != currentReport.weekStartIso) {
        reports.add(entry.report);
      }
    }
    return reports;
  }
}

/// Handles fetching reports, pull-to-refresh, and navigation through reports.
class _InsightsScreenState extends State<InsightsScreen> {
  late Future<_InsightsPayload> _future;
  int _currentIndex = 0;

  /// Seeds the Future when the screen mounts.
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Generates the latest report and pulls stored history entries.
  Future<_InsightsPayload> _load() async {
    final report = await InsightsService.generateWeeklyReport();
    final history = await InsightsService.getSavedReports();
    return _InsightsPayload(currentReport: report, history: history);
  }

  /// Rebuilds the Future and waits for it so pull-to-refresh can complete.
  Future<void> _refresh() async {
    setState(() {
      _currentIndex = 0;
      _future = _load();
    });
    await _future;
  }

  void _goToPrevious(int maxIndex) {
    if (_currentIndex < maxIndex) {
      setState(() => _currentIndex++);
    }
  }

  void _goToNext() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  String _formatDateRange(DateTime start, DateTime end) {
    String fmt(DateTime d) => "${d.day}/${d.month}/${d.year}";
    return "${fmt(start)} - ${fmt(end)}";
  }

  /// Renders the insights cards with navigation.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Insights & Reports")),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_InsightsPayload>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    "Unable to build report:\n${snapshot.error}",
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              );
            }
            final payload = snapshot.data!;
            final allReports = payload.allReports;
            
            // Clamp index in case data changed
            final safeIndex = _currentIndex.clamp(0, allReports.length - 1);
            final report = allReports[safeIndex];
            final maxIndex = allReports.length - 1;
            final canGoBack = safeIndex < maxIndex;
            final canGoForward = safeIndex > 0;
            final isCurrentWeek = safeIndex == 0;
            
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // Navigation bar with arrows and date range
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: canGoBack ? () => _goToPrevious(maxIndex) : null,
                      tooltip: 'Previous week',
                    ),
                    Column(
                      children: [
                        Text(
                          _formatDateRange(report.weekStart, report.weekEnd),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (isCurrentWeek)
                          Text(
                            'This week',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: canGoForward ? _goToNext : null,
                      tooltip: 'Next week',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                BudgetRingCard(report: report),
                const SizedBox(height: 16),
                BudgetComparisonCard(
                  key: ValueKey(report.weekStart),
                  forWeekStart: report.weekStart,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
