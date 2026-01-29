import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bfm_app/models/weekly_report.dart';
import 'package:bfm_app/services/budget_comparison_service.dart';
import 'package:bfm_app/utils/category_emoji_helper.dart';
import 'package:bfm_app/widgets/help_icon_tooltip.dart';

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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      outcome.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
    
    // Calculate spent from segments (exclude Leftover)
    final spentFromSegments = segments
        .where((s) => s.label != 'Leftover' && s.label != 'No spend yet')
        .fold<double>(0, (sum, s) => sum + s.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
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
                            "Spent: \$${spentFromSegments.toStringAsFixed(0)}",
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
                const Positioned(
                  top: 0,
                  right: 0,
                  child: HelpIconTooltip(
                    title: 'Spending Breakdown',
                    message: 'This chart shows where your money went this week:\n\n'
                        '• Each colored segment represents a spending category\n'
                        '• The size of each segment shows how much you spent there\n'
                        '• Categories you\'ve budgeted for appear in the "budgeted for" section\n'
                        '• Unbudgeted spending appears separately\n\n'
                        'The grey "Leftover" shows money you didn\'t spend.\n\n'
                        'Tip: Try to keep most spending in budgeted categories!',
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLegend(segments),
            if (statsSection != null) ...[
              const SizedBox(height: 16),
              statsSection,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade400)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade400)),
      ],
    );
  }

  Widget _buildLegend(List<_RingSegment> segments) {
    // Separate budgeted from non-budgeted (exclude "Leftover" and "No spend yet")
    final budgeted = segments
        .where((s) => s.isBudgeted && s.label != 'Leftover' && s.label != 'No spend yet')
        .toList();
    final notBudgeted = segments
        .where((s) => !s.isBudgeted && s.label != 'Leftover')
        .toList();
    final leftover = segments.where((s) => s.label == 'Leftover').toList();

    Widget buildSegmentRow(_RingSegment seg) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Row(
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
            Flexible(
              child: Text(
                seg.label,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              " \$${seg.value.toStringAsFixed(0)}",
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Budgeted for header and categories
        if (budgeted.isNotEmpty) ...[
          _buildSectionHeader('budgeted for'),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: budgeted.map(buildSegmentRow).toList(),
          ),
        ],
        // Separator and non-budgeted categories
        if (notBudgeted.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSectionHeader('not budgeted for'),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: notBudgeted.map(buildSegmentRow).toList(),
          ),
        ],
        // Leftover (if any)
        if (leftover.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: leftover.map(buildSegmentRow).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildStats(WeeklyInsightsReport report) {
    final budgetTotal = report.totalBudget;
    final totalSpent = report.totalSpent;
    // Only sum spend from categories that have a budget (budget > 0)
    final budgetSpend = report.categories
        .where((entry) => entry.budget > 0)
        .fold<double>(0, (sum, entry) => sum + entry.spent);

    // Use leftToSpend from overviewSummary to match dashboard calculation
    // Falls back to simple income - spent if no summary available
    final leftToSpend = report.overviewSummary?.leftToSpend ??
        (report.totalIncome - totalSpent);
    final leftoverPositive = leftToSpend >= 0;

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
          label: "Spent on budgets",
          value: "\$${budgetSpend.toStringAsFixed(2)}",
          valueColor: budgetSpend > budgetTotal ? Colors.deepOrangeAccent : null,
        ),
        _StatRow(
          label: "Total spent",
          value: "\$${totalSpent.toStringAsFixed(2)}",
          valueColor: Colors.deepOrangeAccent,
        ),
        const SizedBox(height: 8),
        _StatRow(
          label: "Left to spend",
          value: "\$${leftToSpend.abs().toStringAsFixed(2)}",
          valueColor: leftoverPositive ? Colors.green : Colors.redAccent,
          prefix: leftoverPositive ? null : "over",
        ),
      ],
    );
  }

  /// Gets special color for goal/recovery contributions
  Color? _getSpecialColor(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('goal contribution') || lower.contains('savings')) {
      return Colors.green.shade500; // Green for savings/goals
    }
    if (lower.contains('recovery payment') || lower.contains('recovery')) {
      return Colors.orange.shade500; // Orange for recovery
    }
    return null;
  }
  
  /// Check if label is a special contribution type
  bool _isContribution(String label) {
    final lower = label.toLowerCase();
    return lower.contains('goal contribution') || 
           lower.contains('recovery payment') ||
           lower.contains('savings') ||
           lower.contains('recovery');
  }

  List<_RingSegment> _buildSegments(WeeklyInsightsReport report) {
    final segments = <_RingSegment>[];
    double budgetSpent = 0;
    var colorIndex = 0;
    final usedLabels = <String>{};

    // Build a set of labels that have budgets (case-insensitive)
    final budgetedLabels = <String>{};
    for (final cat in report.categories) {
      if (cat.budget > 0) {
        budgetedLabels.add(cat.label.toLowerCase());
      }
    }

    // Combine categories with the same label
    final combinedCategories = <String, ({double spent, double budget})>{};
    for (final cat in report.categories) {
      final label = cat.label;
      final existing = combinedCategories[label];
      if (existing != null) {
        combinedCategories[label] = (
          spent: existing.spent + cat.spent,
          budget: existing.budget + cat.budget,
        );
      } else {
        combinedCategories[label] = (spent: cat.spent, budget: cat.budget);
      }
    }

    for (final entry in combinedCategories.entries) {
      final label = entry.key;
      final value = entry.value.spent.abs();
      if (value <= 0) continue;
      usedLabels.add(label.toLowerCase());
      final hasBudget = entry.value.budget > 0;
      final specialColor = _getSpecialColor(label);
      segments.add(
        _RingSegment(
          value: value,
          label: label,
          color: specialColor ?? _ringPalette[colorIndex % _ringPalette.length],
          isBudgeted: hasBudget || _isContribution(label), // Show contributions in budgeted section
        ),
      );
      budgetSpent += value;
      if (specialColor == null) colorIndex++;
    }

    // Instead of showing "Other spend" as one item, break it down using topCategories
    final otherSpend = math.max(report.totalSpent - budgetSpent, 0.0);
    if (otherSpend > 0) {
      // Combine topCategories by label first
      final combinedTop = <String, double>{};
      for (final top in report.topCategories) {
        if (top.spent <= 0) continue;
        if (usedLabels.contains(top.label.toLowerCase())) continue;
        combinedTop[top.label] = (combinedTop[top.label] ?? 0) + top.spent.abs();
      }
      
      double otherAccountedFor = 0;
      for (final entry in combinedTop.entries) {
        final label = entry.key;
        final value = entry.value;
        usedLabels.add(label.toLowerCase());
        // Check if this label matches a budget (case-insensitive)
        final hasBudget = budgetedLabels.contains(label.toLowerCase());
        final specialColor = _getSpecialColor(label);
        final isContrib = _isContribution(label);
        segments.add(
          _RingSegment(
            value: value,
            label: label,
            color: specialColor ?? (hasBudget 
                ? _ringPalette[colorIndex % _ringPalette.length]
                : Colors.blueGrey.shade400),
            isBudgeted: hasBudget || isContrib,
          ),
        );
        if (hasBudget && specialColor == null) colorIndex++;
        otherAccountedFor += value;
      }
      
      // If there's still unaccounted spend, show it as "Other"
      final remaining = otherSpend - otherAccountedFor;
      if (remaining > 0.01) {
        segments.add(
          _RingSegment(
            value: remaining,
            label: 'Other',
            color: Colors.blueGrey.shade300,
            isBudgeted: false,
          ),
        );
      }
    }

    final leftover = math.max(report.totalIncome - report.totalSpent, 0.0);
    if (leftover > 0) {
      segments.add(
        _RingSegment(
          value: leftover,
          label: 'Leftover',
          color: Colors.grey.shade300,
          isBudgeted: true, // Not shown in legend anyway
        ),
      );
    }

    if (segments.isEmpty) {
      segments.add(
        _RingSegment(
          value: report.totalIncome > 0 ? report.totalIncome : 1,
          label: 'No spend yet',
          color: Colors.grey.shade300,
          isBudgeted: true,
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
  final bool isBudgeted;

  const _RingSegment({
    required this.value,
    required this.label,
    required this.color,
    this.isBudgeted = true,
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

/// Expandable card comparing budget spend vs weekly average.
/// 
/// If [forWeekStart] is provided, shows comparisons for that specific week.
/// Otherwise shows current week (week-to-date).
class BudgetComparisonCard extends StatefulWidget {
  final DateTime? forWeekStart;
  
  const BudgetComparisonCard({super.key, this.forWeekStart});

  @override
  State<BudgetComparisonCard> createState() => _BudgetComparisonCardState();
}

class _BudgetComparisonCardState extends State<BudgetComparisonCard> {
  bool _isExpanded = false;
  CategoryEmojiHelper? _emojiHelper;
  Future<List<BudgetSpendComparison>>? _comparisonsFuture;

  @override
  void initState() {
    super.initState();
    CategoryEmojiHelper.ensureLoaded().then((h) {
      if (mounted) setState(() => _emojiHelper = h);
    });
    _loadComparisons();
  }

  @override
  void didUpdateWidget(BudgetComparisonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if the week changed
    if (oldWidget.forWeekStart != widget.forWeekStart) {
      _loadComparisons();
    }
  }

  void _loadComparisons() {
    _comparisonsFuture = BudgetComparisonService.getComparisons(forWeekStart: widget.forWeekStart);
  }

  String _formatWeekLabel() {
    if (widget.forWeekStart != null) {
      final start = widget.forWeekStart!;
      final end = start.add(const Duration(days: 6));
      return "${start.day}/${start.month} - ${end.day}/${end.month}";
    }
    return "This week";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
            InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Monthly Average vs Budget",
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            const SizedBox(width: 4),
                            const HelpIconTooltip(
                              title: 'Monthly Average vs Budget',
                              message: 'This compares your average monthly spending to your budget limits:\n\n'
                                  '✅ On track: Your average spending is within your budget\n'
                                  '✅ Under budget: You typically spend less than budgeted\n'
                                  '⚠️ Over budget: Your average spending exceeds your budget\n\n'
                                  'If you\'re consistently over budget in a category, '
                                  'consider either increasing the budget or finding ways to spend less.\n\n'
                                  'Tap to expand and see details for each category.',
                              size: 14,
                            ),
                          ],
                        ),
                        Text(
                          _formatWeekLabel(),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FutureBuilder<List<BudgetSpendComparison>>(
                future: _comparisonsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final comparisons = snapshot.data!;
                  if (comparisons.isEmpty) {
                    return const Text("No budget data available yet.");
                  }
                  return Column(
                    children: [
                      for (final c in comparisons)
                        _ComparisonRow(comparison: c, emojiHelper: _emojiHelper),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final BudgetSpendComparison comparison;
  final CategoryEmojiHelper? emojiHelper;
  
  const _ComparisonRow({required this.comparison, this.emojiHelper});

  @override
  Widget build(BuildContext context) {
    final c = comparison;
    
    // Compare average spending to budget to show if user is consistently over/under
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (c.isAvgOverBudget) {
      // Average is significantly higher than budget - consistently overspending
      statusColor = Colors.orange;
      statusIcon = Icons.trending_up;
      statusText = "Over budget";
    } else if (c.weeklyAvgSpend > c.budgetLimit) {
      // Over budget but within tolerance - normal variance
      statusColor = Colors.green;
      statusIcon = Icons.check;
      statusText = "Normal variance";
    } else if (c.isAvgUnderBudget) {
      // Average is significantly lower than budget - room to spare
      statusColor = Colors.green;
      statusIcon = Icons.trending_down;
      statusText = "Under budget";
    } else {
      // Average is at or under budget within tolerance - on track
      statusColor = Colors.teal;
      statusIcon = Icons.check;
      statusText = "On track";
    }
    
    final emoji = emojiHelper?.emojiForName(c.label) ?? CategoryEmojiHelper.defaultEmoji;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "Avg: \$${c.weeklyAvgSpend.toStringAsFixed(0)}  •  Budget: \$${c.budgetLimit.toStringAsFixed(0)}",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
