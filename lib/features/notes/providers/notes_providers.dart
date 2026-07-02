import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/markdown_io_service.dart';
import '../domain/note_folder.dart';
import '../domain/note_preview.dart';
import '../domain/note_tag.dart';
import '../domain/notes_repository.dart';
import 'notes_repository_factory.dart';
import 'notes_view_state.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return createDefaultNotesRepository(ref);
});

final markdownIoServiceProvider = Provider<MarkdownIoService>((ref) {
  return const MarkdownIoService();
});

final notesViewStateProvider = StateProvider<NotesViewState>((ref) {
  return const NotesViewState();
});

final notesListProvider = FutureProvider<List<NotePreview>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  final viewState = ref.watch(notesViewStateProvider);
  return repository.listNotes(
    collection: viewState.collection,
    searchQuery: viewState.searchQuery,
    searchMode: viewState.searchMode,
    folderId: viewState.folderId,
    tagId: viewState.tagId,
    pinnedOnly: viewState.pinnedOnly,
  );
});

final noteFoldersProvider = FutureProvider<List<NoteFolder>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.listFolders();
});

final noteTagsProvider = FutureProvider<List<NoteTag>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.listTags();
});
