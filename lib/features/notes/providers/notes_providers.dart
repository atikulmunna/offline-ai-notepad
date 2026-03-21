import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/note_preview.dart';
import '../domain/notes_repository.dart';
import 'notes_repository_factory.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return createDefaultNotesRepository(ref);
});

final notesListProvider = FutureProvider<List<NotePreview>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.listNotes();
});
