import 'note_embedding_metadata.dart';

class AiGenerationResult {
  const AiGenerationResult({
    required this.summary,
    required this.embeddingMetadata,
  });

  final String summary;
  final NoteEmbeddingMetadata embeddingMetadata;
}

abstract class AiRuntime {
  String get runtimeLabel;
  String get modelVersion;
  bool get isLocalOnly;

  Future<AiGenerationResult> processNote({
    required String noteId,
    String? title,
    required String body,
  });
}
