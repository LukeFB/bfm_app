import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bfm_app/models/weekly_report.dart';

/// Card summarising goal outcomes and linking to the goals screen.
class GoalReportCard extends StatelessWidget {
  final WeeklyInsightsReport report;
  final Future<void> Function() onOpenGoals;

  const GoalReportCard({
    super.key,
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

/// Visualises income vs budget/spend using a custom donut chart.
class BudgetRingCard extends StatelessWidget {
  final WeeklyInsightsReport report;
  final bool showStats;
  const BudgetRingCard({
    super.key,
    required this.report,
    this.showStats = true,
  });

  @override
  Widget build(BuildContext context) {
    final segments = _buildSegments(report);
    final statsSection = showStats ? _buildStats(report) : null;

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
                      const SizedBox(height: 4),
                      Text(
                        "Spent: \$${report.totalSpent.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
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
                          "${seg.label} (\$${seg.value.toStringAsFixed(0)})",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
            if (statsSection != null) ...[
              const SizedBox(height: 16),
              statsSection,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStats(WeeklyInsightsReport report) {
    final budgetTotal = report.totalBudget;
    final totalSpent = report.totalSpent;
    final budgetSpend =
        report.categories.fold<double>(0, (sum, entry) => sum + entry.spent);
    final remainingBudget = budgetTotal - budgetSpend;
    final leftoverCash = report.totalIncome - totalSpent;
    final leftoverPositive = leftoverCash >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("This week",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 6),
        _StatRow(
          label: "Budgeted",
          value: "\$${budgetTotal.toStringAsFixed(2)}",
        ),
        _StatRow(
          label: "Spent",
          value: "\$${totalSpent.toStringAsFixed(2)}",
          valueColor: Colors.deepOrangeAccent,
        ),
        _StatRow(
          label: "Remaining budget",
          value: "\$${remainingBudget.toStringAsFixed(2)}",
          valueColor: remainingBudget >= 0 ? Colors.teal : Colors.redAccent,
        ),
        const SizedBox(height: 8),
        _StatRow(
          label: "Money left over",
          value: "\$${leftoverCash.abs().toStringAsFixed(2)}",
          valueColor: leftoverPositive ? Colors.green : Colors.redAccent,
          prefix: leftoverPositive ? "saved" : "over",
        ),
      ],
    );
  }

  List<_RingSegment> _buildSegments(WeeklyInsightsReport report) {
    final segments = <_RingSegment>[];
    double budgetSpent = 0;
    var colorIndex = 0;
    final labelCounts = <String, int>{};

    for (final cat in report.categories) {
      final value = cat.spent.abs();
      if (value <= 0) continue;
      var label = cat.label;
      final nextCount = (labelCounts[label] ?? 0) + 1;
      labelCounts[label] = nextCount;
      if (nextCount > 1) {
        label = "$label (${nextCount})";
      }
      segments.add(
        _RingSegment(
          value: value,
          label: label,
          color: _ringPalette[colorIndex % _ringPalette.length],
        ),
      );
      budgetSpent += value;
      colorIndex++;
    }

    final otherSpend = math.max(report.totalSpent - budgetSpent, 0.0);
    if (otherSpend > 0) {
      segments.add(
        _RingSegment(
          value: otherSpend,
          label: 'Other spend',
          color: Colors.blueGrey.shade400,
        ),
      );
    }

    final leftover = math.max(report.totalIncome - report.totalSpent, 0.0);
    if (leftover > 0) {
      segments.add(
        _RingSegment(
          value: leftover,
          label: 'Leftover',
          color: Colors.grey.shade300,
        ),
      );
    }

    if (segments.isEmpty) {
      segments.add(
        _RingSegment(
          value: report.totalIncome > 0 ? report.totalIncome : 1,
          label: 'No spend yet',
          color: Colors.grey.shade300,
        ),
      );
    }

    return segments;
  }
}

/// Shows the top spending categories as progress bars.
class TopCategoryChart extends StatelessWidget {
  final WeeklyInsightsReport report;
  const TopCategoryChart({super.key, required this.report});

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
            const Text("Top spending this week",
                style: TextStyle(fontWeight: FontWeight.w600)),
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
