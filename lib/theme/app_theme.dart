import 'package:flutter/material.dart';

/// Taxi Pay's visual identity.
///
/// Deep teal/green — reads as trustworthy and financial, matches
/// teleBirr's own green without cloning it. Warm amber is the cash
/// accent ([secondary]) so cash visually contrasts teleBirr everywhere
/// (feed icons, dashboard chips) without reaching for the error color.
/// Dark mode is a first-class variant, not an inversion afterthought:
/// drivers use this in direct sunlight and at night.
abstract final class AppTheme {
  static const seed = Color(0xFF006A60); // deep teal

  /// Warm accent for cash-derived UI.
  static const cashAccent = Color(0xFFB58500);

  static ThemeData light() => _base(
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ).copyWith(secondary: cashAccent),
      );

  static ThemeData dark() => _base(
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          secondary: cashAccent, // amber stays warm on dark surfaces too
        ),
      );

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48), // comfortable one-handed taps
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }
}
