import 'dart:typed_data';

import '../../notes/data/semantic_note_search.dart';
import '../../notes/data/vector_note_search.dart';
import '../../notes/domain/note_preview.dart';
import '../domain/grounded_answerer.dart';
import '../domain/note_qa.dart';
import '../domain/note_qa_context.dart';
import '../domain/note_query_embedder.dart';

/// Answers a natural-language question over the note library: retrieves the most
/// relevant notes, assembles a bounded grounded context, and synthesizes an
/// answer from it, with citations back to the source notes.
///
/// Retrieval prefers native semantic (cosine) similarity when an embedding
/// runtime is available, and falls back to lexical ranking otherwise, so the
/// feature works on every platform, degrading in quality rather than breaking.
class AskNotesService {
  AskNotesService({
    required NoteQueryEmbedder? queryEmbedder,
    required GroundedAnswerer answerer,
    required Future<List<NotePreview>> Function() loadNotes,
    required Future<Map<String, Float32List>> Function() loadVectors,
    NoteQaContextBuilder contextBuilder = const NoteQaContextBuilder(),
    int maxNotes = 5,
  })  : _queryEmbedder = queryEmbedder,
        _answerer = answerer,
        _loadNotes = loadNotes,
        _loadVectors = loadVectors,
        _contextBuilder = contextBuilder,
        _maxNotes = maxNotes;

  final NoteQueryEmbedder? _queryEmbedder;
  final GroundedAnswerer _answerer;
  final Future<List<NotePreview>> Function() _loadNotes;
  final Future<Map<String, Float32List>> Function() _loadVectors;
  final NoteQaContextBuilder _contextBuilder;
  final int _maxNotes;

  Future<NoteQaAnswer> ask(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) {
      return NoteQaAnswer.emptyQuestion(question);
    }

    final notes = await _loadNotes();
    if (notes.isEmpty) {
      return NoteQaAnswer.noNotes(trimmed);
    }

    final ranked = await _rank(trimmed, notes);
    if (ranked.isEmpty) {
      return NoteQaAnswer.noMatches(trimmed);
    }

    final assembled = _contextBuilder.build(question: trimmed, ranked: ranked);
    if (assembled.isEmpty) {
      return NoteQaAnswer.noMatches(trimmed);
    }

    final answer = await _answerer.answer(
      question: trimmed,
      context: assembled.context,
    );
    return NoteQaAnswer.answered(
      question: trimmed,
      answer: answer,
      citations: assembled.citations,
    );
  }

  Future<List<({NotePreview note, double? score})>> _rank(
    String question,
    List<NotePreview> notes,
  ) async {
    final queryVector = await _queryEmbedder?.embedQuery(question);
    if (queryVector != null && queryVector.isNotEmpty) {
      final vectors = await _loadVectors();
      final scored = VectorNoteSearch.cosineRankScored(
        noteVectors: vectors,
        queryVector: queryVector,
        notes: notes,
      );
      if (scored.isNotEmpty) {
        return scored
            .take(_maxNotes)
            .map((entry) => (note: entry.note, score: entry.score as double?))
            .toList(growable: false);
      }
    }

    // No embedding runtime, or nothing cleared the similarity floor: fall back
    // to lexical ranking, which already drops zero-overlap notes.
    final lexical = SemanticNoteSearch.rank(notes: notes, query: question);
    return lexical
        .take(_maxNotes)
        .map((note) => (note: note, score: null))
        .toList(growable: false);
  }
}
