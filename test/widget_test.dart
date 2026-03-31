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

import 'package:offline_ai_notepad/app/app.dart';
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

    expect(find.text('NativeNote'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'New note'), findsOneWidget);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'New note'));
    await tester.pumpAndSettle();

    expect(find.text('New note'), findsOneWidget);
    expect(find.text('AI Summary'), findsOneWidget);
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
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
  });
}
