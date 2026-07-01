import 'package:flutter/material.dart';

/// Shared brand palette. The light theme keeps the original "paper/sand/bark"
/// look; the AMOLED theme reuses the same hues on a true-black canvas.
class _Palette {
  static const bark = Color(0xFF5E503F);
  static const sand = Color(0xFFC6AC8F);
  static const linen = Color(0xFFEAE0D5);
  static const slate = Color(0xFF22333B);
  static const coal = Color(0xFF0A0908);
  static const mist = Color(0xFFF5EEE6);
  static const paper = Color(0xFFFFFBF7);
  static const chip = Color(0xFFF1E6D8);

  // AMOLED-specific tones.
  static const black = Color(0xFF000000);
  static const nearBlack = Color(0xFF0A0A0A);
  static const ashSurface = Color(0xFF141414);
  static const ink = Color(0xFFEDEDED);
  static const inkMuted = Color(0xFFA8A29A);
}

class AppTheme {
  static ThemeData light() {
    const bark = _Palette.bark;
    const sand = _Palette.sand;
    const linen = _Palette.linen;
    const slate = _Palette.slate;
    const coal = _Palette.coal;
    const mist = _Palette.mist;
    const paper = _Palette.paper;
    const chip = _Palette.chip;

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
      textTheme: _textTheme(coal),
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
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: bark,
        selectionColor: Color(0x665E503F),
        selectionHandleColor: bark,
      ),
      dividerColor: sand,
      splashFactory: InkSparkle.splashFactory,
      extensions: [
        AppSurfaces(
          glassFillTop: Colors.white.withValues(alpha: 0.60),
          glassFillBottom: sand.withValues(alpha: 0.26),
          glassBorder: Colors.white.withValues(alpha: 0.55),
          glassHighlight: Colors.white.withValues(alpha: 0.70),
          cardFill: Colors.white.withValues(alpha: 0.55),
          cardBorder: Colors.white.withValues(alpha: 0.65),
          blurSigma: 18,
          mutedText: slate,
          accent: bark,
          onGlass: coal,
        ),
      ],
    );
  }

  static ThemeData amoled() {
    const bark = _Palette.bark;
    const sand = _Palette.sand;
    const coal = _Palette.coal;
    const black = _Palette.black;
    const surface = _Palette.nearBlack;
    const ink = _Palette.ink;
    const inkMuted = _Palette.inkMuted;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: bark,
      brightness: Brightness.dark,
      // On black, the warm mid-brown reads too dark, so the lighter "sand"
      // becomes the accent and dark text sits on top of it.
      primary: sand,
      onPrimary: coal,
      secondary: sand,
      tertiary: sand,
      surface: surface,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: black,
      fontFamily: 'Merriweather',
      textTheme: _textTheme(ink),
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
          backgroundColor: sand,
          foregroundColor: coal,
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
          foregroundColor: sand,
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
              return coal;
            }
            return ink;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return sand;
            }
            return Colors.white.withValues(alpha: 0.06);
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: Colors.white.withValues(alpha: 0.14)),
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
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        selectedColor: sand,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
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
        color: _Palette.ashSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: sand, width: 1.5),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Merriweather',
          color: inkMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: sand,
        foregroundColor: coal,
        elevation: 8,
        extendedTextStyle: TextStyle(
          fontFamily: 'Merriweather',
          fontWeight: FontWeight.w700,
          color: coal,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _Palette.ashSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _Palette.ashSurface,
        surfaceTintColor: Colors.transparent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: sand,
        selectionColor: sand.withValues(alpha: 0.35),
        selectionHandleColor: sand,
      ),
      dividerColor: Colors.white.withValues(alpha: 0.10),
      splashFactory: InkSparkle.splashFactory,
      extensions: [
        AppSurfaces(
          glassFillTop: Colors.white.withValues(alpha: 0.12),
          glassFillBottom: Colors.white.withValues(alpha: 0.04),
          glassBorder: Colors.white.withValues(alpha: 0.16),
          glassHighlight: Colors.white.withValues(alpha: 0.24),
          cardFill: Colors.white.withValues(alpha: 0.07),
          cardBorder: Colors.white.withValues(alpha: 0.13),
          blurSigma: 22,
          mutedText: inkMuted,
          accent: sand,
          onGlass: ink,
        ),
      ],
    );
  }

  static TextTheme _textTheme(Color ink) {
    return TextTheme(
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
    );
  }
}

/// Theme-aware tokens for the liquid-glass surfaces and note cards. Read via
/// `Theme.of(context).extension<AppSurfaces>()!` (a non-null default is always
/// registered by both [AppTheme.light] and [AppTheme.amoled]).
class AppSurfaces extends ThemeExtension<AppSurfaces> {
  const AppSurfaces({
    required this.glassFillTop,
    required this.glassFillBottom,
    required this.glassBorder,
    required this.glassHighlight,
    required this.cardFill,
    required this.cardBorder,
    required this.blurSigma,
    required this.mutedText,
    required this.accent,
    required this.onGlass,
  });

  /// Top/bottom stops of the translucent gradient painted inside glass panels.
  final Color glassFillTop;
  final Color glassFillBottom;

  /// Hairline outline and inner highlight of a glass panel.
  final Color glassBorder;
  final Color glassHighlight;

  /// Fill/border for note-list cards, which use a translucent fill (no live
  /// blur) for performance.
  final Color cardFill;
  final Color cardBorder;

  /// Backdrop blur strength for glass chrome.
  final double blurSigma;

  /// Secondary text color and the primary accent for the current theme.
  final Color mutedText;
  final Color accent;

  /// Foreground (text/icon) color that reads well on top of glass.
  final Color onGlass;

  @override
  AppSurfaces copyWith({
    Color? glassFillTop,
    Color? glassFillBottom,
    Color? glassBorder,
    Color? glassHighlight,
    Color? cardFill,
    Color? cardBorder,
    double? blurSigma,
    Color? mutedText,
    Color? accent,
    Color? onGlass,
  }) {
    return AppSurfaces(
      glassFillTop: glassFillTop ?? this.glassFillTop,
      glassFillBottom: glassFillBottom ?? this.glassFillBottom,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      cardFill: cardFill ?? this.cardFill,
      cardBorder: cardBorder ?? this.cardBorder,
      blurSigma: blurSigma ?? this.blurSigma,
      mutedText: mutedText ?? this.mutedText,
      accent: accent ?? this.accent,
      onGlass: onGlass ?? this.onGlass,
    );
  }

  @override
  AppSurfaces lerp(covariant AppSurfaces? other, double t) {
    if (other == null) {
      return this;
    }
    return AppSurfaces(
      glassFillTop: Color.lerp(glassFillTop, other.glassFillTop, t)!,
      glassFillBottom: Color.lerp(glassFillBottom, other.glassFillBottom, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      cardFill: Color.lerp(cardFill, other.cardFill, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      blurSigma: blurSigma + (other.blurSigma - blurSigma) * t,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onGlass: Color.lerp(onGlass, other.onGlass, t)!,
    );
  }
}
