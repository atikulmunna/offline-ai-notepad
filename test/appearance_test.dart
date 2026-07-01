import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:offline_ai_notepad/features/appearance/data/appearance_repository.dart';
import 'package:offline_ai_notepad/features/appearance/domain/app_background.dart';
import 'package:offline_ai_notepad/features/appearance/domain/app_theme_mode.dart';
import 'package:offline_ai_notepad/features/appearance/providers/appearance_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('AppThemeMode', () {
    test('round-trips through its storage value', () {
      for (final mode in AppThemeMode.values) {
        expect(AppThemeMode.fromStorage(mode.storageValue), mode);
      }
    });

    test('falls back to system for unknown/absent values', () {
      expect(AppThemeMode.fromStorage(null), AppThemeMode.system);
      expect(AppThemeMode.fromStorage('nonsense'), AppThemeMode.system);
    });
  });

  group('AppBackground', () {
    test('round-trips through its storage value', () {
      for (final background in AppBackground.values) {
        expect(AppBackground.fromStorage(background.storageValue), background);
      }
    });

    test('falls back to particles for unknown/absent values', () {
      expect(AppBackground.fromStorage(null), AppBackground.particles);
      expect(AppBackground.fromStorage('nonsense'), AppBackground.particles);
    });

    test('shuffle always resolves to a concrete animated style', () {
      final random = Random(1);
      for (var i = 0; i < 100; i++) {
        final resolved = AppBackground.shuffle.resolveConcrete(random);
        expect(resolved, isNot(AppBackground.shuffle));
        expect(resolved, isNot(AppBackground.none));
        expect(AppBackground.concreteStyles.contains(resolved), isTrue);
      }
    });

    test('non-shuffle values resolve unchanged', () {
      final random = Random(1);
      expect(AppBackground.none.resolveConcrete(random), AppBackground.none);
      expect(AppBackground.space.resolveConcrete(random), AppBackground.space);
    });

    test('isAnimated is false only for none', () {
      expect(AppBackground.none.isAnimated, isFalse);
      for (final background in AppBackground.values) {
        if (background != AppBackground.none) {
          expect(background.isAnimated, isTrue);
        }
      }
    });
  });

  group('AppearanceRepository', () {
    test('defaults, then persists and reloads choices', () async {
      final repository = AppearanceRepository(SharedPreferencesAsync());

      expect(await repository.loadThemeMode(), AppThemeMode.system);
      expect(await repository.loadBackground(), AppBackground.particles);

      await repository.saveThemeMode(AppThemeMode.amoled);
      await repository.saveBackground(AppBackground.space);

      expect(await repository.loadThemeMode(), AppThemeMode.amoled);
      expect(await repository.loadBackground(), AppBackground.space);
    });
  });

  group('AppearanceController', () {
    test('loads persisted state then writes changes through', () async {
      final repository = AppearanceRepository(SharedPreferencesAsync());
      await repository.saveThemeMode(AppThemeMode.light);
      await repository.saveBackground(AppBackground.snow);

      final controller = AppearanceController(repository);
      addTearDown(controller.dispose);

      // Allow the constructor's async _load() to complete.
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.isReady, isTrue);
      expect(controller.state.themeMode, AppThemeMode.light);
      expect(controller.state.background, AppBackground.snow);

      await controller.setThemeMode(AppThemeMode.amoled);
      await controller.setBackground(AppBackground.geometric);

      expect(controller.state.themeMode, AppThemeMode.amoled);
      expect(controller.state.background, AppBackground.geometric);
      expect(await repository.loadThemeMode(), AppThemeMode.amoled);
      expect(await repository.loadBackground(), AppBackground.geometric);
    });
  });
}
