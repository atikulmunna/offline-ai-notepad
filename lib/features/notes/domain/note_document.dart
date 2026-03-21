class NoteDocument {
  const NoteDocument({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
}
