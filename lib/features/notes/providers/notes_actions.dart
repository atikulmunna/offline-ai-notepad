import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/note_collection.dart';
import '../domain/note_document.dart';
import '../domain/note_folder.dart';
import 'notes_providers.dart';

final notesActionsProvider = Provider<NotesActions>((ref) {
  return NotesActions(ref);
});

class NotesActions {
  const NotesActions(this._ref);

  final Ref _ref;

  Future<String> createNote({
    String? title,
    required String body,
    String? folderId,
  }) async {
    final repository = _ref.read(notesRepositoryProvider);
    final id = await repository.createNote(
      title: title,
      body: body,
      folderId: folderId,
    );
    _ref.invalidate(notesListProvider);
    _ref.invalidate(noteFoldersProvider);
    return id;
  }

  Future<NoteDocument?> loadNote(String id) {
    final repository = _ref.read(notesRepositoryProvider);
    return repository.getNote(id);
  }

  Future<void> updateNote({
    required String id,
    String? title,
    required String body,
    String? folderId,
  }) async {
    final repository = _ref.read(notesRepositoryProvider);
    await repository.updateNote(
      id: id,
      title: title,
      body: body,
      folderId: folderId,
    );
    _ref.invalidate(notesListProvider);
    _ref.invalidate(noteFoldersProvider);
  }

  Future<void> togglePin({
    required String id,
    required bool value,
  }) async {
    final repository = _ref.read(notesRepositoryProvider);
    await repository.togglePin(id: id, value: value);
    _ref.invalidate(notesListProvider);
  }

  Future<void> setArchived({
    required String id,
    required bool value,
  }) async {
    final repository = _ref.read(notesRepositoryProvider);
    await repository.setArchived(id: id, value: value);
    _ref.invalidate(notesListProvider);
  }

  Future<void> moveToTrash(String id) async {
    final repository = _ref.read(notesRepositoryProvider);
    await repository.moveToTrash(id);
    _ref.invalidate(notesListProvider);
  }

  Future<void> restoreFromTrash(String id) async {
    final repository = _ref.read(notesRepositoryProvider);
    await repository.restoreFromTrash(id);
    _ref.invalidate(notesListProvider);
  }

  Future<void> deletePermanently(String id) async {
    final repository = _ref.read(notesRepositoryProvider);
    await repository.deletePermanently(id);
    _ref.invalidate(notesListProvider);
  }

  Future<NoteFolder> createFolder(String name) async {
    final repository = _ref.read(notesRepositoryProvider);
    final folder = await repository.createFolder(name);
    _ref.invalidate(noteFoldersProvider);
    _ref.invalidate(notesListProvider);
    return folder;
  }

  Future<NoteFolder?> renameFolder({
    required String id,
    required String name,
  }) async {
    final repository = _ref.read(notesRepositoryProvider);
    final folder = await repository.renameFolder(id: id, name: name);
    _ref.invalidate(noteFoldersProvider);
    _ref.invalidate(notesListProvider);
    return folder;
  }

  void showCollection(NoteCollection collection) {
    _ref.read(notesViewStateProvider.notifier).state = _ref
        .read(notesViewStateProvider)
        .copyWith(collection: collection);
  }

  void setSearchQuery(String value) {
    _ref.read(notesViewStateProvider.notifier).state = _ref
        .read(notesViewStateProvider)
        .copyWith(searchQuery: value);
  }

  void setFolderFilter(String? folderId) {
    _ref.read(notesViewStateProvider.notifier).state = _ref
        .read(notesViewStateProvider)
        .copyWith(folderId: folderId, clearFolder: folderId == null);
  }

  void setPinnedOnly(bool value) {
    _ref.read(notesViewStateProvider.notifier).state = _ref
        .read(notesViewStateProvider)
        .copyWith(pinnedOnly: value);
  }
}
