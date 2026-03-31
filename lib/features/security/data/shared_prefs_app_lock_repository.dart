import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_lock_repository.dart';
import '../domain/app_lock_settings.dart';

class SharedPrefsAppLockRepository implements AppLockRepository {
  SharedPrefsAppLockRepository(this._preferences);

  final SharedPreferencesAsync _preferences;

  static const _enabledKey = 'privacy.app_lock.enabled';
  static const _pinHashKey = 'privacy.app_lock.pin_hash';
  static const _saltKey = 'privacy.app_lock.salt';

  @override
  Future<AppLockSettings> loadSettings() async {
    final isEnabled = await _preferences.getBool(_enabledKey) ?? false;
    final pinHash = await _preferences.getString(_pinHashKey);
    final saltBase64 = await _preferences.getString(_saltKey);
    return AppLockSettings(
      isEnabled: isEnabled &&
          pinHash != null &&
          pinHash.isNotEmpty &&
          saltBase64 != null &&
          saltBase64.isNotEmpty,
      pinHash: pinHash,
      saltBase64: saltBase64,
    );
  }

  @override
  Future<void> savePin(String pin) async {
    final hashedPin = _hash(pin);
    final salt = _randomSalt();
    await _preferences.setString(_pinHashKey, hashedPin);
    await _preferences.setString(_saltKey, base64Encode(salt));
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
    await _preferences.remove(_saltKey);
  }

  static String hashForTesting(String pin) => _hash(pin);

  static String _hash(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  static List<int> _randomSalt() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256));
  }
}
