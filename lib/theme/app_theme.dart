import 'package:flutter/material.dart';

/// Taxi Pay's visual identity.
///
/// Ethiopian telebirr identity: vibrant telebirr royal blue as the primary seed,
/// clean white/ice-tinted surfaces, and energetic telebirr green for brand accents
/// and success indicators.
///
/// Warm amber ([cashAccent] / [ColorScheme.secondary]) ensures cash-derived UI
/// visually contrasts telebirr digital payments throughout the entire app without
/// looking like an error state.
///
/// Dark mode is a first-class midnight-slate variant for night driving comfort,
/// maintaining high contrast and brand clarity.
abstract final class AppTheme {
  /// Telebirr Royal Blue seed
  static const seed = Color(0xFF005CB9);

  /// Iconic telebirr brand blue
  static const telebirrBlue = Color(0xFF005CB9);

  /// Telebirr Green brand accent
  static const telebirrGreen = Color(0xFF00A859);

  /// Warm accent for cash-derived UI
  static const cashAccent = Color(0xFFB58500);

  static ThemeData light() => _base(
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          primary: const Color(0xFF005CB9),
          surface: const Color(0xFFFFFFFF),
          surfaceContainerLowest: const Color(0xFFFFFFFF),
          surfaceContainerLow: const Color(0xFFF6F9FD),
          surfaceContainer: const Color(0xFFEEF4FA),
          surfaceContainerHigh: const Color(0xFFE5EEF7),
          surfaceContainerHighest: const Color(0xFFDCE7F3),
          primaryContainer: const Color(0xFFE0EDFB),
          onPrimaryContainer: const Color(0xFF002F65),
          tertiary: telebirrGreen,
          tertiaryContainer: const Color(0xFFD4F4E2),
          onTertiaryContainer: const Color(0xFF00391A),
        ).copyWith(
          secondary: cashAccent,
          secondaryContainer: const Color(0xFFFFF1D6),
          onSecondaryContainer: const Color(0xFF4E3700),
        ),
      );

  static ThemeData dark() => _base(
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          primary: const Color(0xFF7CB8FF),
          surface: const Color(0xFF0F172A),
          surfaceContainerLowest: const Color(0xFF090E1A),
          surfaceContainerLow: const Color(0xFF131D31),
          surfaceContainer: const Color(0xFF1A263D),
          surfaceContainerHigh: const Color(0xFF22304C),
          surfaceContainerHighest: const Color(0xFF2B3C5E),
          primaryContainer: const Color(0xFF00448A),
          onPrimaryContainer: const Color(0xFFD6E4FF),
          tertiary: const Color(0xFF5ADAA2),
          tertiaryContainer: const Color(0xFF00522A),
          onTertiaryContainer: const Color(0xFF86F8BF),
          secondary: cashAccent,
          secondaryContainer: const Color(0xFF4E3700),
          onSecondaryContainer: const Color(0xFFFFDFA0),
        ),
      );

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 0,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        color: scheme.surfaceContainerLow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        dense: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        dragHandleSize: const Size(40, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        backgroundColor: scheme.surface,
        elevation: 4,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        elevation: 6,
        backgroundColor: scheme.surface,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
