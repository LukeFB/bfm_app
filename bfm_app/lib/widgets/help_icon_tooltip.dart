/// ---------------------------------------------------------------------------
/// File: lib/widgets/help_icon_tooltip.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Reusable help icon that shows an info tooltip on long press.
///   Used throughout the app to explain complex concepts to users.
/// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

/// A small help icon (?) that displays a tooltip with explanatory text
/// when the user long-presses it.
class HelpIconTooltip extends StatelessWidget {
  /// The help text to display in the tooltip.
  final String message;
  
  /// Optional title for the tooltip popup.
  final String? title;
  
  /// Size of the help icon. Defaults to 16.
  final double size;
  
  /// Color of the icon. Defaults to grey.
  final Color? color;

  const HelpIconTooltip({
    super.key,
    required this.message,
    this.title,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Colors.grey.shade500;
    
    return GestureDetector(
      onLongPress: () => _showHelpDialog(context),
      onTap: () => _showHelpDialog(context),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.help_outline,
          size: size,
          color: iconColor,
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: title != null
            ? Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            : null,
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// A row widget that combines a label with a help icon.
/// Useful for section headers that need explanations.
class LabelWithHelp extends StatelessWidget {
  final String label;
  final String helpMessage;
  final String? helpTitle;
  final TextStyle? labelStyle;
  final double iconSize;

  const LabelWithHelp({
    super.key,
    required this.label,
    required this.helpMessage,
    this.helpTitle,
    this.labelStyle,
    this.iconSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(width: 4),
        HelpIconTooltip(
          message: helpMessage,
          title: helpTitle,
          size: iconSize,
        ),
      ],
    );
  }
}
