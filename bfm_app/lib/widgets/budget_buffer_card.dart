// ---------------------------------------------------------------------------
// File: lib/widgets/budget_buffer_card.dart
// Author: Luke Fraser-Brown
//
// Purpose:
//   Displays per-budget buffer balances, and optionally each budget's
//   weekly contribution. Used on the budgets screen (balances only) and
//   the weekly overview (balances + contributions).
//
// Called by:
//   - `budgets_screen.dart`
//   - `weekly_overview_sheet.dart`
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:bfm_app/theme/buxly_theme.dart';
import 'package:bfm_app/widgets/help_icon_tooltip.dart';

/// A single budget's buffer entry for display.
class BufferEntry {
  final String label;
  final String emoji;
  final double buffered;
  final double? contribution;

  /// Amount that will be drawn from Buxly Buffer because this budget's
  /// buffer couldn't fully cover the overspend. Null when not applicable.
  final double? savingsDrawn;

  const BufferEntry({
    required this.label,
    required this.emoji,
    required this.buffered,
    this.contribution,
    this.savingsDrawn,
  });
}

/// Card showing per-budget buffer amounts and optional weekly contributions.
class BudgetBufferCard extends StatelessWidget {
  final List<BufferEntry> entries;

  const BudgetBufferCard({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BuxlyRadius.lg),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          const Row(
            children: [
              Text('🛡️', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text(
                'Budget Buffer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(width: 4),
              HelpIconTooltip(
                title: 'Budget Buffer',
                message:
                    'Money put aside per budget from your weekly surpluses.\n\n'
                    'Each week, leftover from each budget is added to that '
                    'budget\'s buffer. If you overspend, the buffer absorbs it.\n\n'
                    'Think of it as a safety net — a big payment in one '
                    'category is fine if that budget\'s buffer covers it!',
                size: 16,
              ),
            ],
          ),

          if (entries.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Your buffer will build up as you stay under budget each week.',
              style: TextStyle(
                fontSize: 13,
                color: BuxlyColors.darkText.withValues(alpha: 0.5),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            for (int i = 0; i < entries.length; i++) ...[
              _BufferRow(entry: entries[i]),
              if (i < entries.length - 1) const SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }
}

class _BufferRow extends StatelessWidget {
  final BufferEntry entry;
  const _BufferRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final hasContrib = entry.contribution != null;
    final contrib = entry.contribution ?? 0.0;
    final contribPositive = contrib >= 0;
    final drawn = entry.savingsDrawn ?? 0.0;
    final hasDrawn = drawn > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BuxlyColors.offWhite,
        borderRadius: BorderRadius.circular(BuxlyRadius.sm),
      ),
      child: Row(
        children: [
          Text(entry.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasContrib)
                  Text(
                    '${contribPositive ? '+' : '−'}\$${contrib.abs().toStringAsFixed(0)} this week',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: contribPositive
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                    ),
                  ),
                if (hasDrawn)
                  Text(
                    '−\$${drawn.toStringAsFixed(0)} from Buxly Buffer',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange.shade700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '\$${entry.buffered.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: BuxlyColors.darkText,
            ),
          ),
        ],
      ),
    );
  }
}
