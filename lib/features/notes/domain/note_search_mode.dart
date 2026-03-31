enum NoteSearchMode {
  keyword,
  semantic,
}

extension NoteSearchModeX on NoteSearchMode {
  String get label => switch (this) {
        NoteSearchMode.keyword => 'Keyword',
        NoteSearchMode.semantic => 'Semantic',
      };

  String get helperLabel => switch (this) {
        NoteSearchMode.keyword => 'Exact words and phrases',
        NoteSearchMode.semantic => 'Meaning-first local recall',
      };
}
