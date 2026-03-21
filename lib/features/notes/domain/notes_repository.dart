import 'note_preview.dart';

abstract class NotesRepository {
  Future<List<NotePreview>> listNotes();
  Future<void> createNote({
    String? title,
    required String body,
  });
}
