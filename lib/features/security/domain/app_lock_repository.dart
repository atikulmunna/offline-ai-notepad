import 'app_lock_settings.dart';

abstract class AppLockRepository {
  Future<AppLockSettings> loadSettings();
  Future<void> savePin(String pin);
  Future<bool> verifyPin(String pin);
  Future<void> clear();
}
