import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wantr App Theme - "The Cartographer's Chronicle"
/// An explorer's atlas aesthetic with aged parchment, brass accents,
/// and cartographic visual language.
class WantrTheme {
  // === CORE PALETTE ===
  // Deep maritime navy - the vast unexplored ocean
  static const Color background = Color(0xFF0D1117);
  static const Color backgroundAlt = Color(0xFF161B22);

  // Aged parchment - for cards and overlays
  static const Color parchment = Color(0xFFF5E6D3);
  static const Color parchmentDark = Color(0xFFE8D5BE);
  static const Color parchmentShadow = Color(0xFFD4C4A8);

  // Surface colors
  static const Color surface = Color(0xFF1C2128);
  static const Color surfaceElevated = Color(0xFF242B35);

  // === ACCENT COLORS ===
  // Aged brass - primary accent (warm, golden)
  static const Color brass = Color(0xFFC9A227);
  static const Color brassLight = Color(0xFFDDB94D);
  static const Color brassDark = Color(0xFFA68B1D);

  // Weathered copper - secondary accent
  static const Color copper = Color(0xFFB87333);
  static const Color copperLight = Color(0xFFD4915A);

  // Discovery gold - for revealed streets
  static const Color discovered = Color(0xFFD4AF37);
  static const Color discoveredGlow = Color(0xFFFFD700);

  // Mystery fog - undiscovered areas
  static const Color undiscovered = Color(0xFF3D4556);
  static const Color fogPurple = Color(0xFF6B4C7A);

  // === FUNCTIONAL COLORS ===
  // Text on dark backgrounds
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF9BA4B0);
  static const Color textMuted = Color(0xFF636D7D);

  // Text on parchment (ink colors)
  static const Color inkDark = Color(0xFF2C3E50);
  static const Color inkFaded = Color(0xFF5D6D7E);
  static const Color inkRed = Color(0xFF8B4513);

  // Resource Colors
  static const Color gold = Color(0xFFFFD700);
  static const Color energy = Color(0xFF50C878);  // Emerald
  static const Color materials = Color(0xFFCD853F);  // Peru/tan
  static const Color influence = Color(0xFF9966CC);  // Amethyst

  // Street State Colors
  static const Color streetGray = Color(0xFF3D4556);
  static const Color streetTeamGreen = Color(0xFF50C878);
  static const Color streetYellow = Color(0xFFD4AF37);
  static const Color streetGold = Color(0xFFFFD700);
  static const Color streetLegendary = Color(0xFFFF8C00);
  static const Color streetMastered = Color(0xFFE6BE8A);  // Soft gold

  // Status colors
  static const Color success = Color(0xFF50C878);
  static const Color warning = Color(0xFFE6A23C);
  static const Color error = Color(0xFFCD5C5C);
  static const Color tracking = Color(0xFF50C878);

  // === DECORATIVE ===
  static const Color ornamentGold = Color(0xFFBFA24D);
  static const Color borderBrass = Color(0xFF8B7355);
  static const Color shadowDeep = Color(0xFF080B0F);

  // === GRADIENTS ===
  static const LinearGradient brassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brassLight, brass, brassDark],
  );

  static const LinearGradient parchmentGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [parchment, parchmentDark],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceElevated, surface],
  );

  // === BOX DECORATIONS ===
  static BoxDecoration get cardDecoration => BoxDecoration(
    gradient: cardGradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: borderBrass.withOpacity(0.3),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: shadowDeep.withOpacity(0.5),
        blurRadius: 20,
        spreadRadius: 2,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration get parchmentCardDecoration => BoxDecoration(
    gradient: parchmentGradient,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: inkFaded.withOpacity(0.3),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: inkDark.withOpacity(0.15),
        blurRadius: 12,
        spreadRadius: 1,
        offset: const Offset(2, 4),
      ),
    ],
  );

  static BoxDecoration get brassButtonDecoration => BoxDecoration(
    gradient: brassGradient,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: brassLight.withOpacity(0.5),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: brass.withOpacity(0.3),
        blurRadius: 8,
        spreadRadius: 0,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: brass,
        secondary: copper,
        tertiary: discovered,
        surface: surface,
        onPrimary: background,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        error: error,
      ),
      // Distinctive typography using Cormorant for display and Crimson Pro for body
      textTheme: GoogleFonts.crimsonProTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 1.2,
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.8,
          ),
          headlineLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.5,
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
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: textSecondary,
            height: 1.4,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 1.0,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textMuted,
            letterSpacing: 1.5,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cormorant(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: brass,
          letterSpacing: 2.0,
        ),
        iconTheme: const IconThemeData(color: brass),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderBrass.withOpacity(0.2)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brass,
          foregroundColor: background,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 4,
          shadowColor: brass.withOpacity(0.4),
          textStyle: GoogleFonts.crimsonPro(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brass,
          side: const BorderSide(color: brass, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.crimsonPro(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brass,
        foregroundColor: background,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      iconTheme: const IconThemeData(
        color: textSecondary,
        size: 24,
      ),
      dividerTheme: DividerThemeData(
        color: borderBrass.withOpacity(0.3),
        thickness: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return brass;
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return brass.withOpacity(0.4);
          return undiscovered;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brass,
        linearTrackColor: undiscovered,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: GoogleFonts.crimsonPro(
          color: textPrimary,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderBrass.withOpacity(0.3)),
        ),
        titleTextStyle: GoogleFonts.cormorant(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: brass,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderBrass.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderBrass.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: brass, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textSecondary),
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
  Color get brass => WantrTheme.brass;
  Color get copper => WantrTheme.copper;
  Color get gold => WantrTheme.gold;
  Color get energy => WantrTheme.energy;
  Color get parchment => WantrTheme.parchment;
}

/// Custom painters and decorations for cartographic elements
class CartographicDecorations {
  /// Creates a compass rose decoration
  static Widget compassRose({double size = 48, Color? color}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CompassRosePainter(color: color ?? WantrTheme.brass),
    );
  }

  /// Creates decorative corner ornaments
  static Widget cornerOrnament({
    required CornerPosition position,
    double size = 24,
    Color? color,
  }) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CornerOrnamentPainter(
        position: position,
        color: color ?? WantrTheme.brass.withOpacity(0.6),
      ),
    );
  }
}

