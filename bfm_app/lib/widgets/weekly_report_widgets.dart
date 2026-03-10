import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bfm_app/models/weekly_report.dart';
import 'package:bfm_app/services/budget_comparison_service.dart';
import 'package:bfm_app/theme/buxly_theme.dart';
import 'package:bfm_app/utils/category_emoji_helper.dart';
import 'package:bfm_app/widgets/help_icon_tooltip.dart';
import 'package:bfm_app/widgets/semi_circle_chart.dart';

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
                          Text(
                            "Income",
                            style: TextStyle(
                              fontFamily: BuxlyTheme.fontFamily,
                              fontSize: 12,
                              color: BuxlyColors.midGrey,
                            ),
                          ),
                          Text(
                            "\$${report.totalIncome.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontFamily: BuxlyTheme.fontFamily,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: BuxlyColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Spent: \$${spentFromSegments.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontFamily: BuxlyTheme.fontFamily,
                              fontSize: 12,
                              color: BuxlyColors.midGrey,
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
        const Expanded(child: Divider(color: BuxlyColors.disabled)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: BuxlyTheme.fontFamily,
              fontSize: 11,
              color: BuxlyColors.midGrey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const Expanded(child: Divider(color: BuxlyColors.disabled)),
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
                style: const TextStyle(
                  fontFamily: BuxlyTheme.fontFamily,
                  fontSize: 12,
                  color: BuxlyColors.darkText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              " \$${seg.value.toStringAsFixed(0)}",
              style: const TextStyle(
                fontFamily: BuxlyTheme.fontFamily,
                fontSize: 12,
                color: BuxlyColors.darkText,
              ),
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
            style: TextStyle(
              fontFamily: BuxlyTheme.fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: BuxlyColors.darkText,
            )),
        const SizedBox(height: 6),
        _StatRow(
          label: "Budgeted",
          value: "\$${budgetTotal.toStringAsFixed(2)}",
        ),
        _StatRow(
          label: "Spent on budgets",
          value: "\$${budgetSpend.toStringAsFixed(2)}",
          valueColor: budgetSpend > budgetTotal ? BuxlyColors.coralOrange : null,
        ),
        _StatRow(
          label: "Total spent",
          value: "\$${totalSpent.toStringAsFixed(2)}",
          valueColor: BuxlyColors.coralOrange,
        ),
        const SizedBox(height: 8),
        _StatRow(
          label: "Left to spend",
          value: "\$${leftToSpend.abs().toStringAsFixed(2)}",
          valueColor: leftoverPositive ? BuxlyColors.limeGreen : BuxlyColors.hotPink,
          prefix: leftoverPositive ? null : "over",
        ),
      ],
    );
  }

  /// Gets special color for goal/recovery contributions
  Color? _getSpecialColor(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('goal contribution') || lower.contains('savings')) {
      return BuxlyColors.limeGreen;
    }
    if (lower.contains('recovery payment') || lower.contains('recovery')) {
      return BuxlyColors.coralOrange;
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
                : BuxlyColors.midGrey),
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
            color: BuxlyColors.disabled,
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
          color: BuxlyColors.disabled,
          isBudgeted: true, // Not shown in legend anyway
        ),
      );
    }

    if (segments.isEmpty) {
      segments.add(
        _RingSegment(
          value: report.totalIncome > 0 ? report.totalIncome : 1,
          label: 'No spend yet',
          color: BuxlyColors.disabled,
          isBudgeted: true,
        ),
      );
    }

    return segments;
  }
}

/// Combined chart card with tabs to switch between Budget Overview and Spending Breakdown.
class CombinedChartCard extends StatefulWidget {
  /// Report data - used for both views to ensure consistent data
  final WeeklyInsightsReport report;
  /// Whether to show stats in the spending breakdown view
  final bool showStats;

  const CombinedChartCard({
    super.key,
    required this.report,
    this.showStats = true,
  });

  @override
  State<CombinedChartCard> createState() => _CombinedChartCardState();
}

