class NotePreview {
  const NotePreview({
    required this.id,
    required this.title,
    required this.body,
    required this.badge,
    required this.updatedAt,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final String body;
  final String badge;
  final DateTime updatedAt;
  final bool isPinned;
}
