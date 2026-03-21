import 'note_preview.dart';

abstract class NotesRepository {
  Future<List<NotePreview>> listNotes();
}
