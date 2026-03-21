class NotePreview {
  const NotePreview({
    required this.id,
    required this.title,
    required this.body,
    required this.badge,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final String body;
  final String badge;
  final bool isPinned;
}
