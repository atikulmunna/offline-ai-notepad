import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    const accent = Color(0xFF0B6E4F);
    const coral = Color(0xFFFF7A59);
    const sky = Color(0xFF6CCFF6);
    const cream = Color(0xFFFFF8EE);
    const ink = Color(0xFF182230);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      primary: accent,
      secondary: coral,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: cream,
      textTheme: GoogleFonts.merriweatherTextTheme(const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: ink,
          height: 1.05,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: ink,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: ink,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: 0.2,
        ),
      )),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: accent,
        side: const BorderSide(color: Color(0xFFE8DDC7)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: const TextStyle(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFFE9DCC6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE7DCC8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE7DCC8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF55606F),
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      dividerColor: const Color(0xFFE7DCC8),
      splashFactory: InkSparkle.splashFactory,
      extensions: const [
        _AppColors(
          accent: accent,
          coral: coral,
          sky: sky,
          cream: cream,
          ink: ink,
        ),
      ],
    );
  }
}

class _AppColors extends ThemeExtension<_AppColors> {
  const _AppColors({
    required this.accent,
    required this.coral,
    required this.sky,
    required this.cream,
    required this.ink,
  });

  final Color accent;
  final Color coral;
  final Color sky;
  final Color cream;
  final Color ink;

  @override
  ThemeExtension<_AppColors> copyWith({
    Color? accent,
    Color? coral,
    Color? sky,
    Color? cream,
    Color? ink,
  }) {
    return _AppColors(
      accent: accent ?? this.accent,
      coral: coral ?? this.coral,
      sky: sky ?? this.sky,
      cream: cream ?? this.cream,
      ink: ink ?? this.ink,
    );
  }

  @override
  ThemeExtension<_AppColors> lerp(
    covariant ThemeExtension<_AppColors>? other,
    double t,
  ) {
    if (other is! _AppColors) {
      return this;
    }

    return _AppColors(
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      coral: Color.lerp(coral, other.coral, t) ?? coral,
      sky: Color.lerp(sky, other.sky, t) ?? sky,
      cream: Color.lerp(cream, other.cream, t) ?? cream,
      ink: Color.lerp(ink, other.ink, t) ?? ink,
    );
  }
}
