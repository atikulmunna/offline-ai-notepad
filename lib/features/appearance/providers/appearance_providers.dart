import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../security/providers/app_lock_providers.dart'
    show sharedPreferencesProvider;
import '../data/appearance_repository.dart';
import '../domain/app_background.dart';
import '../domain/app_theme_mode.dart';

class AppearanceState {
  const AppearanceState({
    required this.isReady,
    required this.themeMode,
    required this.background,
  });

  const AppearanceState.initial()
      : isReady = false,
        themeMode = AppThemeMode.system,
        background = AppBackground.particles;

  final bool isReady;
  final AppThemeMode themeMode;
  final AppBackground background;

  AppearanceState copyWith({
    bool? isReady,
    AppThemeMode? themeMode,
    AppBackground? background,
  }) {
    return AppearanceState(
      isReady: isReady ?? this.isReady,
      themeMode: themeMode ?? this.themeMode,
      background: background ?? this.background,
    );
  }
}

final appearanceRepositoryProvider = Provider<AppearanceRepository>((ref) {
  return AppearanceRepository(ref.watch(sharedPreferencesProvider));
});

final appearanceControllerProvider =
    StateNotifierProvider<AppearanceController, AppearanceState>((ref) {
  return AppearanceController(ref.watch(appearanceRepositoryProvider));
});

class AppearanceController extends StateNotifier<AppearanceState> {
  AppearanceController(this._repository)
      : super(const AppearanceState.initial()) {
    _load();
  }

  final AppearanceRepository _repository;

  Future<void> _load() async {
    final mode = await _repository.loadThemeMode();
    final background = await _repository.loadBackground();
    state = AppearanceState(
      isReady: true,
      themeMode: mode,
      background: background,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (state.themeMode == mode) {
      return;
    }
    state = state.copyWith(themeMode: mode);
    await _repository.saveThemeMode(mode);
  }

  Future<void> setBackground(AppBackground background) async {
    if (state.background == background) {
      return;
    }
    state = state.copyWith(background: background);
    await _repository.saveBackground(background);
  }
}
