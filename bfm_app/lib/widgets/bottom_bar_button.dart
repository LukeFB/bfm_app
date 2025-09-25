/// ---------------------------------------------------------------------------
/// File: bottom_bar_button.dart
/// Author: Luke Fraser-Brown
/// Description:
///   A reusable widget for the bottom navigation bar. Provides an
///   icon + label combination that is fully async-aware.
///
/// Why:
///   Using GestureDetector instead of ElevatedButton keeps the look
///   clean and matches the design spec (white icon + label on dark bar).
/// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

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
