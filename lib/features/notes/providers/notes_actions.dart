import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/note_document.dart';
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
  }) async {
    final repository = _ref.read(notesRepositoryProvider);
    final id = await repository.createNote(title: title, body: body);
    _ref.invalidate(notesListProvider);
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
  }) async {
    final repository = _ref.read(notesRepositoryProvider);
    await repository.updateNote(id: id, title: title, body: body);
    _ref.invalidate(notesListProvider);
  }
}
