// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:offline_ai_notepad/app/app.dart';
import 'package:offline_ai_notepad/features/appearance/data/appearance_repository.dart';
import 'package:offline_ai_notepad/features/appearance/domain/app_background.dart';
import 'package:offline_ai_notepad/features/notes/data/in_memory_notes_repository.dart';
import 'package:offline_ai_notepad/features/notes/presentation/note_editor_page.dart';
import 'package:offline_ai_notepad/features/notes/providers/notes_providers.dart';
import 'package:offline_ai_notepad/features/security/domain/app_lock_repository.dart';
import 'package:offline_ai_notepad/features/security/domain/app_lock_settings.dart';
import 'package:offline_ai_notepad/features/security/providers/app_lock_providers.dart';

class _TestAppLockRepository implements AppLockRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<AppLockSettings> loadSettings() async {
    return const AppLockSettings(
      isEnabled: false,
      pinHash: null,
      saltBase64: null,
    );
  }

  @override
  Future<void> savePin(String pin) async {}

  @override
  Future<bool> verifyPin(String pin) async => false;
}

void main() {
  setUp(() async {
    // The app reads appearance prefs on startup; back them with an in-memory
    // store and pin the library background to "none" so the decorative,
    // continuously-repeating animation doesn't keep pumpAndSettle from settling.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await AppearanceRepository(SharedPreferencesAsync())
        .saveBackground(AppBackground.none);
  });

  testWidgets('app shell renders the project home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(InMemoryNotesRepository()),
          appLockRepositoryProvider.overrideWithValue(_TestAppLockRepository()),
        ],
        child: OfflineAiNotepadApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FloatingActionButton, 'New note'), findsOneWidget);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'New note'));
    await tester.pumpAndSettle();

    expect(find.text('New note'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);
    expect(find.text('Title'), findsOneWidget);
  });

  testWidgets('existing note opens in edit mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(InMemoryNotesRepository()),
          appLockRepositoryProvider.overrideWithValue(_TestAppLockRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates:
              FlutterQuillLocalizations.localizationsDelegates,
          supportedLocales: FlutterQuillLocalizations.supportedLocales,
          home: NoteEditorPage(noteId: 'research-ideas'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit note'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);
    expect(find.text('Title'), findsOneWidget);
  });
}
