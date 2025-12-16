/// ---------------------------------------------------------------------------
/// File: lib/widgets/dashboard_card.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Shared visual shell for dashboard sections so spacing/typography stays
///   consistent.
///
/// Called by:
///   `dashboard_screen.dart` for activity, tips, cards, etc.
///
/// Inputs / Outputs:
///   Takes a title, body widget, and optional trailing action. Emits layout
///   only; caller owns state.
/// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

/// Simple stateless wrapper with consistent padding, rounded corners, and
/// optional trailing actions.
class DashboardCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  /// Creates a dashboard card with a required title/body and optional trailing
  /// widget (buttons, filters, etc.).
  const DashboardCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  /// Renders the card:
  /// - Title row with trailing slot.
  /// - Spacing followed by the provided child content.
  /// - White background with a soft drop shadow.
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
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
