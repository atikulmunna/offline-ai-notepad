import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import '../features/notes/presentation/home_page.dart';
import '../features/security/providers/app_lock_providers.dart';

class OfflineAiNotepadApp extends ConsumerStatefulWidget {
  const OfflineAiNotepadApp({super.key});

  @override
  ConsumerState<OfflineAiNotepadApp> createState() => _OfflineAiNotepadAppState();
}

class _OfflineAiNotepadAppState extends ConsumerState<OfflineAiNotepadApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      ref.read(appLockControllerProvider.notifier).onBackgrounded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLockState = ref.watch(appLockControllerProvider);
    final home = !appLockState.isReady
        ? const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          )
        : appLockState.isEnabled && appLockState.isLocked
            ? const _AppLockGate()
            : const NotesHomePage();
    return MaterialApp(
      title: 'NativeNote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      home: home,
    );
  }
}

class _AppLockGate extends ConsumerStatefulWidget {
  const _AppLockGate();

  @override
  ConsumerState<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<_AppLockGate> {
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    await ref
        .read(appLockControllerProvider.notifier)
        .unlock(_pinController.text.trim());
    _pinController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(appLockControllerProvider);

    return ColoredBox(
      color: const Color(0xFFF5EEE6),
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFFBF7),
                        Color(0xFFEAE0D5),
                        Color(0xFFF1E7DB),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0xFFC6AC8F)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2A22333B),
                        blurRadius: 28,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF22333B),
                              Color(0xFF5E503F),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3322333B),
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'NativeNote is locked',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF0A0908),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Enter your PIN to get back to your notes.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF22333B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _pinController,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 8,
                        onChanged: (_) {
                          ref.read(appLockControllerProvider.notifier).clearError();
                        },
                        onSubmitted: (_) => _unlock(),
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          hintText: '4 to 8 digits',
                          counterText: '',
                          prefixIcon: const Icon(Icons.password_rounded),
                          errorText: state.errorMessage,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: state.isBusy ? null : _unlock,
                          icon: const Icon(Icons.lock_open_rounded),
                          label: Text(state.isBusy ? 'Checking...' : 'Unlock'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
