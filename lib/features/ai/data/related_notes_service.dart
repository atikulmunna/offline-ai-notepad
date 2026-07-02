import 'dart:typed_data';

import '../../notes/data/semantic_note_search.dart';
import '../../notes/data/vector_note_search.dart';
import '../../notes/domain/note_preview.dart';

/// Finds notes related to a given note for a "See also" strip. Ranks by cosine
/// similarity between the note's already-stored embedding and other notes'
/// vectors, so it adds no model calls on the reading path. Falls back to lexical
/// ranking over the note's body when no vector is available (e.g. non-Android or
/// not yet indexed), so it works everywhere and degrades in quality rather than
/// breaking.
class RelatedNotesService {
  RelatedNotesService({
    required Future<Float32List?> Function(String noteId) loadNoteVector,
    required Future<Map<String, Float32List>> Function() loadVectors,
    required Future<List<NotePreview>> Function() loadNotes,
    this.limit = 5,
  })  : _loadNoteVector = loadNoteVector,
        _loadVectors = loadVectors,
        _loadNotes = loadNotes;

  final Future<Float32List?> Function(String noteId) _loadNoteVector;
  final Future<Map<String, Float32List>> Function() _loadVectors;
  final Future<List<NotePreview>> Function() _loadNotes;
  final int limit;

  Future<List<NotePreview>> relatedTo({
    required String noteId,
    required String body,
  }) async {
    final notes = await _loadNotes();
    final others =
        notes.where((note) => note.id != noteId).toList(growable: false);
    if (others.isEmpty) {
      return const [];
    }

    final vector = await _loadNoteVector(noteId);
    if (vector != null && vector.isNotEmpty) {
      final vectors = await _loadVectors();
      final ranked = VectorNoteSearch.cosineRankScored(
        noteVectors: vectors,
        queryVector: vector,
        notes: others,
      );
      if (ranked.isNotEmpty) {
        return ranked
            .take(limit)
            .map((entry) => entry.note)
            .toList(growable: false);
      }
    }

    if (body.trim().isEmpty) {
      return const [];
    }
    return SemanticNoteSearch.rank(notes: others, query: body)
        .take(limit)
        .toList(growable: false);
  }
}
