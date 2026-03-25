import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notes/providers/notes_providers.dart';
import 'ai_providers.dart';

final aiActionsProvider = Provider<AiActions>((ref) {
  return AiActions(ref);
});

class AiActions {
  const AiActions(this._ref);

  final Ref _ref;

  Future<String> generateSummary({
    required String noteId,
    String? title,
    required String body,
  }) async {
    final runtime = await _ref.read(aiRuntimeProvider.future);
    final repository = _ref.read(noteAiRepositoryProvider);

    final result = await runtime.processNote(
      noteId: noteId,
      title: title,
      body: body,
    );
    await repository.saveSummary(noteId: noteId, summary: result.summary);
    await repository.saveEmbeddingMetadata(result.embeddingMetadata);

    _ref.invalidate(noteAiSnapshotProvider(noteId));
    _ref.invalidate(notesListProvider);
    return result.summary;
  }
}
