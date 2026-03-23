import '../domain/ai_runtime.dart';
import '../domain/note_embedding_indexer.dart';
import '../domain/note_summarizer.dart';

class HeuristicAiRuntime implements AiRuntime {
  const HeuristicAiRuntime({
    required NoteSummarizer summarizer,
    required NoteEmbeddingIndexer embeddingIndexer,
  })  : _summarizer = summarizer,
        _embeddingIndexer = embeddingIndexer;

  final NoteSummarizer _summarizer;
  final NoteEmbeddingIndexer _embeddingIndexer;

  @override
  String get runtimeLabel => 'Heuristic local runtime';

  @override
  String get modelVersion => 'placeholder-stack-v1';

  @override
  bool get isLocalOnly => true;

  @override
  Future<AiGenerationResult> processNote({
    required String noteId,
    String? title,
    required String body,
  }) async {
    final summary = await _summarizer.summarize(
      title: title,
      body: body,
    );
    final embeddingMetadata = await _embeddingIndexer.indexNote(
      noteId: noteId,
      title: title,
      body: body,
    );
    return AiGenerationResult(
      summary: summary,
      embeddingMetadata: embeddingMetadata,
    );
  }
}
