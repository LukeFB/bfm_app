import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Buxly Design System
// ---------------------------------------------------------------------------

class BuxlyColors {
  BuxlyColors._();

  // Primary
  static const Color teal = Color(0xFF72CBCB);
  static const Color skyBlue = Color(0xFF88D4E4);

  // Accents
  static const Color sunshineYellow = Color(0xFFFED705);
  static const Color limeGreen = Color(0xFFC8DB3E);
  static const Color coralOrange = Color(0xFFF36B3B);
  static const Color hotPink = Color(0xFFE22B78);

  // Soft / Backgrounds
  static const Color blushPink = Color(0xFFF3CDE1);
  static const Color offWhite = Color(0xFFF2F2F3);

  // Text & Neutral
  static const Color darkText = Color(0xFF1A1A2E);
  static const Color midGrey = Color(0xFF8A8A9A);
  static const Color disabled = Color(0xFFD0D0D8);
  static const Color white = Color(0xFFFFFFFF);

  // Tinted backgrounds (10-15% opacity variants)
  static Color tealLight = teal.withOpacity(0.12);
  static Color yellowLight = sunshineYellow.withOpacity(0.15);
  static Color greenLight = limeGreen.withOpacity(0.15);
  static Color orangeLight = coralOrange.withOpacity(0.12);
  static Color pinkLight = hotPink.withOpacity(0.10);
  static Color blueLight = skyBlue.withOpacity(0.12);

  // Hero card gradient
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5BBFBF), Color(0xFF72CBCB), Color(0xFF88D4E4)],
  );

  // Savings card gradient
  static const LinearGradient savingsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF72CBCB), Color(0xFF88D4E4)],
  );
}

class BuxlySpacing {
  BuxlySpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class BuxlyRadius {
  BuxlyRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 100;
}

class BuxlyTheme {
  BuxlyTheme._();

  static const String fontFamily = 'Nunito';

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: Brightness.light,
      scaffoldBackgroundColor: BuxlyColors.offWhite,
      primaryColor: BuxlyColors.teal,

      colorScheme: const ColorScheme.light(
        primary: BuxlyColors.teal,
        onPrimary: BuxlyColors.white,
        secondary: BuxlyColors.skyBlue,
        onSecondary: BuxlyColors.darkText,
        tertiary: BuxlyColors.sunshineYellow,
        error: BuxlyColors.hotPink,
        onError: BuxlyColors.white,
        surface: BuxlyColors.white,
        onSurface: BuxlyColors.darkText,
        outline: BuxlyColors.disabled,
        outlineVariant: BuxlyColors.offWhite,
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: BuxlyColors.offWhite,
        foregroundColor: BuxlyColors.darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: BuxlyColors.darkText,
        ),
      ),

      // Text theme
      textTheme: _textTheme,

