import '../domain/note_collection.dart';
import '../domain/note_search_mode.dart';

class NotesViewState {
  const NotesViewState({
    this.collection = NoteCollection.active,
    this.searchQuery = '',
    this.searchMode = NoteSearchMode.keyword,
    this.folderId,
    this.tagId,
    this.tagName,
    this.pinnedOnly = false,
  });

  final NoteCollection collection;
  final String searchQuery;
  final NoteSearchMode searchMode;
  final String? folderId;
  final String? tagId;
  final String? tagName;
  final bool pinnedOnly;

  NotesViewState copyWith({
    NoteCollection? collection,
    String? searchQuery,
    NoteSearchMode? searchMode,
    String? folderId,
    bool clearFolder = false,
    String? tagId,
    String? tagName,
    bool clearTag = false,
    bool? pinnedOnly,
  }) {
    return NotesViewState(
      collection: collection ?? this.collection,
      searchQuery: searchQuery ?? this.searchQuery,
      searchMode: searchMode ?? this.searchMode,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      tagId: clearTag ? null : (tagId ?? this.tagId),
      tagName: clearTag ? null : (tagName ?? this.tagName),
      pinnedOnly: pinnedOnly ?? this.pinnedOnly,
    );
  }
}
