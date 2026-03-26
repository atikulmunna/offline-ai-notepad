import '../domain/ai_runtime.dart';
import '../domain/local_model_stage.dart';
import '../domain/local_model_task.dart';
import '../domain/note_embedding_indexer.dart';
import '../domain/note_summarizer.dart';
import '../domain/onnx_runtime_capability.dart';
import 'onnx_method_channel_client.dart';

class OnnxAiRuntime implements AiRuntime {
  const OnnxAiRuntime({
    required NoteSummarizer fallbackSummarizer,
    required NoteEmbeddingIndexer fallbackEmbeddingIndexer,
    required OnnxRuntimeCapability capability,
    required List<LocalModelStage> stages,
    required OnnxMethodChannelClient methodChannelClient,
  })  : _fallbackSummarizer = fallbackSummarizer,
        _fallbackEmbeddingIndexer = fallbackEmbeddingIndexer,
        _capability = capability,
        _stages = stages,
        _methodChannelClient = methodChannelClient;

  final NoteSummarizer _fallbackSummarizer;
  final NoteEmbeddingIndexer _fallbackEmbeddingIndexer;
  final OnnxRuntimeCapability _capability;
  final List<LocalModelStage> _stages;
  final OnnxMethodChannelClient _methodChannelClient;

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
    return 'flan-t5-small-onnx-planned';
  }

  @override
  bool get isLocalOnly => true;

  @override
  Future<AiGenerationResult> processNote({
    required String noteId,
    String? title,
    required String body,
  }) async {
    var summary = await _fallbackSummarizer.summarize(
      title: title,
      body: body,
    );
    final summaryStage = _summaryStage();
    if (_capability.isUsable &&
        summaryStage != null &&
        summaryStage.isStaged &&
        summaryStage.stagedModelPath != null) {
      final contract = summaryStage.installation.spec.onnxContract;
      final nativeSummary = await _methodChannelClient.generateSummary(
        modelPath: summaryStage.stagedModelPath!,
        title: title,
        body: body,
        inputNames: contract?.inputNames ?? const [],
        outputNames: contract?.outputNames ?? const [],
        maxSequenceLength: contract?.maxSequenceLength,
      );
      if (nativeSummary != null && nativeSummary.summary.trim().isNotEmpty) {
        summary = nativeSummary.summary.trim();
      }
    }

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

  LocalModelStage? _summaryStage() {
    for (final stage in _stages) {
      if (stage.installation.spec.task == LocalModelTask.summarization) {
        return stage;
      }
    }
    return null;
  }
}
