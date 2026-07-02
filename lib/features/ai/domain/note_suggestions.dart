import '../../notes/domain/note_tag.dart';

/// A folder the assistant proposes for the current note, based on where
/// semantically similar notes live.
class FolderSuggestion {
  const FolderSuggestion({required this.id, required this.name});

  final String id;
  final String name;
}

/// Non-destructive suggestions the on-device assistant offers while writing:
/// a title for an untitled note, a folder for an unfiled one, and tags drawn
/// from similar notes. The user decides whether to apply them.
class NoteSuggestions {
  const NoteSuggestions({this.title, this.folder, this.tags = const []});

  const NoteSuggestions.none()
      : title = null,
        folder = null,
        tags = const [];

  final String? title;
  final FolderSuggestion? folder;
  final List<NoteTag> tags;

  bool get isEmpty => title == null && folder == null && tags.isEmpty;
  bool get isNotEmpty => !isEmpty;
}
