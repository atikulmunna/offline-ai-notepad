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
import '../domain/onnx_runtime_capability.dart';

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

final aiRuntimeStatusProvider = FutureProvider<AiRuntimeStatus>((ref) async {
  final runtime = await ref.watch(aiRuntimeProvider.future);
  final capability = await ref.watch(onnxRuntimeCapabilityProvider.future);
  final manifest = await ref.watch(localModelManifestProvider.future);
  final installations = await ref.watch(localModelInstallationsProvider.future);
  final stages = await ref.watch(localModelStagesProvider.future);
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
