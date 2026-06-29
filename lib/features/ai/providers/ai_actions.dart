import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notes/providers/notes_providers.dart';
import '../data/onnx_note_embedding_indexer.dart';
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

  /// Computes and stores a note's embedding in the background after a save.
  /// Marks the row queued first (preserving any prior vector), then writes the
  /// computed vector. Safe to call fire-and-forget: failures are swallowed.
  Future<void> indexNoteEmbedding({
    required String noteId,
    String? title,
    required String body,
  }) async {
    try {
      // No native embedding runtime -> semantic search uses lexical ranking, so
      // skip writing placeholder embedding rows entirely.
      final embedder = await _ref.read(noteQueryEmbedderProvider.future);
      if (embedder == null) {
        return;
      }

      final repository = _ref.read(noteAiRepositoryProvider);
      await repository.markEmbeddingQueued(
        noteId,
        OnnxNoteEmbeddingIndexer.modelVersion,
      );

      final indexer = await _ref.read(noteEmbeddingIndexerProvider.future);
      final metadata = await indexer.indexNote(
        noteId: noteId,
        title: title,
        body: body,
      );
      await repository.saveEmbeddingMetadata(metadata);

      _ref.invalidate(noteAiSnapshotProvider(noteId));
      _ref.invalidate(notesListProvider);
    } catch (_) {
      // Embedding is a progressive enhancement; lexical search still works.
    }
  }

  /// One-time pass that embeds existing notes lacking a current vector. No-op on
  /// platforms without a native embedding runtime (lexical search is used).
  Future<void> backfillEmbeddings() async {
    try {
      final embedder = await _ref.read(noteQueryEmbedderProvider.future);
      if (embedder == null) {
        return;
      }

      final repository = _ref.read(noteAiRepositoryProvider);
      final pending = await repository.notesNeedingEmbedding(
        OnnxNoteEmbeddingIndexer.modelVersion,
      );
      if (pending.isEmpty) {
        return;
      }

      final indexer = await _ref.read(noteEmbeddingIndexerProvider.future);
      for (final note in pending) {
        final metadata = await indexer.indexNote(
          noteId: note.id,
          title: note.title,
          body: note.body,
        );
        await repository.saveEmbeddingMetadata(metadata);
      }

      _ref.invalidate(notesListProvider);
    } catch (_) {
      // Backfill is best-effort; ignore failures.
    }
  }
}
