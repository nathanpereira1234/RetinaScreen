import 'package:flutter/material.dart';

/// Design tokens (A05).
///
/// Both people build UI against these — never hardcode a colour, padding, or
/// text size in a screen. The palette targets the field: high contrast for
/// outdoor use, generous touch targets and text for low-literacy, older users
/// on small cheap screens (a Phase 1 non-functional requirement).
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF00695C); // teal 800
  static const Color primaryLight = Color(0xFF439889);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5F7F6);
  static const Color onSurface = Color(0xFF1A1C1B);

  // Referral / result semantics. Chosen for contrast, not decoration.
  static const Color referable = Color(0xFFB3261E); // needs action (red)
  static const Color notReferable = Color(0xFF2E7D32); // reassuring (green)
  static const Color ungradable = Color(0xFFF9A825); // re-screen (amber)
  static const Color pending = Color(0xFFF9A825);
  static const Color reached = Color(0xFF2E7D32);
}

/// 8pt spacing scale. Use `AppSpacing.md`, never a raw `16`.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Minimum touch target — larger than Material's 48 for field use.
  static const double touchTarget = 56;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.surface,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      // Large, legible defaults. Respects the user's OS text-scale on top.
      //
      // Scale sizes null-safely, THEN apply colours. `TextTheme.apply` with a
      // `fontSizeFactor != 1.0` asserts on any style whose `fontSize` is null
      // (some Material styles are), so we can't lean on it for the bump.
      // Applying only colours (factor stays 1.0) is safe on null sizes.
      textTheme: _scaleTextTheme(base.textTheme, 1.05).apply(
        bodyColor: AppColors.onSurface,
        displayColor: AppColors.onSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        centerTitle: false,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: AppSpacing.md,
      ),
    );
  }

  /// Dark theme — same teal identity, tuned for low light / battery on OLED
  /// field phones. Shares the legible text scaling and generous touch targets.
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primaryLight,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
    );

    return base.copyWith(
      textTheme: _scaleTextTheme(base.textTheme, 1.05),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: AppSpacing.md,
      ),
    );
  }

  /// Multiply every text size by [factor], leaving styles with a null
  /// `fontSize` untouched. A null-safe stand-in for
  /// `TextTheme.apply(fontSizeFactor: factor)`, which asserts on null sizes.
  static TextTheme _scaleTextTheme(TextTheme base, double factor) {
    TextStyle? scale(TextStyle? style) => style?.fontSize == null
        ? style
        : style!.copyWith(fontSize: style.fontSize! * factor);

    return TextTheme(
      displayLarge: scale(base.displayLarge),
      displayMedium: scale(base.displayMedium),
      displaySmall: scale(base.displaySmall),
      headlineLarge: scale(base.headlineLarge),
      headlineMedium: scale(base.headlineMedium),
      headlineSmall: scale(base.headlineSmall),
      titleLarge: scale(base.titleLarge),
      titleMedium: scale(base.titleMedium),
      titleSmall: scale(base.titleSmall),
      bodyLarge: scale(base.bodyLarge),
      bodyMedium: scale(base.bodyMedium),
      bodySmall: scale(base.bodySmall),
      labelLarge: scale(base.labelLarge),
      labelMedium: scale(base.labelMedium),
      labelSmall: scale(base.labelSmall),
    );
  }
}
