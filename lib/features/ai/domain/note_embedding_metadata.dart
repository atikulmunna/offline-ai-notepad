import 'embedding_status.dart';

class NoteEmbeddingMetadata {
  const NoteEmbeddingMetadata({
    required this.noteId,
    required this.status,
    required this.modelVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  final String noteId;
  final EmbeddingStatus status;
  final String modelVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
}
