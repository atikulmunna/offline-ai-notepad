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
    final summarizer = _ref.read(noteSummarizerProvider);
    final indexer = _ref.read(noteEmbeddingIndexerProvider);
    final repository = _ref.read(noteAiRepositoryProvider);

    final summary = await summarizer.summarize(
      title: title,
      body: body,
    );
    await repository.saveSummary(noteId: noteId, summary: summary);

    final embeddingMetadata = await indexer.indexNote(
      noteId: noteId,
      title: title,
      body: body,
    );
    await repository.saveEmbeddingMetadata(embeddingMetadata);

    _ref.invalidate(noteAiSnapshotProvider(noteId));
    _ref.invalidate(notesListProvider);
    return summary;
  }
}
