class NoteDocument {
  const NoteDocument({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.isPinned,
    this.summary,
    this.folderId,
    this.isArchived = false,
    this.isDeleted = false,
    this.deletedAt,
  });

  final String id;
  final String? title;
  final String body;
  final String? summary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final String? folderId;
  final bool isArchived;
  final bool isDeleted;
  final DateTime? deletedAt;
}
