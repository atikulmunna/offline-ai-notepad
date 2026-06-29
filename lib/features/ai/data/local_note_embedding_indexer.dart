import '../domain/embedding_status.dart';
import '../domain/note_embedding_indexer.dart';
import '../domain/note_embedding_metadata.dart';

/// Fallback indexer used on platforms without the native ONNX bridge. It does
/// not compute a vector, so it records the note as not indexed and semantic
/// search falls back to lexical ranking ([SemanticNoteSearch]).
class LocalNoteEmbeddingIndexer implements NoteEmbeddingIndexer {
  static const modelVersion = 'lexical-fallback-v1';

  @override
  Future<NoteEmbeddingMetadata> indexNote({
    required String noteId,
    String? title,
    required String body,
  }) async {
    final now = DateTime.now();
    return NoteEmbeddingMetadata(
      noteId: noteId,
      status: EmbeddingStatus.missing,
      modelVersion: modelVersion,
      createdAt: now,
      updatedAt: now,
    );
  }
}
