import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai_notepad/features/ai/data/note_assistant.dart';
import 'package:offline_ai_notepad/features/ai/domain/folder_suggester.dart';
import 'package:offline_ai_notepad/features/ai/domain/note_query_embedder.dart';
import 'package:offline_ai_notepad/features/ai/domain/note_title_suggester.dart';
import 'package:offline_ai_notepad/features/ai/domain/tag_suggester.dart';
import 'package:offline_ai_notepad/features/notes/domain/note_preview.dart';
import 'package:offline_ai_notepad/features/notes/domain/note_tag.dart';

NotePreview _note({
  required String id,
  String title = '',
  required String body,
  String? folderId,
  String? folderName,
  List<NoteTag> tags = const [],
}) {
  return NotePreview(
    id: id,
    title: title,
    body: body,
    badge: '',
    updatedAt: DateTime(2026, 1, 1),
    folderId: folderId,
    folderName: folderName,
    tags: tags,
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

    test('suggests tags carried by similar neighbors', () async {
      const urgent = NoteTag(id: 't-urgent', name: 'urgent');
      final assistant = NoteAssistant(
        embedder: _FakeEmbedder(Float32List.fromList([1, 0, 0])),
        loadNotes: () async => [
          _note(id: 'self', body: 'current'),
          _note(id: 'a', body: 'x', tags: [urgent]),
          _note(id: 'b', body: 'y', tags: [urgent]),
        ],
        loadVectors: () async => {
          'a': Float32List.fromList([1, 0, 0]),
          'b': Float32List.fromList([0.95, 0.05, 0]),
        },
      );

      final result = await assistant.suggest(
        noteId: 'self',
        currentTitle: 'Titled',
        body: 'a note that is similar to the tagged ones',
        currentFolderId: 'somewhere',
      );

      expect(result.tags.map((t) => t.id), contains('t-urgent'));
    });

    test('does not re-suggest tags already on the note', () async {
      const urgent = NoteTag(id: 't-urgent', name: 'urgent');
      final assistant = NoteAssistant(
        embedder: _FakeEmbedder(Float32List.fromList([1, 0, 0])),
        loadNotes: () async => [
          _note(id: 'a', body: 'x', tags: [urgent]),
          _note(id: 'b', body: 'y', tags: [urgent]),
        ],
        loadVectors: () async => {
          'a': Float32List.fromList([1, 0, 0]),
          'b': Float32List.fromList([0.95, 0.05, 0]),
        },
      );

      final result = await assistant.suggest(
        noteId: 'self',
        currentTitle: 'Titled',
        body: 'similar note',
        currentFolderId: 'somewhere',
        currentTags: const [urgent],
      );

      expect(result.tags, isEmpty);
    });
  });

  group('TagSuggester', () {
    const suggester = TagSuggester();
    const work = NoteTag(id: 'work', name: 'Work');
    const misc = NoteTag(id: 'misc', name: 'Misc');

    test('surfaces tags whose summed weight clears the floor', () {
      final result = suggester.suggest(neighbors: [
        (tags: const [work], weight: 0.5),
        (tags: const [work], weight: 0.4),
        (tags: const [misc], weight: 0.2),
      ]);
      expect(result.map((t) => t.id), ['work']);
    });

    test('excludes tags the note already has', () {
      final result = suggester.suggest(
        neighbors: [
          (tags: const [work], weight: 0.9),
        ],
        exclude: {'work'},
      );
      expect(result, isEmpty);
    });

    test('caps the number of suggestions', () {
      const limited = TagSuggester(maxSuggestions: 1, minWeight: 0.1);
      final result = limited.suggest(neighbors: [
        (tags: const [work], weight: 0.9),
        (tags: const [misc], weight: 0.8),
      ]);
      expect(result, hasLength(1));
      expect(result.first.id, 'work');
    });
  });
}
