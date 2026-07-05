import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/app_theme.dart';

/// Consumer-facing palette for the AURUM user dashboard and KYC flow.
class AurumConsumerTheme {
  static bool _isDarkMode = true;

  static Color get background => _isDarkMode ? const Color(0xFF0B1118) : const Color(0xFFF3F4F6);
  static Color get surface => _isDarkMode ? const Color(0xFF141C27) : const Color(0xFFFFFFFF);
  static Color get surfaceElevated => _isDarkMode ? const Color(0xFF1A2432) : const Color(0xFFF1F5F9);
  static Color get border => _isDarkMode ? const Color(0xFF273244) : const Color(0xFFE5E7EB);
  static Color get textPrimary => _isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get textMuted => _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
  static const Color liveGreen = Color(0xFF1E9E5A);
  static const Color chipGold = Color(0xFF9A7B2F);

  // Light experience = Aura Gold cream + gold palette.
  static const Color lightBackground = Color(0xFFF7F3EA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1EDE3);
  static const Color lightBorder = Color(0xFFEBE5D8);
  static const Color lightTextPrimary = Color(0xFF1A1712);
  static const Color lightTextMuted = Color(0xFF8A8578);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color onSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color muted(BuildContext context) =>
      onSurface(context).withValues(alpha: 0.62);

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color surfaceElevatedOf(BuildContext context) =>
      isDark(context) ? surfaceElevated : lightSurfaceElevated;

  static Color borderOf(BuildContext context) =>
      Theme.of(context).dividerColor;

  static ThemeData resolve(ThemeMode mode, Brightness platformBrightness) {
    final useDark = switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };
    _isDarkMode = useDark;
    return useDark ? darkTheme() : lightTheme();
  }

  static ThemeData darkTheme() => theme();

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppTheme.primaryGold,
        onPrimary: Color(0xFF1A1200),
        surface: lightSurface,
        onSurface: lightTextPrimary,
        outline: lightBorder,
        surfaceContainer: lightSurfaceElevated,
        surfaceContainerHighest: Color(0xFFE2E8F0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      cardColor: lightSurface,
      dividerColor: lightBorder,
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppTheme.primaryGold.withValues(alpha: 0.15),
          selectedForegroundColor: AppTheme.primaryGold,
          foregroundColor: lightTextMuted,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: lightBorder),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTheme.primaryGold;
          }
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTheme.primaryGold.withValues(alpha: 0.3);
          }
          return Colors.grey.shade200;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceElevated,
        hintStyle: const TextStyle(color: lightTextMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primaryGold, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryGold,
          foregroundColor: const Color(0xFF1A1200),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: AppTheme.goldDeep,
        unselectedItemColor: lightTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData theme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: AppTheme.primaryGold,
        onPrimary: const Color(0xFF1A1200),
        surface: surface,
        onSurface: textPrimary,
        outline: border,
        surfaceContainer: surfaceElevated,
        surfaceContainerHighest: const Color(0xFF273244),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      cardColor: surface,
      dividerColor: border,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppTheme.primaryGold.withValues(alpha: 0.15),
          selectedForegroundColor: AppTheme.primaryGold,
          foregroundColor: textMuted,
          backgroundColor: Colors.transparent,
          side: BorderSide(color: border),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTheme.primaryGold;
          }
          return const Color(0xFF94A3B8);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTheme.primaryGold.withValues(alpha: 0.3);
          }
          return const Color(0xFF1A2432);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        hintStyle: TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primaryGold, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryGold,
          foregroundColor: const Color(0xFF1A1200),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: const Color(0xFF60A5FA),
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static BoxDecoration cardDecoration({Color? color}) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border),
    );
  }

  static BoxDecoration cardDecorationOf(BuildContext context, {Color? color}) {
    return BoxDecoration(
      color: color ?? surfaceOf(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderOf(context)),
    );
  }
}
