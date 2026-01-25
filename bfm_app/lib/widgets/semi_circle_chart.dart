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

/// Semi-circle chart displaying income breakdown with budget tracking.
class SemiCircleChart extends StatelessWidget {
  final double income;
  final double totalBudgeted;
  final double spentOnBudgets;
  final double leftToSpend;
  final double discretionarySpent;

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
  });

  @override
  Widget build(BuildContext context) {
    // Calculate if overspent
    final isOverspentOnBudgets = spentOnBudgets > totalBudgeted;
    final isOverspentDiscretionary = discretionarySpent > leftToSpend;

    // Calculate remaining amounts
    final leftOnBudgets = (totalBudgeted - spentOnBudgets).clamp(0.0, double.infinity);
    final leftToSpendRemaining = (leftToSpend - discretionarySpent).clamp(0.0, double.infinity);

    return Card(
      elevation: 0,
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: CustomPaint(
                size: const Size(double.infinity, 180),
                painter: _SemiCircleChartPainter(
                  income: income,
                  totalBudgeted: totalBudgeted,
                  spentOnBudgets: spentOnBudgets,
                  leftToSpend: leftToSpend,
                  discretionarySpent: discretionarySpent,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(
              isOverspentOnBudgets: isOverspentOnBudgets,
              isOverspentDiscretionary: isOverspentDiscretionary,
              leftOnBudgets: leftOnBudgets,
              leftToSpendRemaining: leftToSpendRemaining,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend({
    required bool isOverspentOnBudgets,
    required bool isOverspentDiscretionary,
    required double leftOnBudgets,
    required double leftToSpendRemaining,
  }) {
    // Calculate overspend amounts (spent - budgeted)
    final budgetOverspendAmount = (spentOnBudgets - totalBudgeted).clamp(0.0, double.infinity);
    final discretionaryOverspendAmount = (discretionarySpent - leftToSpend).clamp(0.0, double.infinity);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        children: [
          // Orange section (budgets)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: orangeLight.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  bottomLeft: Radius.circular(11),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegendRow(
                    color: isOverspentOnBudgets ? redOverspent : orangeBright,
                    label: isOverspentOnBudgets ? 'Overspent:' : 'Spent:',
                    value: isOverspentOnBudgets
                        ? '\$${budgetOverspendAmount.toStringAsFixed(0)}'
                        : '\$${spentOnBudgets.toStringAsFixed(0)}',
                    isFilled: true,
                  ),
                  const SizedBox(height: 6),
                  _LegendRow(
                    color: orangeBright,
                    label: isOverspentOnBudgets ? 'Budgeted:' : 'Left:',
                    value: isOverspentOnBudgets 
                        ? '\$${totalBudgeted.toStringAsFixed(0)}'
                        : '\$${leftOnBudgets.toStringAsFixed(0)}',
                    isFilled: false,
                    fillColor: orangeLight,
                  ),
                ],
              ),
            ),
          ),
          // Blue section (discretionary)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: blueLight.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegendRow(
                    color: isOverspentDiscretionary ? redOverspent : blueBright,
                    label: isOverspentDiscretionary ? 'Overspent:' : 'Spent:',
                    value: isOverspentDiscretionary
                        ? '\$${discretionaryOverspendAmount.toStringAsFixed(0)}'
                        : '\$${discretionarySpent.toStringAsFixed(0)}',
                    isFilled: true,
                  ),
                  const SizedBox(height: 6),
                  _LegendRow(
                    color: blueBright,
                    label: isOverspentDiscretionary ? 'Budgeted:' : 'Left:',
                    value: isOverspentDiscretionary
                        ? '\$${leftToSpend.toStringAsFixed(0)}'
                        : '\$${leftToSpendRemaining.toStringAsFixed(0)}',
                    isFilled: false,
                    fillColor: blueLight,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final bool isFilled;
  final Color? fillColor;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.isFilled,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isFilled ? color : (fillColor ?? Colors.transparent),
            border: isFilled ? null : Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
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

    // Discretionary overspend - starts at end of blue section
    if (isOverspentDiscretionary && discretionaryOverspendAngle > 0) {
      final redPaint = Paint()
        ..color = _redOverspent
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth - 4
        ..strokeCap = StrokeCap.round;

      final redStartAngle = blueStartAngle + adjustedLeftAngle;
      final maxDiscretionaryOverspend = math.max(0.0, math.pi * 2 - redStartAngle);
      final clampedDiscretionaryOverspend = discretionaryOverspendAngle.clamp(0.0, maxDiscretionaryOverspend);
      
      if (clampedDiscretionaryOverspend > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          redStartAngle,
          clampedDiscretionaryOverspend,
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
