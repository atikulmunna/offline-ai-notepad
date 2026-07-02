import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notes/providers/notes_providers.dart';
import '../data/note_assistant.dart';
import 'ai_providers.dart';

/// Provides the on-device assistant that proposes titles and folders. Resolves
/// the query embedder once; folder suggestions no-op when none is available
/// (e.g. non-Android), while title suggestions still work everywhere.
final noteAssistantProvider = FutureProvider<NoteAssistant>((ref) async {
  final embedder = await ref.watch(noteQueryEmbedderProvider.future);
  final notesRepository = ref.watch(notesRepositoryProvider);
  final aiRepository = ref.watch(noteAiRepositoryProvider);

  return NoteAssistant(
    embedder: embedder,
    loadNotes: () => notesRepository.listNotes(),
    loadVectors: () => aiRepository.loadAllEmbeddings(),
  );
});
