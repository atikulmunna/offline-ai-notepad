// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:offline_ai_notepad/app/app.dart';
import 'package:offline_ai_notepad/features/notes/data/in_memory_notes_repository.dart';
import 'package:offline_ai_notepad/features/notes/providers/notes_providers.dart';

void main() {
  testWidgets('app shell renders the project home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(InMemoryNotesRepository()),
        ],
        child: OfflineAiNotepadApp(),
      ),
    );

    expect(find.text('Offline AI Notepad'), findsWidgets);
    expect(find.text('Private notes with on-device AI'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'New note'), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New note'));
    await tester.pumpAndSettle();

    expect(find.text('New note'), findsOneWidget);
    expect(find.text('Capture a note'), findsOneWidget);
  });
}
