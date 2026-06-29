import 'dart:typed_data';

/// Embeds a free-text search query into the same vector space as note
/// embeddings, so semantic search can rank notes by cosine similarity.
/// Returns null when no native embedding runtime is available.
abstract class NoteQueryEmbedder {
  Future<Float32List?> embedQuery(String text);
}
