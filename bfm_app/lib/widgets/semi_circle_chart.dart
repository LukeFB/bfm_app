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
  });

  @override
  Widget build(BuildContext context) {
    // Calculate if overspent
    final isOverspentOnBudgets = spentOnBudgets > totalBudgeted;
    final isOverspentDiscretionary = discretionarySpent > leftToSpend;

    // Total left to spend (can be negative if overspent)
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
                          '\$${totalLeftToSpend.abs().toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isOverspentTotal ? redOverspent : Colors.black87,
                          ),
                        ),
                        Text(
                          isOverspentTotal ? 'overspent' : 'left to spend',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
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
    final budgetOverspendAmount = (spentOnBudgets - totalBudgeted).clamp(0.0, double.infinity);
    final leftOnBudgets = (totalBudgeted - spentOnBudgets).clamp(0.0, double.infinity);
    final discretionaryOverspendAmount = (discretionarySpent - leftToSpend).clamp(0.0, double.infinity);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side: Legend
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Budget section - spent/overspent
              _LegendItem(
                color: isOverspentOnBudgets ? redOverspent : orangeBright,
                label: isOverspentOnBudgets ? 'Overspent' : 'Budget spent',
                value: isOverspentOnBudgets
                    ? '\$${budgetOverspendAmount.toStringAsFixed(0)}'
                    : '\$${spentOnBudgets.toStringAsFixed(0)}',
                isFilled: true,
              ),
              const SizedBox(height: 4),
              // Budget section - left/budgeted (orange filled when overspent)
              _LegendItem(
                color: orangeBright,
                outlineColor: orangeLight,
                label: isOverspentOnBudgets ? 'Budgeted' : 'Left',
                value: isOverspentOnBudgets
                    ? '\$${totalBudgeted.toStringAsFixed(0)}'
                    : '\$${leftOnBudgets.toStringAsFixed(0)}',
                isFilled: isOverspentOnBudgets, // Orange filled when overspent
              ),
              const SizedBox(height: 8),
            // Non-budget section - show "Spent" normally, "Spending" only when overspent
            _LegendItem(
              color: blueBright,
              label: isOverspentDiscretionary ? 'Spending' : 'Spent',
              value: isOverspentDiscretionary
                  ? '\$${leftToSpend.toStringAsFixed(0)}'
                  : '\$${discretionarySpent.toStringAsFixed(0)}',
              isFilled: true,
            ),
            // Show overspent in red if overspent on non-budget
            if (isOverspentDiscretionary) ...[
              const SizedBox(height: 4),
              _LegendItem(
                color: redOverspent,
                label: 'Overspent',
                value: '\$${discretionaryOverspendAmount.toStringAsFixed(0)}',
                isFilled: true,
              ),
            ],
              // Streak display (only show when > 1)
              if (streakWeeks > 1) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24),
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
            ],
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

  const _LegendItem({
    required this.color,
    this.outlineColor,
    required this.label,
    required this.value,
    required this.isFilled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isFilled ? color : (outlineColor ?? Colors.transparent),
            border: isFilled ? null : Border.all(color: color, width: 1.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
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
            color: isFilled ? color : Colors.black87,
          ),
        ),
      ],
    );
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
    // Position center much lower in the widget
    final topPadding = strokeWidth / 2 + 140;
    final radius = math.min(size.width / 2 - 16, size.height - 20);
    final center = Offset(size.width / 2, topPadding);
    const gapAngle = 0.06;

    const totalAngle = math.pi;

    if (income <= 0) {
      _drawEmptyTrack(canvas, center, radius, strokeWidth);
      return;
    }

    // Calculate overspent amounts
    final isOverspentBudget = spentOnBudgets > totalBudgeted;
    final isOverspentDiscretionary = discretionarySpent > leftToSpend;
    final budgetOverspend = isOverspentBudget ? spentOnBudgets - totalBudgeted : 0.0;
    final discretionaryOverspend = isOverspentDiscretionary ? discretionarySpent - leftToSpend : 0.0;

    // Calculate base angles (without overspend)
    final budgetedProportion = (totalBudgeted / income).clamp(0.0, 1.0);
    final leftToSpendProportion = (leftToSpend / income).clamp(0.0, 1.0);
    final budgetOverspendProportion = (budgetOverspend / income).clamp(0.0, 1.0);
    final discretionaryOverspendProportion = (discretionaryOverspend / income).clamp(0.0, 1.0);

    final budgetedAngle = totalAngle * budgetedProportion;
    final leftToSpendAngle = totalAngle * leftToSpendProportion;
    final budgetOverspendAngle = totalAngle * budgetOverspendProportion;
    final discretionaryOverspendAngle = totalAngle * discretionaryOverspendProportion;

    _drawEmptyTrack(canvas, center, radius, strokeWidth);

    double currentAngle = math.pi;
    final adjustedBudgetAngle = budgetedAngle - (leftToSpendAngle > 0 ? gapAngle / 2 : 0);
    final blueStartAngle = math.pi + budgetedAngle + gapAngle;
    final adjustedLeftAngle = leftToSpendAngle - (budgetedAngle > 0 ? gapAngle / 2 : 0);

    // 1. Draw BLUE section outline FIRST (will be under orange)
    if (adjustedLeftAngle > 0) {
      final outlinePaint = Paint()
        ..color = _blueLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        blueStartAngle,
        adjustedLeftAngle,
        false,
        outlinePaint,
      );
    }

    // 2. Draw BLUE fill
    if (leftToSpend > 0 && discretionarySpent > 0) {
      final fillPaint = Paint()
        ..color = _blueBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth - 4
        ..strokeCap = StrokeCap.round;

      // Fill up to spent amount (capped at left-to-spend angle)
      final fillRatio = (discretionarySpent / leftToSpend).clamp(0.0, 1.0);
      final blueFillAngle = isOverspentDiscretionary
          ? adjustedLeftAngle
          : adjustedLeftAngle * fillRatio;

      if (blueFillAngle > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          blueStartAngle,
          blueFillAngle,
          false,
          fillPaint,
        );
      }
    }

    // 3. Draw ORANGE section outline (overlaps blue)
    if (adjustedBudgetAngle > 0) {
      final outlinePaint = Paint()
        ..color = _orangeLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        adjustedBudgetAngle,
        false,
        outlinePaint,
      );
    }

    // 4. Draw ORANGE fill
    if (totalBudgeted > 0 && spentOnBudgets > 0) {
      final fillPaint = Paint()
        ..color = _orangeBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth - 4
        ..strokeCap = StrokeCap.round;

      // Fill up to spent amount (capped at budgeted angle)
      final fillRatio = (spentOnBudgets / totalBudgeted).clamp(0.0, 1.0);
      final orangeFillAngle = isOverspentBudget 
          ? adjustedBudgetAngle 
          : adjustedBudgetAngle * fillRatio;

      if (orangeFillAngle > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          currentAngle,
          orangeFillAngle,
          false,
          fillPaint,
        );
      }
    }

    // 5. Draw RED overspend LAST (so it overlaps everything)
    // Budget overspend - starts at end of budget section, overlaps into blue
    if (isOverspentBudget && budgetOverspendAngle > 0) {
      final redPaint = Paint()
        ..color = _redOverspent
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth - 4
        ..strokeCap = StrokeCap.round;

      final redStartAngle = currentAngle + adjustedBudgetAngle;
      final maxBudgetOverspend = math.max(0.0, totalAngle - (redStartAngle - math.pi));
      final clampedBudgetOverspend = budgetOverspendAngle.clamp(0.0, maxBudgetOverspend);
      
      if (clampedBudgetOverspend > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          redStartAngle,
          clampedBudgetOverspend,
          false,
          redPaint,
        );
      }
    }

    // Discretionary overspend - draw red at the end of blue section, overlapping it
    if (isOverspentDiscretionary && discretionaryOverspendAngle > 0) {
      final redPaint = Paint()
        ..color = _redOverspent
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth - 4
        ..strokeCap = StrokeCap.round;

      // Red overlaps the end of the blue section
      // Start the red bar earlier so it's visible at the end of the chart
      final redSweep = discretionaryOverspendAngle.clamp(0.0, adjustedLeftAngle);
      final redStartAngle = blueStartAngle + adjustedLeftAngle - redSweep;
      
      if (redSweep > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          redStartAngle,
          redSweep,
          false,
          redPaint,
        );
      }
    }
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
