import 'package:flutter/material.dart';

class AppTheme {
  // Brand Color Palette
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color deepNavy = Color(0xFF0F172A);
  static const Color emerald = Color(0xFF10B981);
  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color amber = Color(0xFFF59E0B);
  static const Color rose = Color(0xFFF43F5E);
  static const Color auraPurple = Color(0xFF7C3AED);
  static const Color profileMuted = Color(0xFF8A8578);

  // ---- Aura Gold cream + gold design tokens (light experience) ----
  /// Warm cream scaffold background.
  static const Color cream = Color(0xFFF7F3EA);
  /// Pure white card surface.
  static const Color creamSurface = Color(0xFFFFFFFF);
  /// Slightly warm elevated surface (input fills, chips).
  static const Color creamElevated = Color(0xFFF1EDE3);
  /// Soft warm hairline border.
  static const Color creamBorder = Color(0xFFEBE5D8);
  /// Near-black ink for headings / primary text.
  static const Color ink = Color(0xFF1A1712);
  /// Warm muted grey for secondary text.
  static const Color inkMuted = Color(0xFF8A8578);
  /// Black CTA button (e.g. "Start SIP").
  static const Color ctaBlack = Color(0xFF17130B);
  /// Gold gradient endpoints for hero cards.
  static const Color goldGradientStart = Color(0xFFDCB94C);
  static const Color goldGradientEnd = Color(0xFFC29327);
  /// Deep gold-brown used for text/icons on gold surfaces.
  static const Color goldDeep = Color(0xFF6B5210);
  /// Muted brown for secondary text on gold surfaces.
  static const Color onGoldMuted = Color(0xFF5A4A1E);
  /// Silver metal card surface + border.
  static const Color silverSurface = Color(0xFFE9E6DF);
  static const Color silverBorder = Color(0xFFD9D4C8);

  static const Color lightBg = cream;
  static const Color profileBg = cream;
  static const Color lightSurf = creamSurface;
  static const Color darkBg = Color(0xFF0B0F19);
  static const Color darkSurf = Color(0xFF1E293B);

  /// Warm gold gradient for hero cards.
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldGradientStart, goldGradientEnd],
  );

  // Soft shadows for cards
  static List<BoxShadow> get premiumShadow {
    return [
      BoxShadow(
        color: const Color(0xFF6B5210).withValues(alpha: 0.06),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: const Color(0xFF1A1712).withValues(alpha: 0.03),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// Softer ambient shadow for standard cards on cream backgrounds.
  static List<BoxShadow> get softShadow {
    return [
      BoxShadow(
        color: const Color(0xFF6B5210).withValues(alpha: 0.05),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// Warm glow shadow used beneath gold hero cards.
  static List<BoxShadow> get goldGlowShadow {
    return [
      BoxShadow(
        color: goldGradientEnd.withValues(alpha: 0.28),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryGold,
        onPrimary: ink,
        secondary: goldDeep,
        onSecondary: Color(0xFFFFFFFF),
        tertiary: emerald,
        onTertiary: Color(0xFFFFFFFF),
        error: rose,
        onError: Color(0xFFFFFFFF),
        surface: creamSurface,
        onSurface: ink,
        surfaceContainer: cream,
        surfaceContainerHighest: creamElevated,
        outline: creamBorder,
        outlineVariant: creamBorder,
      ),
      scaffoldBackgroundColor: cream,
      dividerColor: creamBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      cardColor: creamSurface,
      cardTheme: CardThemeData(
        color: creamSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: creamBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: creamElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: creamBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryGold, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: rose, width: 1),
        ),
        hintStyle: const TextStyle(color: inkMuted),
        labelStyle: const TextStyle(color: inkMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: ink,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ctaBlack,
          foregroundColor: const Color(0xFFFFFFFF),
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldDeep,
          side: const BorderSide(color: creamBorder),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: goldDeep),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: primaryGold,
          selectedForegroundColor: ink,
          foregroundColor: inkMuted,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: creamBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: creamElevated,
        selectedColor: primaryGold,
        side: const BorderSide(color: creamBorder),
        labelStyle: const TextStyle(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(color: ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primaryGold
              : const Color(0xFFBDB6A6),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primaryGold.withValues(alpha: 0.35)
              : creamElevated,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: creamSurface,
        selectedItemColor: goldDeep,
        unselectedItemColor: inkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: creamBorder, space: 1),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryGold,
        onPrimary: Color(0xFF0F172A),
        secondary: sapphireBlue,
        onSecondary: Color(0xFFFFFFFF),
        tertiary: emerald,
        onTertiary: Color(0xFF0F172A),
        error: rose,
        onError: Color(0xFFFFFFFF),
        surface: darkSurf,
        onSurface: Color(0xFFF8FAFC),
        surfaceContainer: darkBg,
      ),
      scaffoldBackgroundColor: darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurf,
        foregroundColor: Color(0xFFF8FAFC),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurf,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: rose, width: 1),
        ),
        hintStyle: const TextStyle(color: Color(0xFF475569)),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: deepNavy,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
