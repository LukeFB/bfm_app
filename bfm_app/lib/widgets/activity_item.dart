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
  final bool excluded;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ActivityItem({
    super.key,
    required this.label,
    required this.amount,
    required this.date,
    this.excluded = false,
    this.onTap,
    this.onLongPress,
  });

  /// Renders the label, amount with +/- color, and weekday label.
  @override
  Widget build(BuildContext context) {
    final isNegative = amount < 0;
    // Show "-$186.30" instead of "$-186.30"
    final amountStr =
        (isNegative ? "-\$" : "\$") + amount.abs().toStringAsFixed(2);

    final labelStyle = TextStyle(
      color: excluded ? Colors.black45 : Colors.black87,
      fontStyle: excluded ? FontStyle.italic : FontStyle.normal,
    );
    final amountColor = excluded
        ? Colors.black38
        : (isNegative ? const Color(0xFFFF6934) : Colors.green);

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (excluded)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                Icons.block,
                size: 16,
                color: Colors.black38,
              ),
            ),
          // Constrain the label so it can't push amount/date off-screen
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          const SizedBox(width: 8),

          // Amount stays right of the label, never compressed to zero width
          Text(
            amountStr,
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),

          // Let the date take just what it needs (no fixed 32px box)
          Text(
            date,
            style: labelStyle.copyWith(
              color: (excluded ? Colors.black38 : Colors.black54),
              fontStyle: labelStyle.fontStyle,
            ),
          ),
        ],
      ),
    );

    if (onTap == null && onLongPress == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        onLongPress: onLongPress,
        child: content,
      ),
    );
  }
}