      // Buttons
      filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButtonStyle),
      textButtonTheme: TextButtonThemeData(style: ghostButtonStyle),

      // Input
      inputDecorationTheme: _inputDecoration,

      // Cards
      cardTheme: CardThemeData(
        color: BuxlyColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BuxlyRadius.lg),
        ),
        margin: EdgeInsets.zero,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: BuxlyColors.white,
        selectedColor: BuxlyColors.teal,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: BuxlyColors.darkText,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: BuxlyColors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BuxlyRadius.pill),
          side: const BorderSide(color: BuxlyColors.disabled),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // Bottom nav (not used directly, but sets defaults)
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: BuxlyColors.white,
        selectedItemColor: BuxlyColors.teal,
        unselectedItemColor: BuxlyColors.midGrey,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 8,
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BuxlyRadius.xl),
        ),
        backgroundColor: BuxlyColors.white,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BuxlyColors.darkText,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: BuxlyColors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BuxlyRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: BuxlyColors.offWhite,
        thickness: 1,
        space: 1,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BuxlyColors.white;
          }
          return BuxlyColors.midGrey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BuxlyColors.teal;
          }
          return BuxlyColors.disabled;
        }),
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BuxlyColors.teal,
        linearTrackColor: BuxlyColors.offWhite,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Text Theme
  // ---------------------------------------------------------------------------

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 48,
      fontWeight: FontWeight.w800,
      color: BuxlyColors.darkText,
      letterSpacing: -1,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 36,
      fontWeight: FontWeight.w800,
      color: BuxlyColors.darkText,
      letterSpacing: -0.5,
    ),
    displaySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: BuxlyColors.darkText,
    ),
    headlineLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: BuxlyColors.darkText,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: BuxlyColors.darkText,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: BuxlyColors.darkText,
    ),
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: BuxlyColors.darkText,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: BuxlyColors.darkText,
    ),
    titleSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: BuxlyColors.darkText,
    ),
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: BuxlyColors.darkText,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: BuxlyColors.darkText,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: BuxlyColors.midGrey,
    ),
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: BuxlyColors.white,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: BuxlyColors.darkText,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: BuxlyColors.darkText,
    ),
  );

  // ---------------------------------------------------------------------------
  // Button Styles
  // ---------------------------------------------------------------------------

  /// Primary teal filled button with pill shape.
  static ButtonStyle get primaryButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BuxlyColors.disabled;
          }
          return BuxlyColors.teal;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BuxlyColors.midGrey;
          }
          return BuxlyColors.white;
        }),
        textStyle: WidgetStateProperty.all(const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        )),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BuxlyRadius.pill),
          ),
        ),
        elevation: WidgetStateProperty.all(0),
      );

  /// Secondary outlined button.
  static ButtonStyle get secondaryButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.all(BuxlyColors.white),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BuxlyColors.midGrey;
          }
          return BuxlyColors.teal;
        }),
        textStyle: WidgetStateProperty.all(const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        )),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BuxlyRadius.pill),
            side: const BorderSide(color: BuxlyColors.teal, width: 2),
          ),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const BorderSide(color: BuxlyColors.disabled, width: 2);
          }
          return const BorderSide(color: BuxlyColors.teal, width: 2);
        }),
        elevation: WidgetStateProperty.all(0),
      );

  /// Ghost / text button.
  static ButtonStyle get ghostButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BuxlyColors.midGrey;
          }
          return BuxlyColors.teal;
        }),
        textStyle: WidgetStateProperty.all(const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        )),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BuxlyRadius.pill),
          ),
        ),
        elevation: WidgetStateProperty.all(0),
      );

  /// Destructive button (coral orange).
  static ButtonStyle get destructiveButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BuxlyColors.disabled;
          }
          return BuxlyColors.coralOrange;
        }),
        foregroundColor: WidgetStateProperty.all(BuxlyColors.white),
        textStyle: WidgetStateProperty.all(const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        )),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BuxlyRadius.pill),
          ),
        ),
        elevation: WidgetStateProperty.all(0),
      );

  /// Quick action button (sunshine yellow).
  static ButtonStyle get quickActionButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BuxlyColors.disabled;
          }
          return BuxlyColors.sunshineYellow;
        }),
        foregroundColor: WidgetStateProperty.all(BuxlyColors.darkText),
        textStyle: WidgetStateProperty.all(const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        )),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BuxlyRadius.pill),
          ),
        ),
        elevation: WidgetStateProperty.all(0),
      );

  // ---------------------------------------------------------------------------
  // Input Decoration
  // ---------------------------------------------------------------------------

  static InputDecorationTheme get _inputDecoration => InputDecorationTheme(
        filled: true,
        fillColor: BuxlyColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          color: BuxlyColors.midGrey,
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: BuxlyColors.darkText,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: BuxlyColors.teal,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BuxlyRadius.md),
          borderSide: const BorderSide(color: BuxlyColors.disabled),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BuxlyRadius.md),
          borderSide: const BorderSide(color: BuxlyColors.disabled),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BuxlyRadius.md),
          borderSide: const BorderSide(color: BuxlyColors.teal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BuxlyRadius.md),
          borderSide: const BorderSide(color: BuxlyColors.hotPink, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BuxlyRadius.md),
          borderSide: const BorderSide(color: BuxlyColors.hotPink, width: 2),
        ),
        errorStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: BuxlyColors.hotPink,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BuxlyRadius.md),
          borderSide: const BorderSide(color: BuxlyColors.offWhite),
        ),
      );

  // ---------------------------------------------------------------------------
  // Card Decorations (for manual use)
  // ---------------------------------------------------------------------------

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: BuxlyColors.white,
        borderRadius: BorderRadius.circular(BuxlyRadius.lg),
        boxShadow: [
          BoxShadow(
            color: BuxlyColors.darkText.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration get heroCardDecoration => BoxDecoration(
        gradient: BuxlyColors.heroGradient,
        borderRadius: BorderRadius.circular(BuxlyRadius.xl),
      );

  static BoxDecoration tintedCardDecoration(Color color) => BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(BuxlyRadius.lg),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
      );

  static BoxDecoration warningCardDecoration() => BoxDecoration(
        color: BuxlyColors.sunshineYellow.withOpacity(0.12),
        borderRadius: BorderRadius.circular(BuxlyRadius.lg),
        border: const Border(
          left: BorderSide(color: BuxlyColors.sunshineYellow, width: 4),
        ),
      );
}

