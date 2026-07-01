/// The three theme choices the user can pick in the appearance settings.
///
/// [system] follows the OS light/dark setting; [light] forces the original
/// "paper" theme; [amoled] forces the true-black theme.
enum AppThemeMode {
  system,
  light,
  amoled;

  /// The value persisted in shared preferences.
  String get storageValue => name;

  /// Parses a persisted value, defaulting to [AppThemeMode.system].
  static AppThemeMode fromStorage(String? value) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AppThemeMode.system,
    );
  }

  /// Human-readable label for the settings UI.
  String get label => switch (this) {
        AppThemeMode.system => 'System',
        AppThemeMode.light => 'Light',
        AppThemeMode.amoled => 'AMOLED',
      };
}
