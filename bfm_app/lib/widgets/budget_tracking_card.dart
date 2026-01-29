/// ---------------------------------------------------------------------------
/// File: lib/widgets/budget_tracking_card.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   - Displays a "Track your spending" card with horizontal progress bars
///     for each budget category showing spent vs budget limit.
///
/// Called by:
///   - budgets_screen.dart
/// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:bfm_app/services/dashboard_service.dart';
import 'package:bfm_app/widgets/help_icon_tooltip.dart';

const Color _bfmBlue = Color(0xFF005494);
const Color _bfmOrange = Color(0xFFFF6934);
const Color _redOverspent = Color(0xFFE53935);

/// Card showing budget tracking progress bars.
class BudgetTrackingCard extends StatelessWidget {
  final List<BudgetTrackingItem> items;

  const BudgetTrackingCard({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
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
                'Track your spending',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              HelpIconTooltip(
                title: 'Budget Tracking',
                message: 'See how your spending compares to your budget limits this week.\n\n'
                    '🟢 Green: On track\n'
                    '🟠 Orange: Approaching limit (80%+)\n'
                    '🔴 Red: Over budget\n\n'
                    'Tap on your budgets below to adjust limits.',
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < items.length; i++) ...[
            _BudgetTrackingBar(item: items[i]),
            if (i < items.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _BudgetTrackingBar extends StatelessWidget {
  final BudgetTrackingItem item;

  const _BudgetTrackingBar({required this.item});

  Color _getBarColor() {
    if (item.isOverBudget) {
      return _redOverspent;
    } else if (item.percentage >= 0.8) {
      return _bfmOrange;
    } else {
      return const Color(0xFF4CAF50); // Green
    }
  }

  @override
  Widget build(BuildContext context) {
    final barColor = _getBarColor();
    final isOver = item.isOverBudget;
    // Clamp percentage to 0-1 range for display
    final displayPercentage = item.percentage.clamp(0.0, 1.0);

    return Row(
      children: [
        Text(item.emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Text(
            item.label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
              ),
              child: Stack(
                children: [
                  // Progress bar
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: displayPercentage,
                      child: Container(
                        decoration: BoxDecoration(
                          color: barColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${item.spent.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOver ? _redOverspent : Colors.black87,
                ),
              ),
              Text(
                'of \$${item.budgetLimit.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
