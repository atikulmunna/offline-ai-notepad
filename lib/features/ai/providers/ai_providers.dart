import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../data/local_model_asset_stager.dart';
import '../data/local_model_downloader.dart';
import '../data/local_model_installation_checker.dart';
import '../data/local_model_manifest_loader.dart';
import '../data/local_note_embedding_indexer.dart';
import '../data/local_note_summarizer.dart';
import '../data/note_ai_repository.dart';
import '../data/onnx_ai_runtime.dart';
import '../data/onnx_method_channel_client.dart';
import '../data/onnx_note_embedding_indexer.dart';
import '../domain/ai_runtime.dart';
import '../domain/ai_runtime_status.dart';
import '../domain/local_model_installation.dart';
import '../domain/local_model_manifest.dart';
import '../domain/local_model_stage.dart';
import '../domain/local_model_task.dart';
import '../domain/note_ai_snapshot.dart';
import '../domain/note_embedding_indexer.dart';
import '../domain/note_query_embedder.dart';
import '../domain/note_summarizer.dart';
import '../domain/onnx_runtime_capability.dart';

final noteSummarizerProvider = Provider<NoteSummarizer>((ref) {
  return LocalNoteSummarizer();
});

final noteEmbeddingIndexerProvider =
    FutureProvider<NoteEmbeddingIndexer>((ref) async {
  final capability = await ref.watch(onnxRuntimeCapabilityProvider.future);
  final stages = await ref.watch(localModelStagesProvider.future);
  final embeddingStage = stages
      .where((stage) => stage.installation.spec.task == LocalModelTask.embedding)
      .cast<LocalModelStage?>()
      .firstWhere((stage) => stage != null, orElse: () => null);

  return OnnxNoteEmbeddingIndexer(
    methodChannelClient: ref.watch(onnxMethodChannelClientProvider),
    embeddingStage: embeddingStage,
    capability: capability,
    fallback: LocalNoteEmbeddingIndexer(),
  );
});

/// The query-side embedder for semantic search, when a native embedding runtime
/// is available. Null on platforms that fall back to lexical ranking.
final noteQueryEmbedderProvider =
    FutureProvider<NoteQueryEmbedder?>((ref) async {
  final capability = await ref.watch(onnxRuntimeCapabilityProvider.future);
  if (!capability.isUsable) {
    return null;
  }
  final indexer = await ref.watch(noteEmbeddingIndexerProvider.future);
  return indexer is NoteQueryEmbedder ? indexer as NoteQueryEmbedder : null;
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
    fallbackEmbeddingIndexer:
        await ref.watch(noteEmbeddingIndexerProvider.future),
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

final localModelDownloaderProvider = Provider<LocalModelDownloader>((ref) {
  return LocalModelDownloader();
});

final localModelInstallationCheckerProvider =
    Provider<LocalModelInstallationChecker>((ref) {
  return LocalModelInstallationChecker(
    downloader: ref.watch(localModelDownloaderProvider),
  );
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

final aiRuntimeStatusProvider = FutureProvider<AiRuntimeStatus>((ref) async {
  final capability = await ref.watch(onnxRuntimeCapabilityProvider.future);
  final manifest = await ref.watch(localModelManifestProvider.future);
  final installations = await ref.watch(localModelInstallationsProvider.future);
  final stages = await ref.watch(localModelStagesProvider.future);
  final summaryModel = manifest.byTask(LocalModelTask.summarization);
  final embeddingModel = manifest.byTask(LocalModelTask.embedding);
  final packagedModels = manifest.packagedCount;
  final installedModels = installations.where((item) => item.isInstalled).length;
  final totalModels = manifest.models.length;
  final stagedModels = stages.where((stage) => stage.isStaged).length;
  final runtimeDirectory = stages
      .map((stage) => stage.runtimeDirectory)
      .firstWhere((dir) => dir != null, orElse: () => null);
  final packagedRuntimeReady =
      capability.nativeLibraryLinked && stagedModels > 0;
  final runtimeLabel = capability.nativeLibraryLinked
      ? 'ONNX runtime ready on demand'
      : capability.bridgeAvailable
      ? 'ONNX bridge registered'
      : 'Fallback local runtime';
  final modelVersion = [
    if (summaryModel != null) summaryModel.id,
    if (embeddingModel != null) embeddingModel.id,
  ].join('+');

  return AiRuntimeStatus(
    runtimeLabel: runtimeLabel,
    modelVersion: modelVersion.isEmpty ? 'local-ai-planned' : modelVersion,
    isLocalOnly: true,
    isReady: true,
    packagedRuntimeReady: packagedRuntimeReady,
    nativeBackendLinked: capability.nativeLibraryLinked,
    nativeSessionReady: false,
    contractMatchesManifest: false,
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
    sessionMessage:
        'Runs when you generate a summary.',
    contractMessage:
        'Checked during generation.',
    tokenizationMessage:
        'Prepared during generation.',
    tokenizerMessage: 'Loaded during generation.',
    runPreviewMessage:
        'Available during generation.',
    outputInterpretationMessage:
        'This panel shows setup state, not the last result.',
    actualInputNames: const [],
    actualOutputNames: const [],
    previewInputIds: const [],
    previewAttentionMask: const [],
    previewTokenizerLoaded: false,
    previewOutputNames: const [],
    previewOutputShapes: const [],
    previewOutputValueSample: const [],
    decoderType: summaryModel?.onnxContract?.decoderType,
    canAttemptDecode: false,
    tokenizerVocabSize: 0,
    tokenizerModelType: null,
    tokenizerPreTokenizerType: null,
    tokenizerNormalizerType: null,
  );
});

final noteAiRepositoryProvider = Provider<NoteAiRepository>((ref) {
  return NoteAiRepository(
    ref.watch(appDatabaseProvider),
    ref,
  );
});

final noteAiSnapshotProvider =
    FutureProvider.family<NoteAiSnapshot?, String>((ref, noteId) {
  final repository = ref.watch(noteAiRepositoryProvider);
  return repository.getSnapshot(noteId);
});
