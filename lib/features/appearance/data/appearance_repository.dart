import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_background.dart';
import '../domain/app_theme_mode.dart';

/// Persists the user's appearance choices (theme mode + animated background)
/// via [SharedPreferencesAsync], mirroring the app-lock repository pattern.
class AppearanceRepository {
  AppearanceRepository(this._preferences);

  final SharedPreferencesAsync _preferences;

  static const _themeModeKey = 'appearance.theme_mode';
  static const _backgroundKey = 'appearance.background';

  Future<AppThemeMode> loadThemeMode() async {
    return AppThemeMode.fromStorage(await _preferences.getString(_themeModeKey));
  }

  Future<AppBackground> loadBackground() async {
    return AppBackground.fromStorage(
      await _preferences.getString(_backgroundKey),
    );
  }

  Future<void> saveThemeMode(AppThemeMode mode) async {
    await _preferences.setString(_themeModeKey, mode.storageValue);
  }

  Future<void> saveBackground(AppBackground background) async {
    await _preferences.setString(_backgroundKey, background.storageValue);
  }
}
