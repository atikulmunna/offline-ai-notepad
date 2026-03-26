import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/local_model_asset_stager.dart';
import '../data/local_model_installation_checker.dart';
import '../data/local_model_manifest_loader.dart';
import '../data/local_note_embedding_indexer.dart';
import '../data/local_note_summarizer.dart';
import '../data/note_ai_repository.dart';
import '../data/onnx_ai_runtime.dart';
import '../data/onnx_method_channel_client.dart';
import '../domain/ai_runtime.dart';
import '../domain/ai_runtime_status.dart';
import '../domain/local_model_installation.dart';
import '../domain/local_model_manifest.dart';
import '../domain/local_model_stage.dart';
import '../domain/local_model_task.dart';
import '../domain/note_ai_snapshot.dart';
import '../domain/note_embedding_indexer.dart';
import '../domain/note_summarizer.dart';
import '../domain/onnx_contract_inspection.dart';
import '../domain/onnx_output_interpretation.dart';
import '../domain/onnx_run_preview.dart';
import '../domain/onnx_runtime_capability.dart';
import '../domain/onnx_session_preparation.dart';
import '../domain/onnx_tokenizer_inspection.dart';
import '../domain/onnx_tokenization_preview.dart';

final noteSummarizerProvider = Provider<NoteSummarizer>((ref) {
  return LocalNoteSummarizer();
});

final noteEmbeddingIndexerProvider = Provider<NoteEmbeddingIndexer>((ref) {
  return LocalNoteEmbeddingIndexer();
});

final onnxMethodChannelClientProvider = Provider<OnnxMethodChannelClient>((ref) {
  return const OnnxMethodChannelClient();
});

final onnxRuntimeCapabilityProvider =
    FutureProvider<OnnxRuntimeCapability>((ref) async {
  final client = ref.watch(onnxMethodChannelClientProvider);
  return client.getCapability();
});

final aiRuntimeProvider = FutureProvider<AiRuntime>((ref) async {
  final capability = await ref.watch(onnxRuntimeCapabilityProvider.future);
  final stages = await ref.watch(localModelStagesProvider.future);
  return OnnxAiRuntime(
    fallbackSummarizer: ref.watch(noteSummarizerProvider),
    fallbackEmbeddingIndexer: ref.watch(noteEmbeddingIndexerProvider),
    capability: capability,
    stages: stages,
    methodChannelClient: ref.watch(onnxMethodChannelClientProvider),
  );
});

final localModelManifestLoaderProvider = Provider<LocalModelManifestLoader>((ref) {
  return const LocalModelManifestLoader();
});

final localModelManifestProvider = FutureProvider<LocalModelManifest>((ref) async {
  final loader = ref.watch(localModelManifestLoaderProvider);
  return loader.load();
});

final localModelInstallationCheckerProvider =
    Provider<LocalModelInstallationChecker>((ref) {
  return const LocalModelInstallationChecker();
});

final localModelInstallationsProvider =
    FutureProvider<List<LocalModelInstallation>>((ref) async {
  final manifest = await ref.watch(localModelManifestProvider.future);
  final checker = ref.watch(localModelInstallationCheckerProvider);
  return checker.check(manifest);
});

final localModelAssetStagerProvider = Provider<LocalModelAssetStager>((ref) {
  return const LocalModelAssetStager();
});

final localModelStagesProvider = FutureProvider<List<LocalModelStage>>((ref) async {
  final installations = await ref.watch(localModelInstallationsProvider.future);
  final stager = ref.watch(localModelAssetStagerProvider);
  return stager.stageAll(installations);
});

final summaryModelStageProvider = FutureProvider<LocalModelStage?>((ref) async {
  final stages = await ref.watch(localModelStagesProvider.future);
  for (final stage in stages) {
    if (stage.installation.spec.task == LocalModelTask.summarization) {
      return stage;
    }
  }
  return null;
});

final onnxSummarySessionPreparationProvider =
    FutureProvider<OnnxSessionPreparation?>((ref) async {
  final stage = await ref.watch(summaryModelStageProvider.future);
  if (stage == null || !stage.isStaged || stage.stagedModelPath == null) {
    return null;
  }
  final client = ref.watch(onnxMethodChannelClientProvider);
  return client.prepareSession(
    modelPath: stage.stagedModelPath!,
    tokenizerPath: stage.stagedTokenizerPath,
    inputNames: stage.installation.spec.onnxContract?.inputNames ?? const [],
    outputNames: stage.installation.spec.onnxContract?.outputNames ?? const [],
    maxSequenceLength: stage.installation.spec.onnxContract?.maxSequenceLength,
  );
});

