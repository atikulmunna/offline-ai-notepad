import 'dart:math';

/// The animated background painted behind the notes library.
///
/// [none] is a plain black canvas. [shuffle] resolves to one of the concrete
/// animated styles, chosen once per app launch (see [resolveConcrete]).
enum AppBackground {
  none,
  particles,
  snow,
  geometric,
  space,
  shuffle;

  /// The value persisted in shared preferences.
  String get storageValue => name;

  /// Parses a persisted value, defaulting to [AppBackground.particles].
  static AppBackground fromStorage(String? value) {
    return AppBackground.values.firstWhere(
      (bg) => bg.name == value,
      orElse: () => AppBackground.particles,
    );
  }

  /// Human-readable label for the settings UI.
  String get label => switch (this) {
        AppBackground.none => 'None',
        AppBackground.particles => 'Particles',
        AppBackground.snow => 'Snow',
        AppBackground.geometric => 'Geometric',
        AppBackground.space => 'Space',
        AppBackground.shuffle => 'Shuffle',
      };

  /// Whether this value paints an animated layer (everything except [none]).
  bool get isAnimated => this != AppBackground.none;

  /// The concrete animated styles that [shuffle] can pick from.
  static const List<AppBackground> concreteStyles = [
    AppBackground.particles,
    AppBackground.snow,
    AppBackground.geometric,
    AppBackground.space,
  ];

  /// Resolves [shuffle] to a concrete style using [random]. Any already-concrete
  /// value (including [none]) is returned unchanged.
  AppBackground resolveConcrete(Random random) {
    if (this != AppBackground.shuffle) {
      return this;
    }
    return concreteStyles[random.nextInt(concreteStyles.length)];
  }
}
