import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _brand = Color(0xFF147D72);
  static const _lightCanvas = Color(0xFFF5F7F6);
  static const _darkCanvas = Color(0xFF111817);

  static ThemeData get light => _buildTheme(
        brightness: Brightness.light,
        canvas: _lightCanvas,
        surface: Colors.white,
        outline: const Color(0xFFE6EBE8),
        foreground: const Color(0xFF17211F),
        muted: const Color(0xFF74817D),
      );

  static ThemeData get dark => _buildTheme(
        brightness: Brightness.dark,
        canvas: _darkCanvas,
        surface: const Color(0xFF1B2422),
        outline: const Color(0xFF2B3835),
        foreground: const Color(0xFFE9F0ED),
        muted: const Color(0xFFA0ADA8),
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color canvas,
    required Color surface,
    required Color outline,
    required Color foreground,
    required Color muted,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: brightness,
      surface: surface,
    );
    final textTheme = Typography.material2021().black.apply(
          bodyColor: foreground,
          displayColor: foreground,
          fontFamilyFallback: const [
            'Noto Sans Arabic',
            'Noto Naskh Arabic',
            'Arial',
          ],
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme.copyWith(
        primary: _brand,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: foreground,
        outline: outline,
        onSurfaceVariant: muted,
        error: const Color(0xFFB54747),
      ),
      scaffoldBackgroundColor: canvas,
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          height: 1.35,
          letterSpacing: 0,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.45,
          letterSpacing: 0,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.45,
          letterSpacing: 0,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.5,
          letterSpacing: 0,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: 15,
          height: 1.65,
          letterSpacing: 0,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          height: 1.6,
          letterSpacing: 0,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.5,
          letterSpacing: 0,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: 12,
          height: 1.5,
          letterSpacing: 0,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          fontSize: 11,
          height: 1.4,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
        toolbarHeight: 72,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? const Color(0xFFF7F9F8)
            : const Color(0xFF202B28),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: muted, fontSize: 14),
        labelStyle: TextStyle(color: muted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFB54747)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFB54747), width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: textTheme.labelMedium?.copyWith(color: foreground),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          side: BorderSide(color: outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
