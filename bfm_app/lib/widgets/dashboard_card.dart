/// ---------------------------------------------------------------------------
/// File: dashboard_card.dart
/// Author: Luke Fraser-Brown
/// Description:
///   A reusable card-style container used throughout the dashboard.
///   Wraps content in consistent padding, rounded corners, and shadow.
/// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final Widget child;

  /// Creates a dashboard card with a section title and content.
  ///
  /// Example usage:
  /// ```
  /// DashboardCard(
  ///   title: "Recent Activity",
  ///   child: Column(children: [...]),
  /// )
  /// ```
  const DashboardCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
