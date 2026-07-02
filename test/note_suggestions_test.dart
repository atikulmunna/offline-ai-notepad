import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai_notepad/features/ai/data/note_assistant.dart';
import 'package:offline_ai_notepad/features/ai/domain/folder_suggester.dart';
import 'package:offline_ai_notepad/features/ai/domain/note_query_embedder.dart';
import 'package:offline_ai_notepad/features/ai/domain/note_title_suggester.dart';
import 'package:offline_ai_notepad/features/notes/domain/note_preview.dart';

NotePreview _note({
  required String id,
  String title = '',
  required String body,
  String? folderId,
  String? folderName,
}) {
  return NotePreview(
    id: id,
    title: title,
    body: body,
    badge: '',
    updatedAt: DateTime(2026, 1, 1),
    folderId: folderId,
    folderName: folderName,
  );
}

class _FakeEmbedder implements NoteQueryEmbedder {
  _FakeEmbedder(this.vector);
  final Float32List? vector;
  @override
  Future<Float32List?> embedQuery(String text) async => vector;
}

void main() {
  group('NoteTitleSuggester', () {
    const suggester = NoteTitleSuggester();

    test('abstains on very short bodies', () {
      expect(suggester.suggest('hi'), isNull);
      expect(suggester.suggest('   '), isNull);
    });

    test('uses the first line as the title', () {
      final title = suggester.suggest('Weekly team sync\nRest of the note.');
      expect(title, 'Weekly team sync');
    });

    test('cuts a long paragraph at the first sentence', () {
      final title = suggester.suggest(
        'We agreed to renew the lease in March. Then we discussed the budget '
        'and other items at length.',
      );
      expect(title, 'We agreed to renew the lease in March');
    });

    test('strips leading list and markdown markers', () {
      expect(suggester.suggest('# Project ideas for the quarter'),
          'Project ideas for the quarter');
      expect(suggester.suggest('- buy groceries and cook dinner'),
          'buy groceries and cook dinner');
    });

    test('truncates over-long single-line titles at a word boundary', () {
      const short = NoteTitleSuggester(maxLength: 20);
      final title = short.suggest('Supercalifragilistic planning session notes');
      expect(title!.length, lessThanOrEqualTo(20));
      expect(title, isNot(endsWith(' ')));
      expect('Supercalifragilistic planning session notes', startsWith(title));
    });
  });

  group('FolderSuggester', () {
    const suggester = FolderSuggester();

    test('abstains with no filed neighbors', () {
      expect(suggester.suggest(const []), isNull);
      expect(
        suggester.suggest(const [(id: null, name: null, weight: 0.9)]),
        isNull,
      );
    });

    test('suggests the similarity-weighted majority folder', () {
      final result = suggester.suggest(const [
        (id: 'work', name: 'Work', weight: 0.8),
        (id: 'work', name: 'Work', weight: 0.6),
        (id: 'home', name: 'Home', weight: 0.2),
      ]);
      expect(result, isNotNull);
      expect(result!.id, 'work');
      expect(result.name, 'Work');
    });

    test('abstains when only one neighbor votes (below minVoters)', () {
      final result = suggester.suggest(const [
        (id: 'work', name: 'Work', weight: 0.9),
        (id: null, name: null, weight: 0.5),
      ]);
      expect(result, isNull);
    });

    test('abstains when the vote is split below the share threshold', () {
      final result = suggester.suggest(const [
        (id: 'work', name: 'Work', weight: 0.5),
        (id: 'home', name: 'Home', weight: 0.5),
        (id: 'ideas', name: 'Ideas', weight: 0.5),
      ]);
      expect(result, isNull);
    });
  });

  group('NoteAssistant', () {
    test('suggests a title for an untitled note and no folder without embedder',
        () async {
      final assistant = NoteAssistant(
        embedder: null,
        loadNotes: () async => const [],
        loadVectors: () async => const {},
      );

      final result = await assistant.suggest(
        noteId: 'n1',
        currentTitle: '',
        body: 'Plan the offsite agenda\nBook the venue and send invites.',
        currentFolderId: null,
      );

      expect(result.title, 'Plan the offsite agenda');
      expect(result.folder, isNull);
    });

    test('does not suggest a title when one already exists', () async {
      final assistant = NoteAssistant(
        embedder: null,
        loadNotes: () async => const [],
        loadVectors: () async => const {},
      );

      final result = await assistant.suggest(
        noteId: 'n1',
        currentTitle: 'My title',
        body: 'Some body text here that is long enough.',
        currentFolderId: null,
      );

      expect(result.title, isNull);
    });

    test('suggests a folder from similar filed neighbors', () async {
      final assistant = NoteAssistant(
        embedder: _FakeEmbedder(Float32List.fromList([1, 0, 0])),
        loadNotes: () async => [
          _note(id: 'self', body: 'current', folderId: null),
          _note(
              id: 'a',
              body: 'x',
              folderId: 'work',
              folderName: 'Work'),
          _note(
              id: 'b',
              body: 'y',
              folderId: 'work',
              folderName: 'Work'),
          _note(
              id: 'c',
              body: 'z',
              folderId: 'home',
              folderName: 'Home'),
        ],
        loadVectors: () async => {
          'a': Float32List.fromList([1, 0, 0]),
          'b': Float32List.fromList([0.9, 0.1, 0]),
          'c': Float32List.fromList([0, 1, 0]),
        },
      );

      final result = await assistant.suggest(
        noteId: 'self',
        currentTitle: 'Titled already',
        body: 'planning the work sprint tasks',
        currentFolderId: null,
      );

      expect(result.folder, isNotNull);
      expect(result.folder!.id, 'work');
      expect(result.folder!.name, 'Work');
    });
  });
}
