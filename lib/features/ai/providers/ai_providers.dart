import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/heuristic_ai_runtime.dart';
import '../data/local_model_installation_checker.dart';
import '../data/local_model_manifest_loader.dart';
import '../data/local_note_embedding_indexer.dart';
import '../data/local_note_summarizer.dart';
import '../data/note_ai_repository.dart';
import '../domain/ai_runtime.dart';
import '../domain/ai_runtime_status.dart';
import '../domain/local_model_installation.dart';
import '../domain/local_model_manifest.dart';
import '../domain/local_model_task.dart';
import '../domain/note_ai_snapshot.dart';
import '../domain/note_embedding_indexer.dart';
import '../domain/note_summarizer.dart';

final noteSummarizerProvider = Provider<NoteSummarizer>((ref) {
  return LocalNoteSummarizer();
});

final noteEmbeddingIndexerProvider = Provider<NoteEmbeddingIndexer>((ref) {
  return LocalNoteEmbeddingIndexer();
});

final aiRuntimeProvider = Provider<AiRuntime>((ref) {
  return HeuristicAiRuntime(
    summarizer: ref.watch(noteSummarizerProvider),
    embeddingIndexer: ref.watch(noteEmbeddingIndexerProvider),
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

final aiRuntimeStatusProvider = FutureProvider<AiRuntimeStatus>((ref) async {
  final runtime = ref.watch(aiRuntimeProvider);
  final manifest = await ref.watch(localModelManifestProvider.future);
  final installations = await ref.watch(localModelInstallationsProvider.future);
  final summaryModel = manifest.byTask(LocalModelTask.summarization);
  final embeddingModel = manifest.byTask(LocalModelTask.embedding);
  final packagedModels = manifest.packagedCount;
  final installedModels = installations.where((item) => item.isInstalled).length;
  final totalModels = manifest.models.length;
  final packagedRuntimeReady =
      summaryModel != null &&
      embeddingModel != null &&
      installations.any(
        (item) => item.spec.id == summaryModel.id && item.isInstalled,
      ) &&
      installations.any(
        (item) => item.spec.id == embeddingModel.id && item.isInstalled,
      );

  return AiRuntimeStatus(
    runtimeLabel: runtime.runtimeLabel,
    modelVersion: runtime.modelVersion,
    isLocalOnly: runtime.isLocalOnly,
    isReady: true,
    packagedRuntimeReady: packagedRuntimeReady,
    summaryEnabled: summaryModel != null,
    embeddingEnabled: embeddingModel != null,
    runtimeProfile: manifest.runtimeProfile,
    packagedModels: packagedModels,
    installedModels: installedModels,
    totalModels: totalModels,
    summaryModelId: summaryModel?.id,
    embeddingModelId: embeddingModel?.id,
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