final onnxSummaryContractInspectionProvider =
    FutureProvider<OnnxContractInspection?>((ref) async {
  final stage = await ref.watch(summaryModelStageProvider.future);
  if (stage == null || !stage.isStaged || stage.stagedModelPath == null) {
    return null;
  }
  final client = ref.watch(onnxMethodChannelClientProvider);
  return client.inspectContract(
    modelPath: stage.stagedModelPath!,
    inputNames: stage.installation.spec.onnxContract?.inputNames ?? const [],
    outputNames: stage.installation.spec.onnxContract?.outputNames ?? const [],
    maxSequenceLength: stage.installation.spec.onnxContract?.maxSequenceLength,
  );
});

final onnxSummaryTokenizationPreviewProvider =
    FutureProvider<OnnxTokenizationPreview?>((ref) async {
  final stage = await ref.watch(summaryModelStageProvider.future);
  if (stage == null || !stage.isStaged || stage.stagedModelPath == null) {
    return null;
  }
  final client = ref.watch(onnxMethodChannelClientProvider);
  return client.previewTokenization(
    modelPath: stage.stagedModelPath!,
    tokenizerPath: stage.stagedTokenizerPath,
    title: 'Preview',
    body: 'Tokenizer preview for the staged summary model.',
    maxSequenceLength: stage.installation.spec.onnxContract?.maxSequenceLength,
    padTokenId: stage.installation.spec.onnxContract?.padTokenId,
    unkTokenId: stage.installation.spec.onnxContract?.unkTokenId,
    bosTokenId: stage.installation.spec.onnxContract?.bosTokenId,
    eosTokenId: stage.installation.spec.onnxContract?.eosTokenId,
  );
});

final onnxSummaryTokenizerInspectionProvider =
    FutureProvider<OnnxTokenizerInspection?>((ref) async {
  final stage = await ref.watch(summaryModelStageProvider.future);
  if (stage == null ||
      !stage.isStaged ||
      stage.stagedTokenizerPath == null ||
      stage.stagedTokenizerPath!.isEmpty) {
    return null;
  }
  final client = ref.watch(onnxMethodChannelClientProvider);
  return client.inspectTokenizer(
    tokenizerPath: stage.stagedTokenizerPath!,
  );
});

final onnxSummaryRunPreviewProvider =
    FutureProvider<OnnxRunPreview?>((ref) async {
  final stage = await ref.watch(summaryModelStageProvider.future);
  if (stage == null || !stage.isStaged || stage.stagedModelPath == null) {
    return null;
  }
  final client = ref.watch(onnxMethodChannelClientProvider);
  final contract = stage.installation.spec.onnxContract;
  return client.previewRun(
    modelPath: stage.stagedModelPath!,
    tokenizerPath: stage.stagedTokenizerPath,
    title: 'Preview',
    body: 'Tokenizer preview for the staged summary model.',
    inputNames: contract?.inputNames ?? const [],
    outputNames: contract?.outputNames ?? const [],
    maxSequenceLength: contract?.maxSequenceLength,
    padTokenId: contract?.padTokenId,
    unkTokenId: contract?.unkTokenId,
    bosTokenId: contract?.bosTokenId,
    eosTokenId: contract?.eosTokenId,
  );
});

final onnxSummaryOutputInterpretationProvider =
    FutureProvider<OnnxOutputInterpretation?>((ref) async {
  final stage = await ref.watch(summaryModelStageProvider.future);
  final runPreview = await ref.watch(onnxSummaryRunPreviewProvider.future);
  if (stage == null || runPreview == null) {
    return null;
  }

  final decoderType =
      stage.installation.spec.onnxContract?.decoderType ?? 'unknown';
  final canAttemptDecode =
      runPreview.ready &&
      stage.installation.spec.onnxContract?.supportsGreedyDecode == true &&
      decoderType == 'seq2seq_logits' &&
      runPreview.outputShapes.isNotEmpty;

  return OnnxOutputInterpretation(
    available: runPreview.ready,
    decoderType: decoderType,
    canAttemptDecode: canAttemptDecode,
    message: switch (decoderType) {
      'seq2seq_logits' => canAttemptDecode
          ? 'Output preview is compatible with a FLAN-T5-style greedy seq2seq decode path.'
          : 'FLAN-T5-style seq2seq decode is configured but not ready to run yet.',
      'embedding_vector' =>
        'Output preview looks like an embedding path, not a text decoder path.',
      _ => 'Output decoder strategy is not configured yet.',
    },
  );
});

