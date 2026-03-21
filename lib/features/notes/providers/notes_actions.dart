import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notes_providers.dart';

final notesActionsProvider = Provider<NotesActions>((ref) {
  return NotesActions(ref);
});

class NotesActions {
  const NotesActions(this._ref);

  final Ref _ref;

  Future<void> createNote({
    String? title,
    required String body,
  }) async {
    final repository = _ref.read(notesRepositoryProvider);
    await repository.createNote(title: title, body: body);
    _ref.invalidate(notesListProvider);
  }
}
