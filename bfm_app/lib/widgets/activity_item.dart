/// ---------------------------------------------------------------------------
/// File: lib/widgets/activity_item.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Dashboard recent activity card.
///
/// Purpose:
///   - One-line widget showing transaction label, amount, and day string.
/// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

/// Transaction row used in the dashboard feed.
class ActivityItem extends StatelessWidget {
  final String label;
  final double amount;
  final String date;

  const ActivityItem({
    super.key,
    required this.label,
    required this.amount,
    required this.date,
  });

  /// Renders the label, amount with +/- color, and weekday label.
  @override
  Widget build(BuildContext context) {
    final isNegative = amount < 0;
    // Show "-$186.30" instead of "$-186.30"
    final amountStr = (isNegative ? "-\$" : "\$") + amount.abs().toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          // Constrain the label so it can't push amount/date off-screen
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Amount stays right of the label, never compressed to zero width
          Text(
            amountStr,
            style: TextStyle(
              color: isNegative ? const Color(0xFFFF6934) : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),

          // Let the date take just what it needs (no fixed 32px box)
          Text(
            date,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

