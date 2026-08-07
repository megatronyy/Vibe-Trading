import 'package:flutter/material.dart';

/// Theme built from the React frontend's HSL design tokens
/// (frontend/src/index.css). Primary orange `--primary: 27 90% 52%`,
/// 4-level dark surfaces, semantic colors. Maps directly onto
/// [ColorScheme] + [ThemeData].
///
/// HSL→RGB conversions done once here so the rest of the app just uses
/// [ColorScheme] slots.
class AppTheme {
  AppTheme._();

  // --- Brand / semantic tokens. Primary is exactly HSL(27 90% 52%) = #F37A16. ---
  static const Color primaryLight = Color(0xFFF37A16); // hsl(27 90% 52%)
  static const Color primaryDark = Color(0xFFFB923C); // lighter on dark
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFEAB308);
  static const Color info = Color(0xFF3B82F6);

  // Chart tokens (up/down/volume) — reused by P2 charts.
  static const Color up = Color(0xFF22C55E);
  static const Color down = Color(0xFFEF4444);

  static ThemeData light() {
    final scheme = const ColorScheme.light(
      primary: primaryLight,
      onPrimary: Colors.white,
      secondary: info,
      error: danger,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF0F172A),
    );
    return _base(scheme, brightness: Brightness.light);
  }

  static ThemeData dark() {
    // Dark mode 4-level surfaces: bg-base / surface-1 / surface-2 / surface-3.
    final scheme = const ColorScheme.dark(
      primary: primaryDark,
      onPrimary: Colors.black,
      secondary: info,
      error: danger,
      surface: Color(0xFF0B1120), // surface-1
      onSurface: Color(0xFFE2E8F0),
    );
    return _base(scheme, brightness: Brightness.dark);
  }

  static ThemeData _base(ColorScheme scheme, {required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF070B16) : const Color(0xFFF8FAFC),
      brightness: brightness,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF0B1120) : Colors.white,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF0B1120) : Colors.white,
        indicatorColor: scheme.primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, color: scheme.onSurface),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
