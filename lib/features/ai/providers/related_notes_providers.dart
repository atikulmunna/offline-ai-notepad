import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notes/providers/notes_providers.dart';
import '../data/related_notes_service.dart';
import 'ai_providers.dart';

/// Provides the "See also" related-notes service. Ranks against stored
/// embeddings (no model call); falls back to lexical ranking when a note has no
/// vector yet.
final relatedNotesServiceProvider = Provider<RelatedNotesService>((ref) {
  final aiRepository = ref.watch(noteAiRepositoryProvider);
  final notesRepository = ref.watch(notesRepositoryProvider);
  return RelatedNotesService(
    loadNoteVector: (id) => aiRepository.loadEmbedding(id),
    loadVectors: () => aiRepository.loadAllEmbeddings(),
    loadNotes: () => notesRepository.listNotes(),
  );
});
