import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/models/weekly_report.dart';
import 'package:bfm_app/services/insights_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsPayload {
  final WeeklyInsightsReport report;
  final List<WeeklyReportEntry> history;
  const _InsightsPayload({required this.report, required this.history});
}

class _InsightsScreenState extends State<InsightsScreen> {
  late Future<_InsightsPayload> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_InsightsPayload> _load() async {
    final report = await InsightsService.generateWeeklyReport();
    final history = await InsightsService.getSavedReports();
    return _InsightsPayload(report: report, history: history);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _openHistoryDetail(WeeklyReportEntry entry) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _WeeklyReportDetailSheet(entry: entry),
    );
  }

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
                _BudgetRingCard(report: report),
                const SizedBox(height: 16),
                _TopCategoryChart(report: report),
                const SizedBox(height: 16),
                _GoalReportCard(report: report, onOpenGoals: () async {
                  await Navigator.pushNamed(context, '/goals');
                  if (!mounted) return;
                  await _refresh();
                }),
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

class _GoalReportCard extends StatelessWidget {
  final WeeklyInsightsReport report;
  final Future<void> Function() onOpenGoals;

  const _GoalReportCard({
    required this.report,
    required this.onOpenGoals,
  });

  @override
  Widget build(BuildContext context) {
    final outcomes = report.goalOutcomes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Savings goals",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await onOpenGoals();
                  },
                  child: const Text('Open goals'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (outcomes.isEmpty)
              const Text(
                  "No goals yet. Create one to automatically add savings when weeks go well."),
            for (final outcome in outcomes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outcome.goal.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(outcome.message),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BudgetRingCard extends StatelessWidget {
  final WeeklyInsightsReport report;
  const _BudgetRingCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final budget = report.totalBudget;
    final spent = report.totalSpent;
    final savedPortion =
        budget <= 0 ? 0.0 : (budget - spent).clamp(0.0, budget);
    final leftoverCash = report.savingsDelta;
    final leftoverPositive = leftoverCash >= 0;
    final segments = _buildSegments(report);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(200),
                    painter: _BudgetRingPainter(
                      segments: segments,
                      strokeWidth: 18,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Income",
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      Text(
                        "\$${report.totalIncome.toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: segments
                  .map(
                    (seg) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: seg.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          seg.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("This week",
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 6),
                _StatRow(
                  label: "Budgeted",
                  value: "\$${budget.toStringAsFixed(2)}",
                ),
                _StatRow(
                  label: "Spent",
                  value: "\$${spent.toStringAsFixed(2)}",
                  valueColor: Colors.deepOrangeAccent,
                ),
                _StatRow(
                  label: "Remaining budget",
                  value: "\$${savedPortion.toStringAsFixed(2)}",
                  valueColor: Colors.teal,
                ),
                const SizedBox(height: 8),
                _StatRow(
                  label: "Money left over",
                  value: "\$${leftoverCash.abs().toStringAsFixed(2)}",
                  valueColor: leftoverPositive ? Colors.green : Colors.redAccent,
                  prefix: leftoverPositive ? "saved" : "over",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<_RingSegment> _buildSegments(WeeklyInsightsReport report) {
    final palette = _ringPalette;
    final categories =
        report.categories.where((c) => c.budget > 0).toList(growable: false);
    if (categories.isEmpty) {
      return [
        _RingSegment(
          value: report.totalBudget <= 0 ? 1 : report.totalBudget,
          label: "Budget",
          color: Colors.deepOrangeAccent,
        ),
      ];
    }
    final segments = <_RingSegment>[];
    for (var i = 0; i < categories.length; i++) {
      final cat = categories[i];
      segments.add(
        _RingSegment(
          value: cat.budget,
          label: cat.label,
          color: palette[i % palette.length],
        ),
      );
    }
    return segments;
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final String? prefix;

  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(
            prefix == null ? value : "$value ($prefix)",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

const List<Color> _ringPalette = [
  Colors.deepOrangeAccent,
  Colors.blueAccent,
  Colors.green,
  Colors.purple,
  Colors.teal,
  Colors.pinkAccent,
  Colors.brown,
  Colors.amber,
];

class _RingSegment {
  final double value;
  final String label;
  final Color color;

  const _RingSegment({
    required this.value,
    required this.label,
    required this.color,
  });
}

class _BudgetRingPainter extends CustomPainter {
  final List<_RingSegment> segments;
  final double strokeWidth;

  const _BudgetRingPainter({
    required this.segments,
    this.strokeWidth = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total =
        segments.fold<double>(0, (sum, seg) => sum + seg.value.abs());
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: math.min(size.width, size.height) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    if (total <= 0) {
      paint.color = Colors.grey.shade300;
      canvas.drawArc(rect, 0, math.pi * 2, false, paint);
      return;
    }

    double startAngle = -math.pi / 2;
    for (final segment in segments) {
      final sweep = (segment.value.abs() / total) * math.pi * 2;
      if (sweep <= 0) continue;
      paint.color = segment.color;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _BudgetRingPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _TopCategoryChart extends StatelessWidget {
  final WeeklyInsightsReport report;
  const _TopCategoryChart({required this.report});

  @override
  Widget build(BuildContext context) {
    final top = report.topCategories;
    final display = top.take(4).toList();
    final maxSpend =
        display.isEmpty ? 0.0 : display.map((c) => c.spent).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Top spending", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (display.isEmpty)
              const Text("No category data yet.")
            else
              ...display.map((c) {
                final percent =
                    maxSpend <= 0 ? 0.0 : (c.spent / maxSpend).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text("\$${c.spent.toStringAsFixed(2)} spent"),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

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
                ),
              ),
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
                title: Text(entry.report.weekLabel),
                subtitle: Text(
                  "Spent \$${entry.report.totalSpent.toStringAsFixed(2)} • Budget \$${entry.report.totalBudget.toStringAsFixed(2)}",
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
