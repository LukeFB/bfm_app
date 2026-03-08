import 'package:flutter/material.dart';

/// Wraps a child widget so that a horizontal right-swipe from anywhere
/// on the screen pops the current route (like iOS edge-swipe but full-width).
class SwipeBackWrapper extends StatelessWidget {
  final Widget child;
  const SwipeBackWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          Navigator.of(context).maybePop();
        }
      },
      child: child,
    );
  }
}
