import '../domain/ai_runtime.dart';
import '../domain/local_model_stage.dart';
import '../domain/note_embedding_indexer.dart';
import '../domain/note_summarizer.dart';
import '../domain/onnx_runtime_capability.dart';

class OnnxAiRuntime implements AiRuntime {
  const OnnxAiRuntime({
    required NoteSummarizer fallbackSummarizer,
    required NoteEmbeddingIndexer fallbackEmbeddingIndexer,
    required OnnxRuntimeCapability capability,
    required List<LocalModelStage> stages,
  })  : _fallbackSummarizer = fallbackSummarizer,
        _fallbackEmbeddingIndexer = fallbackEmbeddingIndexer,
        _capability = capability,
        _stages = stages;

  final NoteSummarizer _fallbackSummarizer;
  final NoteEmbeddingIndexer _fallbackEmbeddingIndexer;
  final OnnxRuntimeCapability _capability;
  final List<LocalModelStage> _stages;

  @override
  String get runtimeLabel {
    if (_capability.isUsable) {
      return 'ONNX local runtime';
    }
    if (_capability.bridgeAvailable) {
      return 'ONNX bridge fallback runtime';
    }
    return 'Fallback local runtime';
  }

  @override
  String get modelVersion {
    final stagedIds = _stages
        .where((stage) => stage.isStaged)
        .map((stage) => stage.installation.spec.id)
        .join('+');
    if (stagedIds.isNotEmpty) {
      return stagedIds;
    }
    return 'onnx-planned-fallback-v1';
  }

  @override
  bool get isLocalOnly => true;

  @override
  Future<AiGenerationResult> processNote({
    required String noteId,
    String? title,
    required String body,
  }) async {
    final summary = await _fallbackSummarizer.summarize(
      title: title,
      body: body,
    );
    final embeddingMetadata = await _fallbackEmbeddingIndexer.indexNote(
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
