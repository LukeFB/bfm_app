/// ---------------------------------------------------------------------------
/// File: lib/widgets/bottom_bar_button.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Dashboard bottom navigation bar.
///
/// Purpose:
///   - Simple icon + label button styled for the dark bottom bar.
/// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

/// Icon + label button used in the dashboard bottom navigation row.
class BottomBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  const BottomBarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  /// Wraps the icon/label in a gesture detector so taps feel snappy.
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
