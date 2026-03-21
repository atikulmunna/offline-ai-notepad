import 'note_document.dart';
import 'note_preview.dart';

abstract class NotesRepository {
  Future<List<NotePreview>> listNotes();
  Future<String> createNote({
    String? title,
    required String body,
  });
  Future<NoteDocument?> getNote(String id);
  Future<void> updateNote({
    required String id,
    String? title,
    required String body,
  });
}
