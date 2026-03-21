import '../domain/note_collection.dart';

class NotesViewState {
  const NotesViewState({
    this.collection = NoteCollection.active,
    this.searchQuery = '',
    this.folderId,
    this.pinnedOnly = false,
  });

  final NoteCollection collection;
  final String searchQuery;
  final String? folderId;
  final bool pinnedOnly;

  NotesViewState copyWith({
    NoteCollection? collection,
    String? searchQuery,
    String? folderId,
    bool clearFolder = false,
    bool? pinnedOnly,
  }) {
    return NotesViewState(
      collection: collection ?? this.collection,
      searchQuery: searchQuery ?? this.searchQuery,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      pinnedOnly: pinnedOnly ?? this.pinnedOnly,
    );
  }
}
