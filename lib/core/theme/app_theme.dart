import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFF08080C);
  static const Color backgroundAlt = Color(0xFF111116);
  static const Color surface = Color(0xFF17171D);

  static const Color accent = Color(0xFF0A84FF);
  static const Color accentPurple = Color(0xFFBF5AF2);
  static const Color accentPink = Color(0xFFFF375F);
  static const Color accentTeal = Color(0xFF64D2FF);

  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFFA1A1A8);
  static const Color textTertiary = Color(0xFF6E6E76);

  static const List<Color> heroScrim = [
    Color(0x00000000),
    Color(0xCC08080C),
    Color(0xFF08080C),
  ];

  static const LinearGradient glassBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x66FFFFFF),
      Color(0x14FFFFFF),
      Color(0x05FFFFFF),
    ],
    stops: [0.0, 0.5, 1.0],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.surface,
        primary: AppColors.accent,
        secondary: AppColors.accentPurple,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
