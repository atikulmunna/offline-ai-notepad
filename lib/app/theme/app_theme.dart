import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    const bark = Color(0xFF5E503F);
    const sand = Color(0xFFC6AC8F);
    const linen = Color(0xFFEAE0D5);
    const slate = Color(0xFF22333B);
    const coal = Color(0xFF0A0908);
    const mist = Color(0xFFF5EEE6);
    const paper = Color(0xFFFFFBF7);
    const chip = Color(0xFFF1E6D8);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: bark,
      brightness: Brightness.light,
      primary: bark,
      secondary: slate,
      tertiary: sand,
      surface: paper,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: mist,
      fontFamily: 'Merriweather',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: coal,
          height: 1.05,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: coal,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: coal,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: coal,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: coal,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: coal,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: coal,
          letterSpacing: 0.2,
        ),
      ).apply(
        fontFamily: 'Merriweather',
        bodyColor: coal,
        displayColor: coal,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: coal,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Merriweather',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: coal,
        ),
        toolbarTextStyle: TextStyle(
          fontFamily: 'Merriweather',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: coal,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: bark,
          foregroundColor: linen,
          textStyle: const TextStyle(
            fontFamily: 'Merriweather',
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: bark,
          textStyle: const TextStyle(
            fontFamily: 'Merriweather',
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return linen;
            }
            return coal;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return bark;
            }
            return chip;
          }),
          side: const WidgetStatePropertyAll(
            BorderSide(color: sand),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Merriweather',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: sand,
        side: const BorderSide(color: sand),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Merriweather',
          color: coal,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: sand),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: sand),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: sand),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: bark, width: 1.5),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Merriweather',
          color: slate,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: bark,
        foregroundColor: linen,
        elevation: 8,
        extendedTextStyle: TextStyle(
          fontFamily: 'Merriweather',
          fontWeight: FontWeight.w700,
          color: linen,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: sand),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: bark,
        selectionColor: Color(0x665E503F),
        selectionHandleColor: bark,
      ),
      dividerColor: sand,
      splashFactory: InkSparkle.splashFactory,
      extensions: const [
        _AppColors(
          accent: bark,
          coral: sand,
          sky: linen,
          cream: mist,
          ink: coal,
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
