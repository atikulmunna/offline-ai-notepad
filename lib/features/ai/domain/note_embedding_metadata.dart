import 'dart:typed_data';

import 'embedding_status.dart';

class NoteEmbeddingMetadata {
  const NoteEmbeddingMetadata({
    required this.noteId,
    required this.status,
    required this.modelVersion,
    required this.createdAt,
    required this.updatedAt,
    this.embedding,
    this.dim,
  });

  final String noteId;
  final EmbeddingStatus status;
  final String modelVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Mean-pooled, L2-normalized sentence embedding. Null when no native vector
  /// was produced (e.g. platforms without the ONNX bridge), in which case
  /// semantic search falls back to lexical ranking.
  final Float32List? embedding;
  final int? dim;
}