class _CombinedChartCardState extends State<CombinedChartCard> {
  int _selectedIndex = 0; // 0 = Budget Overview, 1 = Spending Breakdown

  /// Derives budget overview data from the report for consistency
  ({double income, double totalBudgeted, double spentOnBudgets, double leftToSpend, double discretionarySpent}) get _budgetData {
    final report = widget.report;
    
    // Income and total budgeted come directly from report
    final income = report.totalIncome;
    final totalBudgeted = report.totalBudget;
    
    // Calculate spent on budgets: sum of spent for categories with budget > 0
    double spentOnBudgets = 0;
    for (final cat in report.categories) {
      if (cat.budget > 0) {
        spentOnBudgets += cat.spent;
      }
    }
    
    // Discretionary spent: total spent minus budget spent
    final discretionarySpent = math.max(report.totalSpent - spentOnBudgets, 0.0);
    
    // Left to spend (discretionary budget): income minus total budgeted
    // Use the report's overviewSummary if available for consistency
    final leftToSpend = report.overviewSummary?.leftToSpend != null
        ? income - totalBudgeted  // discretionary budget
        : income - totalBudgeted;
    
    return (
      income: income,
      totalBudgeted: totalBudgeted,
      spentOnBudgets: spentOnBudgets,
      leftToSpend: leftToSpend,
      discretionarySpent: discretionarySpent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // Tab selector at top
          Padding(
            padding: const EdgeInsets.fromLTRB(BuxlySpacing.lg, BuxlySpacing.md, BuxlySpacing.lg, 0),
            child: Container(
              decoration: BoxDecoration(
                color: BuxlyColors.offWhite,
                borderRadius: BorderRadius.circular(BuxlyRadius.sm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTab(
                      index: 0,
                      label: 'Budget',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildTab(
                      index: 1,
                      label: 'Spending',
                      icon: Icons.pie_chart_outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Chart content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selectedIndex == 0
                ? _buildBudgetOverview()
                : _buildSpendingBreakdown(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? BuxlyColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(BuxlyRadius.sm),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: BuxlyColors.darkText.withOpacity(0.08),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        margin: const EdgeInsets.all(4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? BuxlyColors.teal : BuxlyColors.midGrey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: BuxlyTheme.fontFamily,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? BuxlyColors.teal : BuxlyColors.midGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetOverview() {
    final data = _budgetData;
    return Padding(
      key: const ValueKey('budget'),
      padding: const EdgeInsets.all(16),
      child: SemiCircleChart(
        income: data.income,
        totalBudgeted: data.totalBudgeted,
        spentOnBudgets: data.spentOnBudgets,
        leftToSpend: data.leftToSpend,
        discretionarySpent: data.discretionarySpent,
        hideAlerts: true,
      ),
    );
  }

  Widget _buildSpendingBreakdown() {
    // Reuse BudgetRingCard's internal structure but without the Card wrapper
    final segments = _buildSegments(widget.report);
    final statsSection = widget.showStats ? _buildStats(widget.report) : null;
    
    // Calculate spent from segments (exclude Leftover)
    final spentFromSegments = segments
        .where((s) => s.label != 'Leftover' && s.label != 'No spend yet')
        .fold<double>(0, (sum, s) => sum + s.value);

    return Padding(
      key: const ValueKey('spending'),
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Income",
                              style: TextStyle(
                                fontFamily: BuxlyTheme.fontFamily,
                                fontSize: 12,
                                color: BuxlyColors.midGrey,
                              ),
                            ),
                            const SizedBox(width: 2),
                            HelpIconTooltip(
                              title: 'Weekly Income',
                              message: 'Your expected income for this week.\n\n'
                                  'For regular income: Uses last week\'s actual income.\n'
                                  'For irregular income: Uses 4-week average.',
                              size: 12,
                            ),
                          ],
                        ),
                        Text(
                          "\$${widget.report.totalIncome.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontFamily: BuxlyTheme.fontFamily,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: BuxlyColors.darkText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Spent: \$${spentFromSegments.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontFamily: BuxlyTheme.fontFamily,
                                fontSize: 12,
                                color: BuxlyColors.midGrey,
                              ),
                            ),
                            const SizedBox(width: 2),
                            HelpIconTooltip(
                              title: 'Total Spent',
                              message: 'Total amount spent this week across all categories.\n\n'
                                  'This includes both budgeted and non-budgeted spending.',
                              size: 12,
                            ),
                          ],
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
    );
  }

  Widget _buildSectionHeader(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(color: BuxlyColors.disabled)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: BuxlyTheme.fontFamily,
              fontSize: 11,
              color: BuxlyColors.midGrey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const Expanded(child: Divider(color: BuxlyColors.disabled)),
      ],
    );
  }

  Widget _buildLegend(List<_RingSegment> segments) {
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
                style: const TextStyle(
                  fontFamily: BuxlyTheme.fontFamily,
                  fontSize: 12,
                  color: BuxlyColors.darkText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              " \$${seg.value.toStringAsFixed(0)}",
              style: const TextStyle(
                fontFamily: BuxlyTheme.fontFamily,
                fontSize: 12,
                color: BuxlyColors.darkText,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
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
    final budgetSpend = report.categories
        .where((entry) => entry.budget > 0)
        .fold<double>(0, (sum, entry) => sum + entry.spent);

    final leftToSpend = report.overviewSummary?.leftToSpend ??
        (report.totalIncome - totalSpent);
    final leftoverPositive = leftToSpend >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("This week",
            style: TextStyle(
              fontFamily: BuxlyTheme.fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: BuxlyColors.darkText,
            )),
        const SizedBox(height: 6),
        _StatRow(
          label: "Budgeted",
          value: "\$${budgetTotal.toStringAsFixed(2)}",
          helpTitle: "Total Budgeted",
          helpMessage: "Sum of all your weekly budget limits.\n\n"
              "This is the total amount you've allocated to budget categories like bills, groceries, etc.",
        ),
        _StatRow(
          label: "Spent on budgets",
          value: "\$${budgetSpend.toStringAsFixed(2)}",
          valueColor: budgetSpend > budgetTotal ? BuxlyColors.coralOrange : null,
          helpTitle: "Budget Spending",
          helpMessage: "Amount spent in categories that have a budget.\n\n"
              "Orange if you've exceeded your total budget allocation.",
        ),
        _StatRow(
          label: "Total spent",
          value: "\$${totalSpent.toStringAsFixed(2)}",
          valueColor: BuxlyColors.coralOrange,
          helpTitle: "Total Spent",
          helpMessage: "All spending this week.\n\n"
              "Includes both budgeted categories and non-budgeted spending.",
        ),
        const SizedBox(height: 8),
        _StatRow(
          label: "Left to spend",
          value: "\$${leftToSpend.abs().toStringAsFixed(2)}",
          valueColor: leftoverPositive ? BuxlyColors.limeGreen : BuxlyColors.hotPink,
          prefix: leftoverPositive ? null : "over",
          helpTitle: "Left to Spend",
          helpMessage: "How much you have left after all spending.\n\n"
              "Calculation: Income − Budgeted − Budget Overspend − Non-budget Spending\n\n"
              "Green = money remaining\n"
              "Red = overspent",
        ),
      ],
    );
  }

  Color? _getSpecialColor(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('goal contribution') || lower.contains('savings')) {
      return BuxlyColors.limeGreen;
    }
    if (lower.contains('recovery payment') || lower.contains('recovery')) {
      return BuxlyColors.coralOrange;
    }
    return null;
  }

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

    final budgetedLabels = <String>{};
    for (final cat in report.categories) {
      if (cat.budget > 0) {
        budgetedLabels.add(cat.label.toLowerCase());
      }
    }

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
          isBudgeted: hasBudget || _isContribution(label),
        ),
      );
      budgetSpent += value;
      if (specialColor == null) colorIndex++;
    }

    final otherSpend = math.max(report.totalSpent - budgetSpent, 0.0);
    if (otherSpend > 0) {
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
        final hasBudget = budgetedLabels.contains(label.toLowerCase());
        final specialColor = _getSpecialColor(label);
        final isContrib = _isContribution(label);
        segments.add(
          _RingSegment(
            value: value,
            label: label,
            color: specialColor ??
                (hasBudget
                    ? _ringPalette[colorIndex % _ringPalette.length]
                    : BuxlyColors.midGrey),
            isBudgeted: hasBudget || isContrib,
          ),
        );
        if (hasBudget && specialColor == null) colorIndex++;
        otherAccountedFor += value;
      }

      final remaining = otherSpend - otherAccountedFor;
      if (remaining > 0.01) {
        segments.add(
          _RingSegment(
            value: remaining,
            label: 'Other',
            color: BuxlyColors.disabled,
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
          color: BuxlyColors.disabled,
          isBudgeted: true,
        ),
      );
    }

    if (segments.isEmpty) {
      segments.add(
        _RingSegment(
          value: report.totalIncome > 0 ? report.totalIncome : 1,
          label: 'No spend yet',
          color: BuxlyColors.disabled,
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
        padding: const EdgeInsets.all(BuxlySpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Top spending this week",
                style: TextStyle(
                  fontFamily: BuxlyTheme.fontFamily,
                  fontWeight: FontWeight.w600,
                  color: BuxlyColors.darkText,
                )),
            const SizedBox(height: BuxlySpacing.md),
            if (display.isEmpty)
              Text("No category data yet.",
                  style: TextStyle(
                    fontFamily: BuxlyTheme.fontFamily,
                    color: BuxlyColors.midGrey,
                  ))
            else
              ...display.map((c) {
                final percent =
                    maxSpend <= 0 ? 0.0 : (c.spent / maxSpend).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.label,
                        style: const TextStyle(
                          fontFamily: BuxlyTheme.fontFamily,
                          color: BuxlyColors.darkText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      BuxlyProgressBar(value: percent, height: 10),
                      const SizedBox(height: 2),
                      Text("\$${c.spent.toStringAsFixed(2)} spent",
                        style: const TextStyle(
                          fontFamily: BuxlyTheme.fontFamily,
                          color: BuxlyColors.midGrey,
                        ),
                      ),
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
      paint.color = BuxlyColors.disabled;
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
  BuxlyColors.coralOrange,
  BuxlyColors.skyBlue,
  BuxlyColors.limeGreen,
  BuxlyColors.hotPink,
  BuxlyColors.teal,
  BuxlyColors.sunshineYellow,
  BuxlyColors.blushPink,
  Color(0xFF9B8FD7),
];

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final String? prefix;
  final String? helpTitle;
  final String? helpMessage;

  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.prefix,
    this.helpTitle,
    this.helpMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(
                fontFamily: BuxlyTheme.fontFamily,
                color: BuxlyColors.midGrey,
              )),
              if (helpMessage != null) ...[
                const SizedBox(width: 4),
                HelpIconTooltip(
                  title: helpTitle ?? label,
                  message: helpMessage!,
                  size: 12,
                ),
              ],
            ],
          ),
          Text(
            prefix == null ? value : "$value ($prefix)",
            style: TextStyle(
              fontFamily: BuxlyTheme.fontFamily,
              fontWeight: FontWeight.w600,
              color: valueColor ?? BuxlyColors.darkText,
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
              padding: const EdgeInsets.all(BuxlySpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Monthly Average vs Budget",
                              style: TextStyle(
                                fontFamily: BuxlyTheme.fontFamily,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: BuxlyColors.darkText,
                              ),
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
                          style: const TextStyle(
                            fontFamily: BuxlyTheme.fontFamily,
                            fontSize: 12,
                            color: BuxlyColors.midGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: BuxlyColors.midGrey,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(BuxlySpacing.lg, 0, BuxlySpacing.lg, BuxlySpacing.lg),
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
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (c.isAvgOverBudget) {
      statusColor = BuxlyColors.coralOrange;
      statusIcon = Icons.trending_up;
      statusText = "Over budget";
    } else if (c.weeklyAvgSpend > c.budgetLimit) {
      statusColor = BuxlyColors.limeGreen;
      statusIcon = Icons.check;
      statusText = "Normal variance";
    } else if (c.isAvgUnderBudget) {
      statusColor = BuxlyColors.limeGreen;
      statusIcon = Icons.trending_down;
      statusText = "Under budget";
    } else {
      statusColor = BuxlyColors.teal;
      statusIcon = Icons.check;
      statusText = "On track";
    }
    
    final emoji = emojiHelper?.emojiForName(c.emojiHint ?? c.label) ?? CategoryEmojiHelper.defaultEmoji;
    
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
                  style: const TextStyle(
                    fontFamily: BuxlyTheme.fontFamily,
                    fontWeight: FontWeight.w500,
                    color: BuxlyColors.darkText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "Avg: \$${c.weeklyAvgSpend.toStringAsFixed(0)}  •  Budget: \$${c.budgetLimit.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontFamily: BuxlyTheme.fontFamily,
                    fontSize: 11,
                    color: BuxlyColors.midGrey,
                  ),
                ),
              ],
            ),
          ),
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontFamily: BuxlyTheme.fontFamily,
              fontSize: 11,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Expandable card showing weekly transactions grouped by budget,
/// with spending progress bars and monthly average comparison.
/// Replaces BudgetComparisonCard with richer transaction-level detail.
class WeeklyBudgetBreakdownCard extends StatefulWidget {
  final DateTime? forWeekStart;
  const WeeklyBudgetBreakdownCard({super.key, this.forWeekStart});

  @override
  State<WeeklyBudgetBreakdownCard> createState() =>
      _WeeklyBudgetBreakdownCardState();
}

class _WeeklyBudgetBreakdownCardState extends State<WeeklyBudgetBreakdownCard> {
  bool _isExpanded = true;
  final Set<int> _expandedGroups = {};
  CategoryEmojiHelper? _emojiHelper;
  Future<List<BudgetWeeklyBreakdown>>? _breakdownFuture;

  @override
  void initState() {
    super.initState();
    CategoryEmojiHelper.ensureLoaded().then((h) {
      if (mounted) setState(() => _emojiHelper = h);
    });
    _loadBreakdown();
  }

  @override
  void didUpdateWidget(WeeklyBudgetBreakdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forWeekStart != widget.forWeekStart) {
      _expandedGroups.clear();
      _loadBreakdown();
    }
  }

  void _loadBreakdown() {
    _breakdownFuture = BudgetComparisonService.getWeeklyBreakdown(
      forWeekStart: widget.forWeekStart,
    );
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
              padding: const EdgeInsets.all(BuxlySpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Spending Category",
                              style: TextStyle(
                                fontFamily: BuxlyTheme.fontFamily,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: BuxlyColors.darkText,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const HelpIconTooltip(
                              title: 'Spending Category',
                              message:
                                  'All transactions for the week grouped by budget.\n\n'
                                  '• Each budget shows a spending bar and your 4-week average\n'
                                  '• Tap a budget to see individual transactions\n'
                                  '• Non-budgeted spending appears at the bottom',
                              size: 14,
                            ),
                          ],
                        ),
                        Text(
                          _formatWeekLabel(),
                          style: const TextStyle(
                            fontFamily: BuxlyTheme.fontFamily,
                            fontSize: 12,
                            color: BuxlyColors.midGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: BuxlyColors.midGrey,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(BuxlySpacing.lg, 0, BuxlySpacing.lg, BuxlySpacing.lg),
              child: FutureBuilder<List<BudgetWeeklyBreakdown>>(
                future: _breakdownFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final breakdowns = snapshot.data!;
                  if (breakdowns.isEmpty) {
                    return const Text("No transactions this week.");
                  }
                  final budgeted =
                      breakdowns.where((b) => b.isBudgeted).toList();
                  final other =
                      breakdowns.where((b) => !b.isBudgeted).toList();
                  return Column(
                    children: [
                      if (budgeted.isNotEmpty) ...[
                        _sectionDivider('budgeted'),
                        const SizedBox(height: 8),
                        for (var i = 0; i < budgeted.length; i++)
                          _buildGroupRow(budgeted[i], i),
                      ],
                      if (other.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _sectionDivider('other spending'),
                        const SizedBox(height: 8),
                        for (var i = 0; i < other.length; i++)
                          _buildGroupRow(other[i], budgeted.length + i),
                      ],
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionDivider(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(color: BuxlyColors.disabled)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: BuxlyTheme.fontFamily,
              fontSize: 11,
              color: BuxlyColors.midGrey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const Expanded(child: Divider(color: BuxlyColors.disabled)),
      ],
    );
  }

  Widget _buildGroupRow(BudgetWeeklyBreakdown b, int index) {
    final isGroupExpanded = _expandedGroups.contains(index);
    final emoji = _emojiHelper?.emojiForName(b.emojiHint ?? b.label) ??
        CategoryEmojiHelper.defaultEmoji;

    final barPercent = b.budgetLimit > 0
        ? (b.thisWeekSpend / b.budgetLimit).clamp(0.0, 1.0)
        : 0.0;
    final isOverBudget =
        b.budgetLimit > 0 && b.thisWeekSpend > b.budgetLimit;
    final barColor = isOverBudget ? BuxlyColors.hotPink : BuxlyColors.teal;

    String avgStatus = '';
    Color avgColor = BuxlyColors.midGrey;
    if (b.isBudgeted && b.budgetLimit > 0) {
      if (b.isAvgOverBudget) {
        avgStatus = 'Over budget';
        avgColor = BuxlyColors.coralOrange;
      } else if (b.weeklyAvgSpend > b.budgetLimit) {
        avgStatus = 'Normal variance';
        avgColor = BuxlyColors.limeGreen;
      } else if (b.isAvgUnderBudget) {
        avgStatus = 'Under budget';
        avgColor = BuxlyColors.limeGreen;
      } else {
        avgStatus = 'On track';
        avgColor = BuxlyColors.teal;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: b.transactions.isNotEmpty
              ? () {
                  setState(() {
                    if (isGroupExpanded) {
                      _expandedGroups.remove(index);
                    } else {
                      _expandedGroups.add(index);
                    }
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child:
                      Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              b.label,
                              style: const TextStyle(
                                fontFamily: BuxlyTheme.fontFamily,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: BuxlyColors.darkText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            b.budgetLimit > 0
                                ? "\$${b.thisWeekSpend.toStringAsFixed(0)} / \$${b.budgetLimit.toStringAsFixed(0)}"
                                : "\$${b.thisWeekSpend.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontFamily: BuxlyTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isOverBudget
                                  ? BuxlyColors.hotPink
                                  : BuxlyColors.darkText,
                            ),
                          ),
                        ],
                      ),
                      if (b.budgetLimit > 0) ...[
                        const SizedBox(height: 4),
                        BuxlyProgressBar(
                          value: barPercent,
                          color: barColor,
                          height: 6,
                        ),
                      ],
                      if (b.isBudgeted && b.budgetLimit > 0) ...[
                        const SizedBox(height: 3),
                        Text(
                          "Monthly avg: \$${b.weeklyAvgSpend.toStringAsFixed(0)}/wk",
                          style: const TextStyle(
                            fontFamily: BuxlyTheme.fontFamily,
                            fontSize: 11,
                            color: BuxlyColors.midGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (b.transactions.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      isGroupExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 20,
                      color: BuxlyColors.midGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isGroupExpanded && b.transactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 30, bottom: 4),
            child: Column(
              children: [
                for (final txn in b.transactions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            txn.description,
                            style: const TextStyle(
                              fontFamily: BuxlyTheme.fontFamily,
                              fontSize: 12,
                              color: BuxlyColors.midGrey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "-\$${txn.amount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontFamily: BuxlyTheme.fontFamily,
                            fontSize: 12,
                            color: BuxlyColors.midGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1, color: BuxlyColors.offWhite),
      ],
    );
  }
}
