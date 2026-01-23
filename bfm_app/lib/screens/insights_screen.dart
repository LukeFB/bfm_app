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

import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/models/weekly_report.dart';
import 'package:bfm_app/services/insights_service.dart';
import 'package:bfm_app/widgets/weekly_report_widgets.dart';

/// Screen for viewing weekly insights snapshots.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

/// Internal container bundling the latest report plus saved history.
class _InsightsPayload {
  final WeeklyInsightsReport report;
  final List<WeeklyReportEntry> history;
  const _InsightsPayload({required this.report, required this.history});
}

/// Handles fetching reports, pull-to-refresh, and history modals.
class _InsightsScreenState extends State<InsightsScreen> {
  late Future<_InsightsPayload> _future;

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
    return _InsightsPayload(report: report, history: history);
  }

  /// Rebuilds the Future and waits for it so pull-to-refresh can complete.
  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  /// Opens a bottom sheet that shows the JSON-backed report for a given week.
  Future<void> _openHistoryDetail(WeeklyReportEntry entry) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _WeeklyReportDetailSheet(entry: entry),
    );
  }

  /// Renders the insights cards and history list.
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
            final report = payload.report;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                BudgetRingCard(report: report),
                if (payload.history.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _HistoryList(
                    history: payload.history,
                    onOpen: _openHistoryDetail,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}


/// Renders a single category row inside the history detail sheet.
class _CategoryRow extends StatelessWidget {
  final CategoryWeeklySummary summary;
  const _CategoryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final hasBudget = summary.budget > 0;
    final pct = hasBudget && summary.budget > 0
        ? (summary.spent / summary.budget).clamp(0.0, 1.5)
        : 1.0;
    final over = hasBudget && summary.spent > summary.budget + 0.01;
    final label = hasBudget
        ? "\$${summary.spent.toStringAsFixed(2)} / \$${summary.budget.toStringAsFixed(2)}"
        : "\$${summary.spent.toStringAsFixed(2)} spent";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  summary.label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: over ? Colors.deepOrange : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct > 1 ? 1 : pct,
            backgroundColor: Colors.grey.shade200,
            color: over ? Colors.deepOrange : Colors.blueAccent,
          ),
        ],
      ),
    );
  }
}

/// List card showing previously saved weekly reports.
class _HistoryList extends StatelessWidget {
  final List<WeeklyReportEntry> history;
  final Future<void> Function(WeeklyReportEntry) onOpen;
  const _HistoryList({required this.history, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Weekly report history",
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            for (final entry in history)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  entry.report.weekLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  "Spent \$${entry.report.totalSpent.toStringAsFixed(2)} • Budget \$${entry.report.totalBudget.toStringAsFixed(2)}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => onOpen(entry),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet that drills into a historical weekly report.
class _WeeklyReportDetailSheet extends StatelessWidget {
  final WeeklyReportEntry entry;
  const _WeeklyReportDetailSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    final report = entry.report;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text("Week of ${report.weekLabel}",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  const Text("Budgets vs spend",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  for (final summary in report.categories)
                    _CategoryRow(summary: summary),
                  const SizedBox(height: 16),
                  const Text("Transactions",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  FutureBuilder<List<TransactionModel>>(
                    future:
                        InsightsService.getTransactionsForWeek(report.weekStart),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final txs = snapshot.data!;
                      if (txs.isEmpty) {
                        return const Text("No transactions recorded.");
                      }
                      return Column(
                        children: txs.map((t) {
                          final amount = t.type == 'expense'
                              ? -t.amount.abs()
                              : t.amount.abs();
                          final color = amount < 0
                              ? Colors.deepOrange
                              : Colors.green;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              t.description.isEmpty
                                  ? 'Transaction'
                                  : t.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(t.date),
                            trailing: Text(
                              "\$${amount.toStringAsFixed(2)}",
                              style: TextStyle(color: color),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