// ---------------------------------------------------------------------------
// Reusable Widget Helpers
// ---------------------------------------------------------------------------

class BuxlyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BoxDecoration? decoration;

  const BuxlyCard({
    super.key,
    required this.child,
    this.padding,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(BuxlySpacing.lg),
      decoration: decoration ?? BuxlyTheme.cardDecoration,
      child: child,
    );
  }
}

class BuxlyHeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const BuxlyHeroCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(BuxlySpacing.xl),
      decoration: BuxlyTheme.heroCardDecoration,
      child: child,
    );
  }
}

class BuxlyTipCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color? iconColor;

  const BuxlyTipCard({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.lightbulb_rounded,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BuxlySpacing.lg),
      decoration: BuxlyTheme.warningCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (iconColor ?? BuxlyColors.coralOrange).withOpacity(0.15),
              borderRadius: BorderRadius.circular(BuxlyRadius.md),
            ),
            child: Icon(
              icon,
              color: iconColor ?? BuxlyColors.coralOrange,
              size: 22,
            ),
          ),
          const SizedBox(width: BuxlySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: BuxlyTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BuxlyColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: BuxlyTheme.fontFamily,
                    fontSize: 13,
                    color: BuxlyColors.midGrey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BuxlyProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? backgroundColor;
  final double height;

  const BuxlyProgressBar({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(BuxlyRadius.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        color: color ?? BuxlyColors.teal,
        backgroundColor: backgroundColor ?? BuxlyColors.offWhite,
      ),
    );
  }
}

class BuxlyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final IconData? icon;

  const BuxlyChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? (color ?? BuxlyColors.teal)
        : BuxlyColors.white;
    final fgColor = selected
        ? BuxlyColors.white
        : BuxlyColors.darkText;
    final borderColor = selected
        ? (color ?? BuxlyColors.teal)
        : BuxlyColors.disabled;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(BuxlyRadius.pill),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fgColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: BuxlyTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon in a tinted circular container (matches iconography spec).
class BuxlyIconContainer extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const BuxlyIconContainer({
    super.key,
    required this.icon,
    this.color = BuxlyColors.teal,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}

/// Detects an emoji for a savings goal based on its name keywords.
String goalEmoji(dynamic goal) {
  final name = (goal.name as String).toLowerCase();
  if (_any(name, ['trip', 'travel', 'holiday', 'vacation', 'flight', 'rarotonga'])) {
    return '✈️';
  }
  if (_any(name, ['car', 'vehicle', 'repair', 'mechanic'])) return '🚗';
  if (_any(name, ['house', 'home', 'bond', 'mortgage', 'rent', 'deposit'])) {
    return '🏠';
  }
  if (_any(name, ['wedding', 'ring', 'engagement'])) return '💍';
  if (_any(name, ['education', 'school', 'uni', 'course', 'study'])) return '🎓';
  if (_any(name, ['phone', 'laptop', 'computer', 'tech', 'device'])) return '💻';
  if (_any(name, ['emergency', 'rainy', 'safety'])) return '🛡️';
  if (_any(name, ['gift', 'present', 'birthday', 'christmas'])) return '🎁';
  if (_any(name, ['health', 'medical', 'doctor', 'dental'])) return '⚕️';
  if (_any(name, ['baby', 'child', 'kid'])) return '👶';
  if (_any(name, ['pet', 'dog', 'cat', 'vet'])) return '🐾';
  if (_any(name, ['furniture', 'appliance'])) return '🛋️';
  return '💰';
}

bool _any(String input, List<String> needles) =>
    needles.any(input.contains);
