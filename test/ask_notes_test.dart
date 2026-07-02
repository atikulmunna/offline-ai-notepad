import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai_notepad/features/ai/data/ask_notes_service.dart';
import 'package:offline_ai_notepad/features/ai/domain/grounded_answerer.dart';
import 'package:offline_ai_notepad/features/ai/domain/note_qa.dart';
import 'package:offline_ai_notepad/features/ai/domain/note_qa_context.dart';
import 'package:offline_ai_notepad/features/ai/domain/note_query_embedder.dart';
import 'package:offline_ai_notepad/features/notes/data/vector_note_search.dart';
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

/// Returns a fixed vector for whitelisted note ids, so ranking is deterministic.
class _FakeEmbedder implements NoteQueryEmbedder {
  _FakeEmbedder(this.vector);
  final Float32List? vector;
  @override
  Future<Float32List?> embedQuery(String text) async => vector;
}

class _FakeAnswerer implements GroundedAnswerer {
  _FakeAnswerer(this.reply);
  final String reply;
  String? lastContext;
  @override
  Future<String> answer({
    required String question,
    required String context,
  }) async {
    lastContext = context;
    return reply;
  }
}

void main() {
  group('NoteQaContextBuilder', () {
    test('assembles context and citations, best match first', () {
      const builder = NoteQaContextBuilder();
      final result = builder.build(
        question: 'brakes',
        ranked: [
          (note: _note(id: 'a', title: 'Car', body: 'Fixed the brakes today.'),
              score: 0.9),
          (note: _note(id: 'b', title: 'Trip', body: 'We drove to the coast.'),
              score: 0.4),
        ],
      );

      expect(result.citations, hasLength(2));
      expect(result.citations.first.noteId, 'a');
      expect(result.citations.first.score, 0.9);
      expect(result.context, contains('brakes'));
      expect(result.context, contains('coast'));
    });

    test('honors maxNotes and skips empty bodies', () {
      const builder = NoteQaContextBuilder(maxNotes: 1);
      final result = builder.build(
        question: 'x',
        ranked: [
          (note: _note(id: 'empty', body: '   '), score: 0.9),
          (note: _note(id: 'a', body: 'Real content here.'), score: 0.8),
          (note: _note(id: 'b', body: 'More content.'), score: 0.7),
        ],
      );

      expect(result.citations, hasLength(1));
      expect(result.citations.single.noteId, 'a');
    });

    test('picks the question-relevant sentence for the snippet', () {
      const builder = NoteQaContextBuilder();
      final result = builder.build(
        question: 'lease renewal',
        ranked: [
          (
            note: _note(
              id: 'a',
              body: 'The weather was nice. We agreed to a lease renewal in '
                  'March. Then we had lunch.',
            ),
            score: 0.8,
          ),
        ],
      );

      expect(result.citations.single.snippet, contains('lease renewal'));
    });

    test('truncates long snippets with an ellipsis', () {
      const builder = NoteQaContextBuilder(snippetChars: 20);
      final longBody = 'word ' * 40;
      final result = builder.build(
        question: 'unrelated',
        ranked: [(note: _note(id: 'a', body: longBody), score: 0.5)],
      );

      expect(result.citations.single.snippet.length, lessThanOrEqualTo(21));
      expect(result.citations.single.snippet, endsWith('…'));
    });
  });

  group('VectorNoteSearch.cosineRankScored', () {
    test('ranks by score and drops matches below the floor', () {
      final ranked = VectorNoteSearch.cosineRankScored(
        noteVectors: {
          'a': Float32List.fromList([1, 0, 0]),
          'b': Float32List.fromList([0, 1, 0]),
        },
        queryVector: Float32List.fromList([1, 0, 0]),
        notes: [
          _note(id: 'a', body: 'a'),
          _note(id: 'b', body: 'b'),
        ],
      );

      expect(ranked, hasLength(1));
      expect(ranked.single.note.id, 'a');
      expect(ranked.single.score, closeTo(1.0, 1e-6));
    });
  });

  group('AskNotesService', () {
    test('returns emptyQuestion for blank input', () async {
      final service = AskNotesService(
        queryEmbedder: null,
        answerer: _FakeAnswerer('unused'),
        loadNotes: () async => [_note(id: 'a', body: 'x')],
        loadVectors: () async => const {},
      );

      final result = await service.ask('   ');
      expect(result.outcome, NoteQaOutcome.emptyQuestion);
    });

    test('returns noNotes when the library is empty', () async {
      final service = AskNotesService(
        queryEmbedder: null,
        answerer: _FakeAnswerer('unused'),
        loadNotes: () async => const [],
        loadVectors: () async => const {},
      );

      final result = await service.ask('anything');
      expect(result.outcome, NoteQaOutcome.noNotes);
    });

    test('returns noMatches when nothing is relevant (lexical fallback)',
        () async {
      final service = AskNotesService(
        queryEmbedder: null, // no vector runtime -> lexical ranking
        answerer: _FakeAnswerer('unused'),
        loadNotes: () async => [
          _note(id: 'a', title: 'Groceries', body: 'Milk, eggs, bread.'),
        ],
        loadVectors: () async => const {},
      );

      final result = await service.ask('quantum astrophysics telescopes');
      expect(result.outcome, NoteQaOutcome.noMatches);
    });

    test('answers from vector-ranked notes with citations', () async {
      final answerer = _FakeAnswerer('You decided to renew the lease.');
      final service = AskNotesService(
        queryEmbedder: _FakeEmbedder(Float32List.fromList([1, 0, 0])),
        answerer: answerer,
        loadNotes: () async => [
          _note(id: 'a', title: 'Lease', body: 'Agreed to renew the lease.'),
          _note(id: 'b', title: 'Misc', body: 'Unrelated note.'),
        ],
        loadVectors: () async => {
          'a': Float32List.fromList([1, 0, 0]),
          'b': Float32List.fromList([0, 1, 0]),
        },
      );

      final result = await service.ask('what did I decide about the lease?');

      expect(result.outcome, NoteQaOutcome.answered);
      expect(result.answer, 'You decided to renew the lease.');
      expect(result.citations, hasLength(1));
      expect(result.citations.single.noteId, 'a');
      expect(answerer.lastContext, contains('lease'));
    });

    test('answers via lexical fallback when no embedder is available',
        () async {
      final service = AskNotesService(
        queryEmbedder: null,
        answerer: _FakeAnswerer('Here is what your notes say.'),
        loadNotes: () async => [
          _note(id: 'a', title: 'Brakes', body: 'I fixed the car brakes.'),
        ],
        loadVectors: () async => const {},
      );

      final result = await service.ask('car brakes');

      expect(result.outcome, NoteQaOutcome.answered);
      expect(result.citations.single.noteId, 'a');
      expect(result.citations.single.score, isNull);
    });
  });
}
