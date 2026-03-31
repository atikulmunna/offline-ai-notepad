import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_lock_repository.dart';
import '../domain/app_lock_settings.dart';

class SharedPrefsAppLockRepository implements AppLockRepository {
  SharedPrefsAppLockRepository(this._preferences);

  final SharedPreferencesAsync _preferences;

  static const _enabledKey = 'privacy.app_lock.enabled';
  static const _pinHashKey = 'privacy.app_lock.pin_hash';

  @override
  Future<AppLockSettings> loadSettings() async {
    final isEnabled = await _preferences.getBool(_enabledKey) ?? false;
    final pinHash = await _preferences.getString(_pinHashKey);
    return AppLockSettings(
      isEnabled: isEnabled && pinHash != null && pinHash.isNotEmpty,
      pinHash: pinHash,
    );
  }

  @override
  Future<void> savePin(String pin) async {
    final hashedPin = _hash(pin);
    await _preferences.setString(_pinHashKey, hashedPin);
    await _preferences.setBool(_enabledKey, true);
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _preferences.getString(_pinHashKey);
    if (storedHash == null || storedHash.isEmpty) {
      return false;
    }
    return storedHash == _hash(pin);
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_pinHashKey);
    await _preferences.remove(_enabledKey);
  }

  static String hashForTesting(String pin) => _hash(pin);

  static String _hash(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }
}
