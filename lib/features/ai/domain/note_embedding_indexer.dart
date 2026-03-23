import 'note_embedding_metadata.dart';

abstract class NoteEmbeddingIndexer {
  Future<NoteEmbeddingMetadata> indexNote({
    required String noteId,
    String? title,
    required String body,
  });
}
