import '../domain/embedding_status.dart';
import '../domain/note_embedding_indexer.dart';
import '../domain/note_embedding_metadata.dart';

class LocalNoteEmbeddingIndexer implements NoteEmbeddingIndexer {
  static const modelVersion = 'placeholder-embed-v1';

  @override
  Future<NoteEmbeddingMetadata> indexNote({
    required String noteId,
    String? title,
    required String body,
  }) async {
    final now = DateTime.now();
    return NoteEmbeddingMetadata(
      noteId: noteId,
      status: EmbeddingStatus.indexed,
      modelVersion: modelVersion,
      createdAt: now,
      updatedAt: now,
    );
  }
}
