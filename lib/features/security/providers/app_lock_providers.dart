import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/shared_prefs_app_lock_repository.dart';
import '../domain/app_lock_repository.dart';
import '../domain/app_lock_settings.dart';

class AppLockState {
  const AppLockState({
    required this.isReady,
    required this.isEnabled,
    required this.isLocked,
    required this.isBusy,
    this.errorMessage,
  });

  const AppLockState.initial()
      : isReady = false,
        isEnabled = false,
        isLocked = false,
        isBusy = false,
        errorMessage = null;

  final bool isReady;
  final bool isEnabled;
  final bool isLocked;
  final bool isBusy;
  final String? errorMessage;

  AppLockState copyWith({
    bool? isReady,
    bool? isEnabled,
    bool? isLocked,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AppLockState(
      isReady: isReady ?? this.isReady,
      isEnabled: isEnabled ?? this.isEnabled,
      isLocked: isLocked ?? this.isLocked,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferencesAsync>((ref) {
  return SharedPreferencesAsync();
});

final appLockRepositoryProvider = Provider<AppLockRepository>((ref) {
  return SharedPrefsAppLockRepository(ref.watch(sharedPreferencesProvider));
});

final appLockControllerProvider =
    StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController(ref.watch(appLockRepositoryProvider));
});

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController(this._repository) : super(const AppLockState.initial()) {
    _load();
  }

  final AppLockRepository _repository;
  String? _sessionPin;
  AppLockSettings? _settings;

  String? get sessionPin => _sessionPin;
  AppLockSettings? get settings => _settings;

  Future<void> _load() async {
    final settings = await _repository.loadSettings();
    _settings = settings;
    state = AppLockState(
      isReady: true,
      isEnabled: settings.isEnabled,
      isLocked: settings.isEnabled,
      isBusy: false,
    );
  }

  Future<bool> enableWithPin(String pin) async {
    if (!_isValidPin(pin)) {
      state = state.copyWith(
        errorMessage: 'Use a 4 to 8 digit PIN.',
      );
      return false;
    }

    state = state.copyWith(isBusy: true, clearError: true);
    await _repository.savePin(pin);
    _settings = await _repository.loadSettings();
    _sessionPin = pin;
    state = state.copyWith(
      isReady: true,
      isEnabled: true,
      isLocked: false,
      isBusy: false,
      clearError: true,
    );
    return true;
  }

  Future<bool> unlock(String pin) async {
    state = state.copyWith(isBusy: true, clearError: true);
    final isValid = await _repository.verifyPin(pin);
    if (!isValid) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'That PIN does not match.',
      );
      return false;
    }

    _settings = await _repository.loadSettings();
    _sessionPin = pin;
    state = state.copyWith(
      isBusy: false,
      isLocked: false,
      clearError: true,
    );
    return true;
  }

  Future<bool> disable(String pin) async {
    state = state.copyWith(isBusy: true, clearError: true);
    final isValid = await _repository.verifyPin(pin);
    if (!isValid) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'That PIN does not match.',
      );
      return false;
    }

    await _repository.clear();
    _settings = await _repository.loadSettings();
    _sessionPin = null;
    state = state.copyWith(
      isBusy: false,
      isEnabled: false,
      isLocked: false,
      clearError: true,
    );
    return true;
  }

  void lockNow() {
    if (!state.isEnabled) {
      return;
    }
    _sessionPin = null;
    state = state.copyWith(isLocked: true, clearError: true);
  }

  void onBackgrounded() {
    if (!state.isEnabled || state.isLocked) {
      return;
    }
    _sessionPin = null;
    state = state.copyWith(isLocked: true, clearError: true);
  }

  void clearError() {
    if (state.errorMessage == null) {
      return;
    }
    state = state.copyWith(clearError: true);
  }

  static bool _isValidPin(String pin) {
    final normalized = pin.trim();
    return RegExp(r'^\d{4,8}$').hasMatch(normalized);
  }
}