final aiRuntimeStatusProvider = FutureProvider<AiRuntimeStatus>((ref) async {
  final runtime = await ref.watch(aiRuntimeProvider.future);
  final capability = await ref.watch(onnxRuntimeCapabilityProvider.future);
  final manifest = await ref.watch(localModelManifestProvider.future);
  final installations = await ref.watch(localModelInstallationsProvider.future);
  final stages = await ref.watch(localModelStagesProvider.future);
  final sessionPreparation =
      await ref.watch(onnxSummarySessionPreparationProvider.future);
  final contractInspection =
      await ref.watch(onnxSummaryContractInspectionProvider.future);
  final tokenizationPreview =
      await ref.watch(onnxSummaryTokenizationPreviewProvider.future);
  final tokenizerInspection =
      await ref.watch(onnxSummaryTokenizerInspectionProvider.future);
  final runPreview = await ref.watch(onnxSummaryRunPreviewProvider.future);
  final outputInterpretation =
      await ref.watch(onnxSummaryOutputInterpretationProvider.future);
  final summaryModel = manifest.byTask(LocalModelTask.summarization);
  final embeddingModel = manifest.byTask(LocalModelTask.embedding);
  final packagedModels = manifest.packagedCount;
  final installedModels = installations.where((item) => item.isInstalled).length;
  final stagedModels = stages.where((item) => item.isStaged).length;
  final totalModels = manifest.models.length;
  final packagedRuntimeReady =
      summaryModel != null &&
      embeddingModel != null &&
      stages.any(
        (item) => item.installation.spec.id == summaryModel.id && item.isStaged,
      ) &&
      stages.any(
        (item) => item.installation.spec.id == embeddingModel.id && item.isStaged,
      );
  String? runtimeDirectory;
  for (final stage in stages) {
    if (stage.runtimeDirectory != null) {
      runtimeDirectory = stage.runtimeDirectory;
      break;
    }
  }

  return AiRuntimeStatus(
    runtimeLabel: runtime.runtimeLabel,
    modelVersion: runtime.modelVersion,
    isLocalOnly: runtime.isLocalOnly,
    isReady: true,
    packagedRuntimeReady: packagedRuntimeReady,
    nativeBackendLinked: capability.nativeLibraryLinked,
    nativeSessionReady: sessionPreparation?.ready ?? false,
    contractMatchesManifest: contractInspection?.matchesManifest ?? false,
    summaryEnabled: summaryModel != null,
    embeddingEnabled: embeddingModel != null,
    runtimeProfile: manifest.runtimeProfile,
    packagedModels: packagedModels,
    installedModels: installedModels,
    stagedModels: stagedModels,
    totalModels: totalModels,
    summaryModelId: summaryModel?.id,
    embeddingModelId: embeddingModel?.id,
    runtimeDirectory: runtimeDirectory,
    capabilityMessage: capability.message,
    sessionMessage: sessionPreparation?.message,
    contractMessage: contractInspection?.message,
    tokenizationMessage: tokenizationPreview?.message,
    tokenizerMessage: tokenizerInspection?.message,
    runPreviewMessage: runPreview?.message,
    outputInterpretationMessage: outputInterpretation?.message,
    actualInputNames: contractInspection?.actualInputNames ?? const [],
    actualOutputNames: contractInspection?.actualOutputNames ?? const [],
    previewInputIds: tokenizationPreview?.inputIds ?? const [],
    previewAttentionMask: tokenizationPreview?.attentionMask ?? const [],
    previewTokenizerLoaded: tokenizationPreview?.tokenizerLoaded ?? false,
    previewOutputNames: runPreview?.outputNames ?? const [],
    previewOutputShapes: runPreview?.outputShapes ?? const [],
    previewOutputValueSample: runPreview?.outputValueSample ?? const [],
    decoderType: outputInterpretation?.decoderType,
    canAttemptDecode: outputInterpretation?.canAttemptDecode ?? false,
    tokenizerVocabSize: tokenizerInspection?.vocabSize ?? 0,
    tokenizerModelType: tokenizerInspection?.modelType,
    tokenizerPreTokenizerType: tokenizerInspection?.preTokenizerType,
    tokenizerNormalizerType: tokenizerInspection?.normalizerType,
  );
});

final noteAiRepositoryProvider = Provider<NoteAiRepository>((ref) {
  return NoteAiRepository(AppDatabase());
});

final noteAiSnapshotProvider =
    FutureProvider.family<NoteAiSnapshot?, String>((ref, noteId) {
  final repository = ref.watch(noteAiRepositoryProvider);
  return repository.getSnapshot(noteId);
});
