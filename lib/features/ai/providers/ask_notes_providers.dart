import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notes/providers/notes_providers.dart';
import '../data/ask_notes_service.dart';
import '../data/onnx_grounded_answerer.dart';
import '../domain/grounded_answerer.dart';
import '../domain/local_model_stage.dart';
import '../domain/local_model_task.dart';
import '../domain/note_qa.dart';
import 'ai_providers.dart';

/// Builds an on-device answerer over the staged summarization model (falls back
/// to the extractive summarizer when the native runtime is unavailable).
final groundedAnswererProvider = FutureProvider<GroundedAnswerer>((ref) async {
  final capability = await ref.watch(onnxRuntimeCapabilityProvider.future);
  final stages = await ref.watch(localModelStagesProvider.future);
  final summaryStage = stages
      .where((stage) =>
          stage.installation.spec.task == LocalModelTask.summarization)
      .cast<LocalModelStage?>()
      .firstWhere((stage) => stage != null, orElse: () => null);

  return OnnxGroundedAnswerer(
    fallbackSummarizer: ref.watch(noteSummarizerProvider),
    capability: capability,
    summaryStage: summaryStage,
    methodChannelClient: ref.watch(onnxMethodChannelClientProvider),
  );
});

final askNotesServiceProvider = FutureProvider<AskNotesService>((ref) async {
  final embedder = await ref.watch(noteQueryEmbedderProvider.future);
  final answerer = await ref.watch(groundedAnswererProvider.future);
  final notesRepository = ref.watch(notesRepositoryProvider);
  final aiRepository = ref.watch(noteAiRepositoryProvider);

  return AskNotesService(
    queryEmbedder: embedder,
    answerer: answerer,
    loadNotes: () => notesRepository.listNotes(),
    loadVectors: () => aiRepository.loadAllEmbeddings(),
  );
});

enum AskStatus { idle, loading, done, error }

class AskNotesState {
  const AskNotesState({
    this.status = AskStatus.idle,
    this.answer,
    this.error,
  });

  final AskStatus status;
  final NoteQaAnswer? answer;
  final String? error;

  bool get isLoading => status == AskStatus.loading;
}

class AskNotesController extends StateNotifier<AskNotesState> {
  AskNotesController(this._ref) : super(const AskNotesState());

  final Ref _ref;

  Future<void> ask(String question) async {
    state = const AskNotesState(status: AskStatus.loading);
    try {
      final service = await _ref.read(askNotesServiceProvider.future);
      final answer = await service.ask(question);
      if (!mounted) return;
      state = AskNotesState(status: AskStatus.done, answer: answer);
    } catch (error) {
      if (!mounted) return;
      state = AskNotesState(status: AskStatus.error, error: error.toString());
    }
  }

  void reset() {
    state = const AskNotesState();
  }
}

final askNotesControllerProvider =
    StateNotifierProvider<AskNotesController, AskNotesState>((ref) {
  return AskNotesController(ref);
});
