import '../domain/ai_runtime.dart';
import '../domain/local_model_stage.dart';
import '../domain/local_model_task.dart';
import '../domain/note_embedding_indexer.dart';
import '../domain/note_summarizer.dart';
import '../domain/onnx_runtime_capability.dart';
import 'onnx_method_channel_client.dart';

class OnnxAiRuntime implements AiRuntime {
  static const _stopwords = <String>{
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'but',
    'by',
    'for',
    'from',
    'in',
    'into',
    'is',
    'it',
    'its',
    'main',
    'note',
    'of',
    'on',
    'or',
    'subject',
    'that',
    'the',
    'their',
    'there',
    'these',
    'this',
    'those',
    'to',
    'was',
    'were',
    'which',
    'with',
  };

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
    final fallbackSummary = await _fallbackSummarizer.summarize(
      title: title,
      body: body,
    );
    var summary = fallbackSummary;
    final summaryStage = _summaryStage();
    if (_capability.isUsable &&
        summaryStage != null &&
        summaryStage.isStaged &&
        summaryStage.stagedModelPath != null) {
      final contract = summaryStage.installation.spec.onnxContract;
      final nativeSummary = await _methodChannelClient.generateSummary(
        modelPath: summaryStage.stagedModelPath!,
        tokenizerPath: summaryStage.stagedTokenizerPath,
        title: title,
        body: body,
        inputNames: contract?.inputNames ?? const [],
        outputNames: contract?.outputNames ?? const [],
        maxSequenceLength: contract?.maxSequenceLength,
        padTokenId: contract?.padTokenId,
        unkTokenId: contract?.unkTokenId,
        bosTokenId: contract?.bosTokenId,
        eosTokenId: contract?.eosTokenId,
      );
      final candidateSummary = nativeSummary?.summary.trim();
      if (_looksUsefulSummary(
        candidateSummary,
        title: title,
        body: body,
        fallbackSummary: fallbackSummary,
      )) {
        summary = candidateSummary!;
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

  bool _looksUsefulSummary(
    String? candidate,
    {
    String? title,
    required String body,
    required String fallbackSummary,
  }) {
    if (candidate == null || candidate.isEmpty) {
      return false;
    }

    final normalizedCandidate = _normalize(candidate);
    if (normalizedCandidate.length < 24) {
      return false;
    }
    if (normalizedCandidate.length > 320) {
      return false;
    }

    final words = normalizedCandidate
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.length < 6) {
      return false;
    }
    if (words.length > 55) {
      return false;
    }

    final normalizedFallback = _normalize(fallbackSummary);
    if (normalizedCandidate == normalizedFallback) {
      return false;
    }

    final normalizedTitle = _normalize(title ?? '');
    if (normalizedTitle.isNotEmpty &&
        (normalizedCandidate == normalizedTitle ||
            normalizedCandidate.startsWith('$normalizedTitle:'))) {
      return false;
    }

    final normalizedBody = _normalize(body);
    if (normalizedBody.isNotEmpty &&
        normalizedBody.startsWith(normalizedCandidate) &&
        normalizedCandidate.length < 80) {
      return false;
    }
    if (_bodyContainsCandidate(
      normalizedBody: normalizedBody,
      normalizedCandidate: normalizedCandidate,
    )) {
      return false;
    }

    if (RegExp(r'^\s*(summary|summarize)\s*:\s*', caseSensitive: false)
        .hasMatch(normalizedCandidate)) {
      return false;
    }
    if (RegExp(
      r'\b(main subject|subject of this note|this note is|the main idea)\b',
      caseSensitive: false,
    ).hasMatch(normalizedCandidate)) {
      return false;
    }
    if (RegExp(r'^(it|this|these|they|there)\b', caseSensitive: false)
        .hasMatch(normalizedCandidate)) {
      return false;
    }
    if (RegExp(r'[:;]\s*$').hasMatch(normalizedCandidate)) {
      return false;
    }

    final punctuationHeavy =
        RegExp(r'^[\p{L}\p{N}\s,&;:/()-]+$', unicode: true).hasMatch(
      normalizedCandidate,
    );
    final sentenceLike = RegExp(r'[.!?]').hasMatch(normalizedCandidate);
    final hasVerbLikeTerm = RegExp(
      r'\b(is|are|was|were|be|been|being|has|have|had|will|would|could|should|can|may|might|do|does|did|announced|said|plans|launched|revealed|showed|found|used|uses|helps|improves|includes)\b',
      caseSensitive: false,
    ).hasMatch(normalizedCandidate);
    final semicolonCount = ';'.allMatches(normalizedCandidate).length;
    if (!sentenceLike && (!hasVerbLikeTerm || punctuationHeavy)) {
      return false;
    }
    if (semicolonCount >= 2) {
      return false;
    }
    if (_looksLikeKeywordList(normalizedCandidate)) {
      return false;
    }
    if (!_hasBodyOverlap(
      normalizedCandidate: normalizedCandidate,
      normalizedBody: normalizedBody,
      normalizedTitle: normalizedTitle,
    )) {
      return false;
    }

    return true;
  }

  String _normalize(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _bodyContainsCandidate({
    required String normalizedBody,
    required String normalizedCandidate,
  }) {
    if (normalizedCandidate.length < 96) {
      return false;
    }
    return normalizedBody.contains(normalizedCandidate);
  }

  bool _looksLikeKeywordList(String value) {
    final commaCount = ','.allMatches(value).length;
    final semicolonCount = ';'.allMatches(value).length;
    final sentenceCount = RegExp(r'[.!?]').allMatches(value).length;
    final hasColonLead = value.contains(':') && !RegExp(r'[.!?]').hasMatch(value);
    return (commaCount >= 3 && sentenceCount == 0) ||
        (semicolonCount >= 1 && sentenceCount == 0) ||
        hasColonLead;
  }

  bool _hasBodyOverlap({
    required String normalizedCandidate,
    required String normalizedBody,
    required String normalizedTitle,
  }) {
    final candidateTerms = _keywords(normalizedCandidate);
    final bodyTerms = _keywords(normalizedBody);
    final titleTerms = _keywords(normalizedTitle);
    final overlap = candidateTerms.intersection({...bodyTerms, ...titleTerms});
    return overlap.length >= 2;
  }

  Set<String> _keywords(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((part) => part.length > 2 && !_stopwords.contains(part))
        .toSet();
  }
}
