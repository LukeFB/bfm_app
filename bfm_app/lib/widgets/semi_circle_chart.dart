/// ---------------------------------------------------------------------------
/// File: lib/widgets/semi_circle_chart.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Semi-circle (half donut) chart showing income breakdown with budgeted
///   and left-to-spend bars.
///
/// Called by:
///   - dashboard_screen.dart
/// ---------------------------------------------------------------------------

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:bfm_app/models/alert_model.dart';
import 'package:bfm_app/widgets/help_icon_tooltip.dart';

/// Semi-circle chart displaying income breakdown with budget tracking.
class SemiCircleChart extends StatelessWidget {
  final double income;
  final double totalBudgeted;
  final double spentOnBudgets;
  final double leftToSpend;
  final double discretionarySpent;
  final List<AlertModel> alerts;
  final VoidCallback? onAlertsPressed;
  final int streakWeeks;
  /// When true, hides the alerts section and centers the legend labels.
  final bool hideAlerts;

  // Colors - brighter orange
  static const Color orangeBright = Color(0xFFFF7A00);
  static const Color orangeLight = Color(0xFFFFE0C0);
  static const Color blueBright = Color(0xFF2196F3);
  static const Color blueLight = Color(0xFFBBDEFB);
  static const Color redOverspent = Color(0xFFE53935);

