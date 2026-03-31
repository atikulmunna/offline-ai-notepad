import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    const accent = Color(0xFF7C4DFF);
    const orchid = Color(0xFFB388FF);
    const lilac = Color(0xFFE3D7FF);
    const blush = Color(0xFFF5ECFF);
    const mist = Color(0xFFF7F3FF);
    const ink = Color(0xFF231A33);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      primary: accent,
      secondary: orchid,
      surface: Colors.white,
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
      ).apply(
        fontFamily: 'Merriweather',
        bodyColor: ink,
        displayColor: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Merriweather',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        toolbarTextStyle: TextStyle(
          fontFamily: 'Merriweather',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
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
          foregroundColor: accent,
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
              return Colors.white;
            }
            return ink;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accent;
            }
            return const Color(0xFFF8F3FF);
          }),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Color(0xFFDCD0F4)),
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
        selectedColor: accent,
        side: const BorderSide(color: Color(0xFFDCCEF7)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Merriweather',
          color: ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFFDDD1F4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFEFCFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFDCD0F4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFDCD0F4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Merriweather',
          color: Color(0xFF665A7B),
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 8,
        extendedTextStyle: TextStyle(
          fontFamily: 'Merriweather',
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFFFEFCFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFDCD0F4)),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: Color(0x667C4DFF),
        selectionHandleColor: accent,
      ),
      dividerColor: const Color(0xFFDCD0F4),
      splashFactory: InkSparkle.splashFactory,
      extensions: const [
        _AppColors(
          accent: accent,
          coral: orchid,
          sky: lilac,
          cream: blush,
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
