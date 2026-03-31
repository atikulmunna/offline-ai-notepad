import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai_notepad/features/security/domain/app_lock_repository.dart';
import 'package:offline_ai_notepad/features/security/domain/app_lock_settings.dart';
import 'package:offline_ai_notepad/features/security/providers/app_lock_providers.dart';

class _FakeAppLockRepository implements AppLockRepository {
  AppLockSettings _settings = const AppLockSettings(
    isEnabled: false,
    pinHash: null,
    saltBase64: null,
  );
  String? _pin;

  @override
  Future<void> clear() async {
    _settings = const AppLockSettings(
      isEnabled: false,
      pinHash: null,
      saltBase64: null,
    );
    _pin = null;
  }

  @override
  Future<AppLockSettings> loadSettings() async => _settings;

  @override
  Future<void> savePin(String pin) async {
    _pin = pin;
    _settings = const AppLockSettings(
      isEnabled: true,
      pinHash: 'stored',
      saltBase64: 'salt',
    );
  }

  @override
  Future<bool> verifyPin(String pin) async => pin == _pin;
}

void main() {
  test('app lock can be enabled and unlocked with the right PIN', () async {
    final controller = AppLockController(_FakeAppLockRepository());
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.isEnabled, isFalse);

    final enabled = await controller.enableWithPin('2468');
    expect(enabled, isTrue);
    expect(controller.state.isEnabled, isTrue);
    expect(controller.state.isLocked, isFalse);

    controller.lockNow();
    expect(controller.state.isLocked, isTrue);

    final unlocked = await controller.unlock('2468');
    expect(unlocked, isTrue);
    expect(controller.state.isLocked, isFalse);
  });

  test('app lock rejects an invalid PIN attempt', () async {
    final controller = AppLockController(_FakeAppLockRepository());
    await Future<void>.delayed(Duration.zero);
    await controller.enableWithPin('1357');
    controller.lockNow();

    final unlocked = await controller.unlock('0000');

    expect(unlocked, isFalse);
    expect(controller.state.isLocked, isTrue);
    expect(controller.state.errorMessage, isNotNull);
  });

  test('app lock can ignore backgrounding during external interactions', () async {
    final controller = AppLockController(_FakeAppLockRepository());
    await Future<void>.delayed(Duration.zero);
    await controller.enableWithPin('2468');

    controller.beginExternalInteraction();
    controller.onBackgrounded();
    expect(controller.state.isLocked, isFalse);

    controller.endExternalInteraction();
    controller.onBackgrounded();
    expect(controller.state.isLocked, isTrue);
  });
}
