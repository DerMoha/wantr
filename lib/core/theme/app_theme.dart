import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wantr App Theme - Minimal & Clean aesthetic
/// Color palette based on the design document
class WantrTheme {
  // Core Colors
  static const Color background = Color(0xFF1A1A2E);
  static const Color surface = Color(0xFF252542);
  static const Color undiscovered = Color(0xFF3D3D5C);
  static const Color discovered = Color(0xFFF4D35E);
  static const Color accent = Color(0xFFEE6C4D);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB0B0C0);

  // Resource Colors
  static const Color gold = Color(0xFFFFD700);
  static const Color energy = Color(0xFF4ECDC4);
  static const Color materials = Color(0xFF8B7355);
  static const Color influence = Color(0xFF9B59B6);

  // Street State Colors
  static const Color streetGray = Color(0xFF3D3D5C);
  static const Color streetYellow = Color(0xFFF4D35E);
  static const Color streetGold = Color(0xFFFFD700);
  static const Color streetLegendary = Color(0xFFFF8C00);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: discovered,
        secondary: accent,
        surface: surface,
        onPrimary: background,
        onSecondary: textPrimary,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
          headlineLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: textPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: textSecondary,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: discovered,
          foregroundColor: background,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: discovered,
          side: const BorderSide(color: discovered, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: textPrimary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: discovered,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      iconTheme: const IconThemeData(
        color: textPrimary,
        size: 24,
      ),
      dividerTheme: const DividerThemeData(
        color: undiscovered,
        thickness: 1,
      ),
    );
  }
}

/// Extension for easy color access
extension WantrColors on BuildContext {
  Color get background => WantrTheme.background;
  Color get surface => WantrTheme.surface;
  Color get discovered => WantrTheme.discovered;
  Color get undiscovered => WantrTheme.undiscovered;
  Color get accent => WantrTheme.accent;
  Color get gold => WantrTheme.gold;
  Color get energy => WantrTheme.energy;
}
