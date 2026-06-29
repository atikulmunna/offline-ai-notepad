import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai_notepad/features/notes/data/vector_note_search.dart';
import 'package:offline_ai_notepad/features/notes/domain/note_preview.dart';

NotePreview _preview(String id, {bool isPinned = false}) {
  return NotePreview(
    id: id,
    title: id,
    body: id,
    badge: '',
    updatedAt: DateTime(2026, 1, 1),
    isPinned: isPinned,
  );
}

void main() {
  test('ranks notes by cosine similarity to the query vector', () {
    final query = Float32List.fromList([1.0, 0.0]);
    final vectors = <String, Float32List>{
      'aligned': Float32List.fromList([1.0, 0.0]),
      'partial': Float32List.fromList([0.7071, 0.7071]),
      'orthogonal': Float32List.fromList([0.0, 1.0]),
    };
    final notes = [
      _preview('orthogonal'),
      _preview('partial'),
      _preview('aligned'),
    ];

    final ranked = VectorNoteSearch.cosineRank(
      noteVectors: vectors,
      queryVector: query,
      notes: notes,
    );

    // 'orthogonal' (cosine 0) is below the default floor and dropped.
    expect(ranked.map((note) => note.id), ['aligned', 'partial']);
  });

  test('skips notes without a vector or with a mismatched dimension', () {
    final query = Float32List.fromList([1.0, 0.0, 0.0]);
    final vectors = <String, Float32List>{
      'ok': Float32List.fromList([1.0, 0.0, 0.0]),
      'wrongdim': Float32List.fromList([1.0, 0.0]),
    };
    final notes = [_preview('ok'), _preview('wrongdim'), _preview('novector')];

    final ranked = VectorNoteSearch.cosineRank(
      noteVectors: vectors,
      queryVector: query,
      notes: notes,
    );

    expect(ranked.map((note) => note.id), ['ok']);
  });

  test('tie-breaks equal scores by pinned then recency', () {
    final query = Float32List.fromList([1.0, 0.0]);
    final vectors = <String, Float32List>{
      'plain': Float32List.fromList([1.0, 0.0]),
      'pinned': Float32List.fromList([1.0, 0.0]),
    };
    final notes = [_preview('plain'), _preview('pinned', isPinned: true)];

    final ranked = VectorNoteSearch.cosineRank(
      noteVectors: vectors,
      queryVector: query,
      notes: notes,
    );

    expect(ranked.first.id, 'pinned');
  });
}
