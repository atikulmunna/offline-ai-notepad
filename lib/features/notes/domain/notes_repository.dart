import 'note_collection.dart';
import 'note_document.dart';
import 'note_folder.dart';
import 'note_preview.dart';
import 'note_search_mode.dart';
import 'note_tag.dart';

abstract class NotesRepository {
  Future<List<NotePreview>> listNotes({
    NoteCollection collection = NoteCollection.active,
    String searchQuery = '',
    NoteSearchMode searchMode = NoteSearchMode.keyword,
    String? folderId,
    String? tagId,
    bool pinnedOnly = false,
  });
  Future<List<NoteFolder>> listFolders();
  Future<List<NoteTag>> listTags();
  Future<NoteTag> getOrCreateTag(String name);
  Future<void> setNoteTags({
    required String noteId,
    required List<String> tagIds,
  });
  Future<NoteFolder> createFolder(String name);
  Future<NoteFolder?> renameFolder({
    required String id,
    required String name,
  });
  Future<String> createNote({
    String? title,
    required String body,
    String? bodyDelta,
    String? folderId,
  });
  Future<NoteDocument?> getNote(String id);
  Future<void> updateNote({
    required String id,
    String? title,
    required String body,
    String? bodyDelta,
    String? folderId,
  });
  Future<void> togglePin({
    required String id,
    required bool value,
  });
  Future<void> setArchived({
    required String id,
    required bool value,
  });
  Future<void> moveToTrash(String id);
  Future<void> restoreFromTrash(String id);
  Future<void> deletePermanently(String id);
}