  const SemiCircleChart({
    super.key,
    required this.income,
    required this.totalBudgeted,
    required this.spentOnBudgets,
    required this.leftToSpend,
    required this.discretionarySpent,
    this.alerts = const [],
    this.onAlertsPressed,
    this.streakWeeks = 0,
    this.hideAlerts = false,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate if overspent
    final isOverspentOnBudgets = spentOnBudgets > totalBudgeted;
    // Budget overspend reduces the effective weekly limit
    final budgetOverspend = isOverspentOnBudgets ? spentOnBudgets - totalBudgeted : 0.0;
    final effectiveWeeklyLimit = (leftToSpend - budgetOverspend).clamp(0.0, double.infinity);
    final isOverspentDiscretionary = discretionarySpent > effectiveWeeklyLimit;

    // Total left to spend: income - budget spent - non-budget spent
    // This shows how much is left for both budgets AND non-budgets combined
    final totalLeftToSpend = income - spentOnBudgets - discretionarySpent;
    final isOverspentTotal = totalLeftToSpend < 0;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(double.infinity, 180),
                    painter: _SemiCircleChartPainter(
                      income: income,
                      totalBudgeted: totalBudgeted,
                      spentOnBudgets: spentOnBudgets,
                      leftToSpend: leftToSpend,
                      discretionarySpent: discretionarySpent,
                    ),
                  ),
                  // Center text showing left to spend
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${isOverspentTotal ? '-' : ''}\$${totalLeftToSpend.abs().toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isOverspentTotal ? redOverspent : Colors.black87,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'left for budgets & non-budgets',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 2),
                            HelpIconTooltip(
                              title: 'Left for Budgets & Non-budgets',
                              message: 'Total remaining after all spending.\n\n'
                                  'Calculation: Income − Budget Spent − Non-budget Spent\n\n'
                                  'This shows how much you have left to cover:\n'
                                  '• Remaining budget allocations\n'
                                  '• Any additional non-budget spending',
                              size: 12,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildLegend(
              isOverspentOnBudgets: isOverspentOnBudgets,
              isOverspentDiscretionary: isOverspentDiscretionary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend({
    required bool isOverspentOnBudgets,
    required bool isOverspentDiscretionary,
  }) {
    // Calculate amounts
    final leftOnBudgets = (totalBudgeted - spentOnBudgets).clamp(0.0, double.infinity);
    final budgetOverspend = (spentOnBudgets - totalBudgeted).clamp(0.0, double.infinity);
    // Left to spend is reduced by budget overspend (can go negative)
    final effectiveLimit = leftToSpend - budgetOverspend;
    final actualLeftToSpend = effectiveLimit - discretionarySpent; // Can be negative
    // Budget overspend consumed all weekly limit
    final noWeeklyLimitLeft = effectiveLimit <= 0;
    // Discretionary overspend (spending beyond what's left after budget overspend)
    final discretionaryOverspend = (discretionarySpent - effectiveLimit.clamp(0.0, double.infinity)).clamp(0.0, double.infinity);

    // Determine scenario
    // Scenario 1: Budget OK AND Non-budget OK
    // Scenario 2: Budget overspent AND still has effective left to spend AND non-budget OK
    // Scenario 3: Budget overspent AND (no effective left OR non-budget overspent)
    // Scenario 4: Budget OK AND Non-budget overspent
    
    final isScenario1 = !isOverspentOnBudgets && !isOverspentDiscretionary;
    final isScenario2 = isOverspentOnBudgets && !noWeeklyLimitLeft && !isOverspentDiscretionary;
    final isScenario3 = isOverspentOnBudgets && (noWeeklyLimitLeft || isOverspentDiscretionary);
    final isScenario4 = !isOverspentOnBudgets && isOverspentDiscretionary;

    // Build legend items list
    final legendItems = <Widget>[
      // === BUDGET SECTION ===
      if (isScenario1 || isScenario4) ...[
        // Scenario 1 & 4: Budget OK
        // (Orange) Budget spent
        _LegendItem(
          color: orangeBright,
          label: 'Budget Spent',
          value: '\$${spentOnBudgets.toStringAsFixed(0)}',
          isFilled: true,
          centered: hideAlerts,
          helpTitle: 'Budget Spent',
          helpMessage: 'Amount spent in budget categories (bills, groceries, etc.).\n\n'
              'This is spending in categories where you\'ve set a budget limit.',
        ),
        const SizedBox(height: 4),
        // (Light Orange) budget left
        _LegendItem(
          color: orangeBright,
          outlineColor: orangeLight,
          label: 'budget left',
          value: '\$${leftOnBudgets.toStringAsFixed(0)}',
          isFilled: false,
          centered: hideAlerts,
          helpTitle: 'Budget Left',
          helpMessage: 'Remaining budget allocation.\n\n'
              'Calculation: Total Budgeted − Budget Spent\n\n'
              'This is how much more you can spend before exceeding your budget limits.',
        ),
        const SizedBox(height: 4),
        // Budget: (no color)
        _LegendItem(
          color: orangeBright,
          label: 'Budget',
          value: '\$${totalBudgeted.toStringAsFixed(0)}',
          isFilled: true,
          showIndicator: false,
          centered: hideAlerts,
          helpTitle: 'Total Budget',
          helpMessage: 'Sum of all your weekly budget limits.\n\n'
              'This is the total amount allocated to budget categories.',
        ),
      ] else ...[
        // Scenario 2 & 3: Budget overspent
        // Budget spent: (no color)
        _LegendItem(
          color: orangeBright,
          label: 'Budget Spent',
          value: '\$${spentOnBudgets.toStringAsFixed(0)}',
          isFilled: true,
          showIndicator: false,
          centered: hideAlerts,
          helpTitle: 'Budget Spent',
          helpMessage: 'Amount spent in budget categories.\n\n'
              'You\'ve exceeded your budget limits.',
        ),
        const SizedBox(height: 4),
        // (Orange) Budgeted
        _LegendItem(
          color: orangeBright,
          label: 'Budgeted',
          value: '\$${totalBudgeted.toStringAsFixed(0)}',
          isFilled: true,
          centered: hideAlerts,
          helpTitle: 'Total Budgeted',
          helpMessage: 'Sum of all your weekly budget limits.',
        ),
        const SizedBox(height: 4),
        // (Red) Budget overspend
        _LegendItem(
          color: redOverspent,
          label: 'Budget overspend',
          value: '\$${budgetOverspend.toStringAsFixed(0)}',
          isFilled: true,
          centered: hideAlerts,
          helpTitle: 'Budget Overspend',
          helpMessage: 'Amount spent beyond your budget limits.\n\n'
              'Calculation: Budget Spent − Total Budgeted\n\n'
              'This reduces your available weekly limit.',
        ),
      ],
      const SizedBox(height: 8),
      
      // === DISCRETIONARY SECTION ===
      if (isScenario1) ...[
        // Scenario 1: Budget OK, Non-budget OK
        // (Blue) non-budget spent
        _LegendItem(
          color: blueBright,
          label: 'non-budget spent',
          value: '\$${discretionarySpent.toStringAsFixed(0)}',
          isFilled: true,
          centered: hideAlerts,
          helpTitle: 'Non-budget Spent',
          helpMessage: 'Spending in categories without a budget.\n\n'
              'This is discretionary spending outside your budget categories.',
        ),
        const SizedBox(height: 4),
        // (Light blue) left to spend
        _LegendItem(
          color: blueBright,
          outlineColor: blueLight,
          label: 'left to spend',
          value: '\$${actualLeftToSpend.clamp(0.0, double.infinity).toStringAsFixed(0)}',
          isFilled: false,
          centered: hideAlerts,
          helpTitle: 'Left to Spend',
          helpMessage: 'Remaining discretionary budget.\n\n'
              'Calculation: Weekly Limit − Non-budget Spent\n\n'
              'This is how much more you can spend on non-budget items.',
        ),
        const SizedBox(height: 4),
        // Weekly limit: (no color)
        _LegendItem(
          color: blueBright,
          label: 'Weekly limit',
          value: '\$${leftToSpend.toStringAsFixed(0)}',
          isFilled: true,
          showIndicator: false,
          centered: hideAlerts,
          helpTitle: 'Weekly Limit',
          helpMessage: 'Your discretionary budget for non-budget spending.\n\n'
              'Calculation: Income − Total Budgeted\n\n'
              'This is your allowance for spending outside budget categories.',
        ),
      ] else if (isScenario2) ...[
        // Scenario 2: Budget overspent, still left to spend from weekly limit
        // (light blue) Left to spend
        _LegendItem(
          color: blueBright,
          outlineColor: blueLight,
          label: 'Left to spend',
          value: '\$${actualLeftToSpend.clamp(0.0, double.infinity).toStringAsFixed(0)}',
          isFilled: false,
          centered: hideAlerts,
          helpTitle: 'Left to Spend',
          helpMessage: 'Remaining after budget overspend and non-budget spending.',
        ),
        const SizedBox(height: 4),
        // (Blue) Non-budget spent
        _LegendItem(
          color: blueBright,
          label: 'Non-budget spent',
          value: '\$${discretionarySpent.toStringAsFixed(0)}',
          isFilled: true,
          centered: hideAlerts,
          helpTitle: 'Non-budget Spent',
          helpMessage: 'Spending in categories without a budget.',
        ),
        const SizedBox(height: 4),
        // Weekly limit: (no color) - reduced by budget overspend
        _LegendItem(
          color: blueBright,
          label: 'Weekly limit',
          value: '\$${effectiveLimit.clamp(0.0, double.infinity).toStringAsFixed(0)}',
          isFilled: true,
          showIndicator: false,
          centered: hideAlerts,
          helpTitle: 'Reduced Weekly Limit',
          helpMessage: 'Your weekly limit reduced by budget overspend.\n\n'
              'Budget overspending eats into your discretionary budget.',
        ),
      ] else if (isScenario3) ...[
        // Scenario 3: Budget overspent AND (no effective left OR non-budget overspent)
        if (noWeeklyLimitLeft) ...[
          // Sub-case: Budget overspend consumed ALL weekly limit
          // All non-budget spending is red (no weekly limit left)
          if (discretionarySpent > 0)
            _LegendItem(
              color: redOverspent,
              label: 'Non-budget spent',
              value: '\$${discretionarySpent.toStringAsFixed(0)}',
              isFilled: true,
              centered: hideAlerts,
              helpTitle: 'Non-budget Overspend',
              helpMessage: 'All non-budget spending is over limit.\n\n'
                  'Budget overspending consumed your entire weekly limit.',
            ),
        ] else ...[
          // Sub-case: Still has effective limit but non-budget overspent
          // Non-budget spend: (no color) - total non-budget spent
          _LegendItem(
            color: blueBright,
            label: 'Non-budget spend',
            value: '\$${discretionarySpent.toStringAsFixed(0)}',
            isFilled: true,
            showIndicator: false,
            centered: hideAlerts,
            helpTitle: 'Non-budget Spent',
            helpMessage: 'Total spending in non-budget categories.',
          ),
          const SizedBox(height: 4),
          // (Blue) Weekly limit - the reduced effective limit
          _LegendItem(
            color: blueBright,
            label: 'Weekly limit',
            value: '\$${effectiveLimit.clamp(0.0, double.infinity).toStringAsFixed(0)}',
            isFilled: true,
            centered: hideAlerts,
            helpTitle: 'Reduced Weekly Limit',
            helpMessage: 'Weekly limit reduced by budget overspend.',
          ),
          const SizedBox(height: 4),
          // (Red) Non-budget overspend - amount over the limit
          _LegendItem(
            color: redOverspent,
            label: 'Non-budget overspend',
            value: '\$${discretionaryOverspend.toStringAsFixed(0)}',
            isFilled: true,
            centered: hideAlerts,
            helpTitle: 'Non-budget Overspend',
            helpMessage: 'Amount spent beyond your weekly limit.\n\n'
                'Calculation: Non-budget Spent − Weekly Limit',
          ),
        ],
      ] else if (isScenario4) ...[
        // Scenario 4: Budget OK, Non-budget overspent
        // non-budget spent: (no color)
        _LegendItem(
          color: blueBright,
          label: 'non-budget spent',
          value: '\$${discretionarySpent.toStringAsFixed(0)}',
          isFilled: true,
          showIndicator: false,
          centered: hideAlerts,
          helpTitle: 'Non-budget Spent',
          helpMessage: 'Total spending in non-budget categories.',
        ),
        const SizedBox(height: 4),
        // (Blue) weekly limit
        _LegendItem(
          color: blueBright,
          label: 'weekly limit',
          value: '\$${leftToSpend.toStringAsFixed(0)}',
          isFilled: true,
          centered: hideAlerts,
          helpTitle: 'Weekly Limit',
          helpMessage: 'Your discretionary budget (Income − Budgeted).',
        ),
        const SizedBox(height: 4),
        // (Red) non-budget overspend
        _LegendItem(
          color: redOverspent,
          label: 'non-budget overspend',
          value: '\$${discretionaryOverspend.toStringAsFixed(0)}',
          isFilled: true,
          centered: hideAlerts,
          helpTitle: 'Non-budget Overspend',
          helpMessage: 'Amount spent beyond your weekly limit.\n\n'
              'Calculation: Non-budget Spent − Weekly Limit',
        ),
      ],
      const SizedBox(height: 8),
      // Income: (no color)
      _LegendItem(
        color: Colors.grey,
        label: 'Income',
        value: '\$${income.toStringAsFixed(0)}',
        isFilled: true,
        showIndicator: false,
        centered: hideAlerts,
        helpTitle: 'Weekly Income',
        helpMessage: 'Your expected income for this week.\n\n'
            'For regular income: Uses last week\'s actual income.\n'
            'For irregular income: Uses 4-week average.',
      ),
      // Streak display (only show when > 1)
      if (streakWeeks > 1) ...[
        const SizedBox(height: 12),
        Align(
          alignment: hideAlerts ? Alignment.center : Alignment.centerLeft,
          child: Padding(
            padding: hideAlerts ? EdgeInsets.zero : const EdgeInsets.only(left: 24),
            child: Text(
              '$streakWeeks🔥',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ];

    // When hideAlerts is true, return centered legend only
    if (hideAlerts) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: legendItems,
      );
    }

    // Original layout with alerts section
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side: Legend
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: legendItems,
          ),
        ),
        const SizedBox(width: 8),
        // Right side: Alerts card
        Expanded(
          child: _buildAlertsSection(),
        ),
      ],
    );
  }

  Widget _buildAlertsSection() {
    final now = DateTime.now();
    
    // Alerts are already sorted by due date in the service, but ensure sorting here too
    final sortedAlerts = List<AlertModel>.from(alerts)
      ..sort((a, b) {
        // Nulls go to the end
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
    
    return Container(
      height: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Alerts',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAlertsPressed,
                child: const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: sortedAlerts.isEmpty
                ? const Text(
                    'No alerts',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: sortedAlerts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final alert = sortedAlerts[index];
                      final daysLeft = alert.dueDate != null
                          ? alert.dueDate!.difference(now).inDays
                          : null;
                      final icon = alert.icon ?? '🔔';
                      final hasAmount = alert.amount != null && alert.amount! > 0;
                      
                      // Build days text
                      String daysText = '';
                      if (daysLeft != null) {
                        daysText = daysLeft <= 0
                            ? 'Today'
                            : daysLeft == 1
                                ? '1d'
                                : '${daysLeft}d';
                      }

                      return GestureDetector(
                        onTap: onAlertsPressed,
                        child: Row(
                          children: [
                            Text(icon, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                alert.title,
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasAmount) ...[
                              Text(
                                '\$${alert.amount!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (daysText.isNotEmpty)
                              Text(
                                daysText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: (daysLeft ?? 999) <= 1 ? redOverspent : Colors.grey,
                                  fontWeight: (daysLeft ?? 999) <= 1 ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color? outlineColor;
  final String label;
  final String value;
  final bool isFilled;
  final bool showIndicator;
  final bool centered;
  final String? helpTitle;
  final String? helpMessage;

  const _LegendItem({
    required this.color,
    this.outlineColor,
    required this.label,
    required this.value,
    required this.isFilled,
    this.showIndicator = true,
    this.centered = false,
    this.helpTitle,
    this.helpMessage,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showIndicator)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isFilled ? color : (outlineColor ?? Colors.transparent),
                border: isFilled ? null : Border.all(color: color, width: 1.5),
                shape: BoxShape.circle,
              ),
            ),
          )
        else
          const SizedBox(width: 12),
        const SizedBox(width: 8),
        Flexible(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$label: ',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: showIndicator ? (isFilled ? color : Colors.black87) : Colors.black87,
                ),
              ),
              if (helpMessage != null) ...[
                const SizedBox(width: 2),
                HelpIconTooltip(
                  title: helpTitle ?? label,
                  message: helpMessage!,
                  size: 11,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (centered) {
      return Center(child: content);
    }
    return content;
  }
}

class _SemiCircleChartPainter extends CustomPainter {
  final double income;
  final double totalBudgeted;
  final double spentOnBudgets;
  final double leftToSpend;
  final double discretionarySpent;

  // Colors - brighter
  static const Color _orangeBright = Color(0xFFFF7A00);
  static const Color _orangeLight = Color(0xFFFFE0C0);
  static const Color _blueBright = Color(0xFF2196F3);
  static const Color _blueLight = Color(0xFFBBDEFB);
  static const Color _redOverspent = Color(0xFFE53935);
  static const Color _backgroundTrack = Color(0xFFE8E8E8);

  _SemiCircleChartPainter({
    required this.income,
    required this.totalBudgeted,
    required this.spentOnBudgets,
    required this.leftToSpend,
    required this.discretionarySpent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 24.0;
    final topPadding = strokeWidth / 2 + 140;
    final radius = math.min(size.width / 2 - 16, size.height - 20);
    final center = Offset(size.width / 2, topPadding);
    const gapAngle = 0.04; // Small gap between sections

    const totalAngle = math.pi;
    const startAngle = math.pi; // Start from left side of semi-circle

    if (income <= 0) {
      _drawEmptyTrack(canvas, center, radius, strokeWidth);
      return;
    }

    _drawEmptyTrack(canvas, center, radius, strokeWidth);

    // Calculate key values
    final isOverspentBudget = spentOnBudgets > totalBudgeted;
    final budgetOverspend = isOverspentBudget ? spentOnBudgets - totalBudgeted : 0.0;
    final effectiveLeftToSpend = (leftToSpend - budgetOverspend).clamp(0.0, double.infinity);
    final noWeeklyLimitLeft = effectiveLeftToSpend <= 0;
    final isOverspentDiscretionary = discretionarySpent > effectiveLeftToSpend;
    final discretionaryOverspend = isOverspentDiscretionary ? discretionarySpent - effectiveLeftToSpend : 0.0;
    
    // Determine scenario
    // Scenario 1: Budget OK AND Non-budget OK
    // Scenario 2: Budget overspent AND still has effective left AND non-budget OK
    // Scenario 3: Budget overspent AND (no effective left OR non-budget overspent)
    // Scenario 4: Budget OK AND Non-budget overspent
    final isScenario1 = !isOverspentBudget && !isOverspentDiscretionary;
    final isScenario2 = isOverspentBudget && !noWeeklyLimitLeft && !isOverspentDiscretionary;
    final isScenario3 = isOverspentBudget && (noWeeklyLimitLeft || isOverspentDiscretionary);
    final isScenario4 = !isOverspentBudget && isOverspentDiscretionary;

    if (isScenario1) {
      // ===== SCENARIO 1: Budget OK, Non-budget OK =====
      // Use the actual sum of components as base to prevent wrap-around
      final totalBase = totalBudgeted + leftToSpend;
      if (totalBase <= 0) return;
      
      final budgetAngle = totalAngle * (totalBudgeted / totalBase).clamp(0.0, 1.0);
      final leftToSpendAngle = totalAngle * (leftToSpend / totalBase).clamp(0.0, 1.0);
      
      var currentPos = startAngle;
      
      // Orange outline (budget) with orange fill based on spent
      if (budgetAngle > 0.01) {
        final drawAngle = (budgetAngle - gapAngle/2).clamp(0.0, totalAngle);
        _drawArc(canvas, center, radius, currentPos, drawAngle, _orangeLight, strokeWidth);
        if (spentOnBudgets > 0) {
          final fillRatio = (spentOnBudgets / totalBudgeted).clamp(0.0, 1.0);
          _drawArc(canvas, center, radius, currentPos, drawAngle * fillRatio, _orangeBright, strokeWidth - 4);
        }
        currentPos += budgetAngle + gapAngle/2;
      }
      
      // Blue outline (weekly limit) with blue fill based on non-budget spent
      // Clamp to remaining space in semi-circle
      final remainingAngle = (startAngle + totalAngle - currentPos).clamp(0.0, totalAngle);
      final actualLeftAngle = leftToSpendAngle.clamp(0.0, remainingAngle);
      if (actualLeftAngle > 0.01) {
        final drawAngle = (actualLeftAngle - gapAngle/2).clamp(0.0, remainingAngle);
        _drawArc(canvas, center, radius, currentPos, drawAngle, _blueLight, strokeWidth);
        if (discretionarySpent > 0 && leftToSpend > 0) {
          final fillRatio = (discretionarySpent / leftToSpend).clamp(0.0, 1.0);
          _drawArc(canvas, center, radius, currentPos, drawAngle * fillRatio, _blueBright, strokeWidth - 4);
        }
      }
      
    } else if (isScenario2) {
      // ===== SCENARIO 2: Budget overspent, Non-budget OK =====
      // Use total for proportions: budget + budget overspend + effective limit
      final totalBase = totalBudgeted + budgetOverspend + effectiveLeftToSpend;
      if (totalBase <= 0) return;
      
      final budgetAngle = (totalAngle * (totalBudgeted / totalBase)).clamp(0.0, totalAngle);
      final budgetOverspendAngle = (totalAngle * (budgetOverspend / totalBase)).clamp(0.0, totalAngle);
      final effectiveLimitAngle = (totalAngle * (effectiveLeftToSpend / totalBase)).clamp(0.0, totalAngle);
      
      var currentPos = startAngle;
      
      // Orange filled (100% since overspent)
      if (budgetAngle > 0.01) {
        final drawAngle = budgetAngle.clamp(0.0, startAngle + totalAngle - currentPos);
        _drawArc(canvas, center, radius, currentPos, drawAngle, _orangeLight, strokeWidth);
        _drawArc(canvas, center, radius, currentPos, drawAngle, _orangeBright, strokeWidth - 4);
        currentPos += drawAngle;
      }
      
      // Red (budget overspend)
      if (budgetOverspendAngle > 0.01) {
        final drawAngle = budgetOverspendAngle.clamp(0.0, startAngle + totalAngle - currentPos);
        _drawArc(canvas, center, radius, currentPos, drawAngle, _redOverspent, strokeWidth - 4);
        currentPos += drawAngle;
      }
      
      // Blue outline with fill based on non-budget spent
      final remainingAngle = (startAngle + totalAngle - currentPos - gapAngle).clamp(0.0, totalAngle);
      if (remainingAngle > 0.01) {
        currentPos += gapAngle;
        final drawAngle = effectiveLimitAngle.clamp(0.0, remainingAngle);
        _drawArc(canvas, center, radius, currentPos, drawAngle, _blueLight, strokeWidth);
        if (discretionarySpent > 0 && effectiveLeftToSpend > 0) {
          final fillRatio = (discretionarySpent / effectiveLeftToSpend).clamp(0.0, 1.0);
          _drawArc(canvas, center, radius, currentPos, drawAngle * fillRatio, _blueBright, strokeWidth - 4);
        }
      }
      
    } else if (isScenario3) {
      // ===== SCENARIO 3: Budget overspent AND (no effective left OR non-budget overspent) =====
      
      if (noWeeklyLimitLeft) {
        // Sub-case: Budget overspend consumed ALL weekly limit
        // Show: budget (orange), budget overspend (red), non-budget spent (red) - NO blue section
        final totalBase = totalBudgeted + budgetOverspend + discretionarySpent;
        if (totalBase <= 0) return;
        
        final budgetAngle = (totalAngle * (totalBudgeted / totalBase)).clamp(0.0, totalAngle);
        final budgetOverspendAngle = (totalAngle * (budgetOverspend / totalBase)).clamp(0.0, totalAngle);
        final nonBudgetSpentAngle = (totalAngle * (discretionarySpent / totalBase)).clamp(0.0, totalAngle);
        
        var currentPos = startAngle;
        
        // Orange filled (100% since overspent)
        if (budgetAngle > 0.01) {
          final drawAngle = budgetAngle.clamp(0.0, startAngle + totalAngle - currentPos);
          _drawArc(canvas, center, radius, currentPos, drawAngle, _orangeLight, strokeWidth);
          _drawArc(canvas, center, radius, currentPos, drawAngle, _orangeBright, strokeWidth - 4);
          currentPos += drawAngle;
        }
        
        // Red (budget overspend)
        if (budgetOverspendAngle > 0.01) {
          final drawAngle = budgetOverspendAngle.clamp(0.0, startAngle + totalAngle - currentPos);
          _drawArc(canvas, center, radius, currentPos, drawAngle, _redOverspent, strokeWidth - 4);
          currentPos += drawAngle;
        }
        
        // Red (non-budget spent - all red since no weekly limit left)
        final remainingAngle = (startAngle + totalAngle - currentPos - gapAngle).clamp(0.0, totalAngle);
        if (remainingAngle > 0.01) {
          currentPos += gapAngle;
          final drawAngle = nonBudgetSpentAngle.clamp(0.0, remainingAngle);
          _drawArc(canvas, center, radius, currentPos, drawAngle, _redOverspent, strokeWidth - 4);
        }
        
      } else {
        // Sub-case: Still has effective limit but non-budget overspent
        // Show: budget (orange), budget overspend (red), weekly limit (blue), non-budget overspend (red)
        final totalBase = totalBudgeted + budgetOverspend + effectiveLeftToSpend + discretionaryOverspend;
        if (totalBase <= 0) return;
        
        final budgetAngle = (totalAngle * (totalBudgeted / totalBase)).clamp(0.0, totalAngle);
        final budgetOverspendAngle = (totalAngle * (budgetOverspend / totalBase)).clamp(0.0, totalAngle);
        final weeklyLimitAngle = (totalAngle * (effectiveLeftToSpend / totalBase)).clamp(0.0, totalAngle);
        final nonBudgetOverspendAngle = (totalAngle * (discretionaryOverspend / totalBase)).clamp(0.0, totalAngle);
        
        var currentPos = startAngle;
        
        // Orange filled (100% since overspent)
        if (budgetAngle > 0.01) {
          final drawAngle = budgetAngle.clamp(0.0, startAngle + totalAngle - currentPos);
          _drawArc(canvas, center, radius, currentPos, drawAngle, _orangeLight, strokeWidth);
          _drawArc(canvas, center, radius, currentPos, drawAngle, _orangeBright, strokeWidth - 4);
          currentPos += drawAngle;
        }
        
        // Red (budget overspend)
        if (budgetOverspendAngle > 0.01) {
          final drawAngle = budgetOverspendAngle.clamp(0.0, startAngle + totalAngle - currentPos);
          _drawArc(canvas, center, radius, currentPos, drawAngle, _redOverspent, strokeWidth - 4);
          currentPos += drawAngle;
        }
        
        // Blue (effective weekly limit)
        var remainingAngle = (startAngle + totalAngle - currentPos - gapAngle).clamp(0.0, totalAngle);
        if (remainingAngle > 0.01 && weeklyLimitAngle > 0.01) {
          currentPos += gapAngle;
          final drawAngle = weeklyLimitAngle.clamp(0.0, remainingAngle);
          _drawArc(canvas, center, radius, currentPos, drawAngle, _blueLight, strokeWidth);
          _drawArc(canvas, center, radius, currentPos, drawAngle, _blueBright, strokeWidth - 4);
          currentPos += drawAngle;
        }
        
        // Red (non-budget overspend)
        remainingAngle = (startAngle + totalAngle - currentPos).clamp(0.0, totalAngle);
        if (remainingAngle > 0.01 && nonBudgetOverspendAngle > 0.01) {
          final drawAngle = nonBudgetOverspendAngle.clamp(0.0, remainingAngle);
          _drawArc(canvas, center, radius, currentPos, drawAngle, _redOverspent, strokeWidth - 4);
        }
      }
      
    } else if (isScenario4) {
      // ===== SCENARIO 4: Budget OK, Non-budget overspent =====
      // Use total for proportions: budget + weekly limit + non-budget overspend
      final totalBase = totalBudgeted + leftToSpend + discretionaryOverspend;
      if (totalBase <= 0) return;
      
      final budgetAngle = (totalAngle * (totalBudgeted / totalBase)).clamp(0.0, totalAngle);
      final weeklyLimitAngle = (totalAngle * (leftToSpend / totalBase)).clamp(0.0, totalAngle);
      final overspendAngle = (totalAngle * (discretionaryOverspend / totalBase)).clamp(0.0, totalAngle);
      
      var currentPos = startAngle;
      
      // Orange outline with fill based on spent
      if (budgetAngle > 0.01) {
        final drawAngle = (budgetAngle - gapAngle/2).clamp(0.0, startAngle + totalAngle - currentPos);
        _drawArc(canvas, center, radius, currentPos, drawAngle, _orangeLight, strokeWidth);
        if (spentOnBudgets > 0 && totalBudgeted > 0) {
          final fillRatio = (spentOnBudgets / totalBudgeted).clamp(0.0, 1.0);
          _drawArc(canvas, center, radius, currentPos, drawAngle * fillRatio, _orangeBright, strokeWidth - 4);
        }
        currentPos += budgetAngle + gapAngle/2;
      }
      
      // Blue filled (100% since non-budget overspent)
      var remainingAngle = (startAngle + totalAngle - currentPos).clamp(0.0, totalAngle);
      if (remainingAngle > 0.01 && weeklyLimitAngle > 0.01) {
        final drawAngle = weeklyLimitAngle.clamp(0.0, remainingAngle);
        _drawArc(canvas, center, radius, currentPos, drawAngle, _blueLight, strokeWidth);
        _drawArc(canvas, center, radius, currentPos, drawAngle, _blueBright, strokeWidth - 4);
        currentPos += drawAngle;
      }
      
      // Red (non-budget overspend)
      remainingAngle = (startAngle + totalAngle - currentPos).clamp(0.0, totalAngle);
      if (remainingAngle > 0.01 && overspendAngle > 0.01) {
        final drawAngle = overspendAngle.clamp(0.0, remainingAngle);
        _drawArc(canvas, center, radius, currentPos, drawAngle, _redOverspent, strokeWidth - 4);
      }
    }
  }
  
  void _drawArc(Canvas canvas, Offset center, double radius, double startAngle, double sweepAngle, Color color, double strokeWidth) {
    if (sweepAngle <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  void _drawEmptyTrack(
    Canvas canvas,
    Offset center,
    double radius,
    double strokeWidth,
  ) {
    final paint = Paint()
      ..color = _backgroundTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SemiCircleChartPainter oldDelegate) {
    return oldDelegate.income != income ||
        oldDelegate.totalBudgeted != totalBudgeted ||
        oldDelegate.spentOnBudgets != spentOnBudgets ||
        oldDelegate.leftToSpend != leftToSpend ||
        oldDelegate.discretionarySpent != discretionarySpent;
  }
}
