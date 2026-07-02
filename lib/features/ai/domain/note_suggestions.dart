/// A folder the assistant proposes for the current note, based on where
/// semantically similar notes live.
class FolderSuggestion {
  const FolderSuggestion({required this.id, required this.name});

  final String id;
  final String name;
}

/// Non-destructive suggestions the on-device assistant offers while writing:
/// a title for an untitled note and/or a folder for an unfiled one. The user
/// decides whether to apply them.
class NoteSuggestions {
  const NoteSuggestions({this.title, this.folder});

  const NoteSuggestions.none()
      : title = null,
        folder = null;

  final String? title;
  final FolderSuggestion? folder;

  bool get isEmpty => title == null && folder == null;
  bool get isNotEmpty => !isEmpty;
}
