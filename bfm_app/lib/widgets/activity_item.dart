/// ---------------------------------------------------------------------------
/// File: activity_item.dart
/// Author: [Your Name]
/// Description:
///   A single row representing one transaction in the "Recent Activity"
///   section of the dashboard.
///
/// Features:
///   - Displays description, amount, and weekday label.
///   - Color-codes amount: red for expenses, green for income.
/// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            "\$${amount.toStringAsFixed(2)}",
            style: TextStyle(
              color: amount < 0 ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(date, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
