import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/note_preview.dart';

/// Ranks notes by cosine similarity between their stored embedding vectors and a
/// query embedding. Vectors are produced L2-normalized by the native runtime, so
/// cosine reduces to a dot product; we still divide by norms defensively.
class VectorNoteSearch {
  const VectorNoteSearch._();

  /// Default similarity floor below which notes are considered unrelated and
  /// dropped. Tuned for all-MiniLM-L6-v2 normalized embeddings, where unrelated
  /// text typically scores near 0 and related text 0.3+.
  static const defaultMinSimilarity = 0.15;

  static List<NotePreview> cosineRank({
    required Map<String, Float32List> noteVectors,
    required Float32List queryVector,
    required Iterable<NotePreview> notes,
    double minSimilarity = defaultMinSimilarity,
  }) {
    return cosineRankScored(
      noteVectors: noteVectors,
      queryVector: queryVector,
      notes: notes,
      minSimilarity: minSimilarity,
    ).map((entry) => entry.note).toList(growable: false);
  }

  /// Like [cosineRank] but keeps each note's similarity score, ordered best
  /// first. Used by retrieval-augmented flows (e.g. "Ask your notes") that need
  /// the score to build citations and cut off weak matches.
  static List<({NotePreview note, double score})> cosineRankScored({
    required Map<String, Float32List> noteVectors,
    required Float32List queryVector,
    required Iterable<NotePreview> notes,
    double minSimilarity = defaultMinSimilarity,
  }) {
    final queryNorm = _norm(queryVector);
    if (queryNorm == 0) {
      return const [];
    }

    final ranked = <({NotePreview note, double score})>[];
    for (final note in notes) {
      final vector = noteVectors[note.id];
      if (vector == null || vector.length != queryVector.length) {
        continue;
      }
      final score = _cosine(queryVector, vector, queryNorm);
      if (score >= minSimilarity) {
        ranked.add((note: note, score: score));
      }
    }

    ranked.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return _defaultSort(a.note, b.note);
    });

    return ranked;
  }

  static double _cosine(Float32List query, Float32List value, double queryNorm) {
    var dot = 0.0;
    for (var i = 0; i < query.length; i++) {
      dot += query[i] * value[i];
    }
    final valueNorm = _norm(value);
    if (valueNorm == 0) {
      return 0;
    }
    return dot / (queryNorm * valueNorm);
  }

  static double _norm(Float32List vector) {
    var sum = 0.0;
    for (final value in vector) {
      sum += value * value;
    }
    return sum <= 0 ? 0 : math.sqrt(sum);
  }

  static int _defaultSort(NotePreview a, NotePreview b) {
    final pinCompare = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
    if (pinCompare != 0) {
      return pinCompare;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  }
}
