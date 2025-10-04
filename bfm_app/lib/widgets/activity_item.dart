/// ---------------------------------------------------------------------------
/// File: activity_item.dart
/// Author: Luke Fraser-Brown
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
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                "\$${amount.toStringAsFixed(2)}",
                style: TextStyle(
                  color: amount < 0 ? const Color(0xFFFF6934) : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 32), // Add spacing between amount and date
                    SizedBox(
            width: 32, // Adjust width as needed for your date format
            child: Text(
              date,
              textAlign: TextAlign.left,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