enum CornerPosition { topLeft, topRight, bottomLeft, bottomRight }

class _CompassRosePainter extends CustomPainter {
  final Color color;

  _CompassRosePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Outer circle
    canvas.drawCircle(center, radius, paint);

    // Inner circle
    canvas.drawCircle(center, radius * 0.3, paint);

    // Cardinal directions
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // North pointer
    final northPath = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx - 4, center.dy - radius * 0.3)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx + 4, center.dy - radius * 0.3)
      ..close();
    canvas.drawPath(northPath, fillPaint);

    // South, East, West pointers (stroke only)
    for (var i = 1; i < 4; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * 3.14159 / 2);
      canvas.translate(-center.dx, -center.dy);

      final path = Path()
        ..moveTo(center.dx, center.dy - radius)
        ..lineTo(center.dx - 3, center.dy - radius * 0.4)
        ..lineTo(center.dx + 3, center.dy - radius * 0.4)
        ..close();
      canvas.drawPath(path, paint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerOrnamentPainter extends CustomPainter {
  final CornerPosition position;
  final Color color;

  _CornerOrnamentPainter({required this.position, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path();

    switch (position) {
      case CornerPosition.topLeft:
        path.moveTo(0, size.height * 0.6);
        path.lineTo(0, 0);
        path.lineTo(size.width * 0.6, 0);
        // Decorative curl
        path.moveTo(size.width * 0.15, 0);
        path.quadraticBezierTo(size.width * 0.15, size.height * 0.15, 0, size.height * 0.15);
        break;
      case CornerPosition.topRight:
        path.moveTo(size.width * 0.4, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height * 0.6);
        path.moveTo(size.width * 0.85, 0);
        path.quadraticBezierTo(size.width * 0.85, size.height * 0.15, size.width, size.height * 0.15);
        break;
      case CornerPosition.bottomLeft:
        path.moveTo(0, size.height * 0.4);
        path.lineTo(0, size.height);
        path.lineTo(size.width * 0.6, size.height);
        path.moveTo(size.width * 0.15, size.height);
        path.quadraticBezierTo(size.width * 0.15, size.height * 0.85, 0, size.height * 0.85);
        break;
      case CornerPosition.bottomRight:
        path.moveTo(size.width * 0.4, size.height);
        path.lineTo(size.width, size.height);
        path.lineTo(size.width, size.height * 0.4);
        path.moveTo(size.width * 0.85, size.height);
        path.quadraticBezierTo(size.width * 0.85, size.height * 0.85, size.width, size.height * 0.85);
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
