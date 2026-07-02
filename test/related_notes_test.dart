import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai_notepad/features/ai/data/related_notes_service.dart';
import 'package:offline_ai_notepad/features/notes/domain/note_preview.dart';

NotePreview _note({
  required String id,
  String title = '',
  required String body,
}) {
  return NotePreview(
    id: id,
    title: title,
    body: body,
    badge: '',
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('RelatedNotesService', () {
    test('ranks by cosine to the note vector and excludes self', () async {
      final service = RelatedNotesService(
        loadNoteVector: (id) async => Float32List.fromList([1, 0, 0]),
        loadVectors: () async => {
          'self': Float32List.fromList([1, 0, 0]),
          'a': Float32List.fromList([0.9, 0.1, 0]),
          'b': Float32List.fromList([0, 1, 0]),
        },
        loadNotes: () async => [
          _note(id: 'self', body: 'current'),
          _note(id: 'a', body: 'close'),
          _note(id: 'b', body: 'far'),
        ],
      );

      final related = await service.relatedTo(noteId: 'self', body: 'current');

      expect(related.map((n) => n.id), ['a']); // 'b' is below the floor, self excluded
    });

    test('falls back to lexical ranking when the note has no vector', () async {
      final service = RelatedNotesService(
        loadNoteVector: (id) async => null,
        loadVectors: () async => const {},
        loadNotes: () async => [
          _note(id: 'self', body: 'car brakes and rotors'),
          _note(id: 'a', title: 'Brakes', body: 'fixing the car brakes today'),
          _note(id: 'b', title: 'Recipes', body: 'pasta and tomato sauce'),
        ],
      );

      final related = await service.relatedTo(
        noteId: 'self',
        body: 'car brakes and rotors',
      );

      expect(related.first.id, 'a');
      expect(related.map((n) => n.id), isNot(contains('self')));
    });

    test('returns empty when there are no other notes', () async {
      final service = RelatedNotesService(
        loadNoteVector: (id) async => Float32List.fromList([1, 0, 0]),
        loadVectors: () async => const {},
        loadNotes: () async => [_note(id: 'self', body: 'only note')],
      );

      final related = await service.relatedTo(noteId: 'self', body: 'only note');
      expect(related, isEmpty);
    });

    test('respects the limit', () async {
      final service = RelatedNotesService(
        limit: 2,
        loadNoteVector: (id) async => Float32List.fromList([1, 0, 0]),
        loadVectors: () async => {
          'a': Float32List.fromList([1, 0, 0]),
          'b': Float32List.fromList([0.95, 0.05, 0]),
          'c': Float32List.fromList([0.9, 0.1, 0]),
        },
        loadNotes: () async => [
          _note(id: 'self', body: 'x'),
          _note(id: 'a', body: 'a'),
          _note(id: 'b', body: 'b'),
          _note(id: 'c', body: 'c'),
        ],
      );

      final related = await service.relatedTo(noteId: 'self', body: 'x');
      expect(related, hasLength(2));
    });
  });
}
