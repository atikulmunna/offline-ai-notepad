import '../domain/grounded_answerer.dart';
import '../domain/local_model_stage.dart';
import '../domain/note_summarizer.dart';
import '../domain/onnx_runtime_capability.dart';
import 'onnx_method_channel_client.dart';
import 'summary_quality_gate.dart';

/// Answers a question over retrieved note context by summarizing that context
/// on-device. Prefers the native ONNX summarizer when it is available and its
/// output clears the [SummaryQualityGate]; otherwise returns the extractive
/// summary, so an answer is always produced when context exists.
///
/// This mirrors the native/extractive selection in `OnnxAiRuntime.processNote`,
/// but over an arbitrary grounded context rather than a single note.
class OnnxGroundedAnswerer implements GroundedAnswerer {
  const OnnxGroundedAnswerer({
    required NoteSummarizer fallbackSummarizer,
    required OnnxRuntimeCapability capability,
    required LocalModelStage? summaryStage,
    required OnnxMethodChannelClient methodChannelClient,
  })  : _fallbackSummarizer = fallbackSummarizer,
        _capability = capability,
        _summaryStage = summaryStage,
        _methodChannelClient = methodChannelClient;

  static const _qualityGate = SummaryQualityGate();

  final NoteSummarizer _fallbackSummarizer;
  final OnnxRuntimeCapability _capability;
  final LocalModelStage? _summaryStage;
  final OnnxMethodChannelClient _methodChannelClient;

  @override
  Future<String> answer({
    required String question,
    required String context,
  }) async {
    final extractive = await _fallbackSummarizer.summarize(body: context);

    final stage = _summaryStage;
    if (_capability.isUsable &&
        stage != null &&
        stage.isStaged &&
        stage.stagedModelPath != null) {
      final contract = stage.installation.spec.onnxContract;
      final native = await _methodChannelClient.generateSummary(
        modelPath: stage.stagedModelPath!,
        tokenizerPath: stage.stagedTokenizerPath,
        title: null,
        body: context,
        inputNames: contract?.inputNames ?? const [],
        outputNames: contract?.outputNames ?? const [],
        maxSequenceLength: contract?.maxSequenceLength,
        padTokenId: contract?.padTokenId,
        unkTokenId: contract?.unkTokenId,
        bosTokenId: contract?.bosTokenId,
        eosTokenId: contract?.eosTokenId,
      );
      final candidate = native?.summary.trim();
      if (_qualityGate.isUseful(
        candidate,
        body: context,
        fallbackSummary: extractive,
      )) {
        return candidate!;
      }
    }

    return extractive;
  }
}
