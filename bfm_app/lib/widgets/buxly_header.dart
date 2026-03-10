import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:bfm_app/theme/buxly_theme.dart';

/// Shared branded header used across the main tabbed screens (Dashboard,
/// Budgets, Savings). Renders the tagline, logo SVG, and a settings gear.
class BuxlyHeader extends StatelessWidget {
  final VoidCallback onSettingsPressed;
  final EdgeInsetsGeometry padding;

  const BuxlyHeader({
    super.key,
    required this.onSettingsPressed,
    this.padding = const EdgeInsets.only(top: 8, bottom: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Health. Mental Wealth.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: BuxlyColors.midGrey,
                    fontFamily: BuxlyTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                SvgPicture.asset(
                  'assets/images/SVG/BUXLY LOGO_Horizontal_Wordmark_Light Turquoise.svg',
                  height: 28,
                  colorFilter: const ColorFilter.mode(
                    BuxlyColors.teal,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(
              Icons.settings_outlined,
              color: BuxlyColors.darkText,
            ),
            onPressed: onSettingsPressed,
          ),
        ],
      ),
    );
  }
}
