import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/heuristic_ai_runtime.dart';
import '../data/local_note_embedding_indexer.dart';
import '../data/local_note_summarizer.dart';
import '../data/note_ai_repository.dart';
import '../domain/ai_runtime.dart';
import '../domain/ai_runtime_status.dart';
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

final aiRuntimeStatusProvider = Provider<AiRuntimeStatus>((ref) {
  final runtime = ref.watch(aiRuntimeProvider);
  return AiRuntimeStatus(
    runtimeLabel: runtime.runtimeLabel,
    modelVersion: runtime.modelVersion,
    isLocalOnly: runtime.isLocalOnly,
    isReady: true,
    summaryEnabled: true,
    embeddingEnabled: true,
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
