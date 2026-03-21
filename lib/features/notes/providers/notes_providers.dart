import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/in_memory_notes_repository.dart';
import '../domain/note_preview.dart';
import '../domain/notes_repository.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return InMemoryNotesRepository();
});

final notesListProvider = FutureProvider<List<NotePreview>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.listNotes();
});
