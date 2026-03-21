class NotePreview {
  const NotePreview({
    required this.id,
    required this.title,
    required this.body,
    required this.badge,
    required this.updatedAt,
    this.folderId,
    this.folderName,
    this.isPinned = false,
    this.isArchived = false,
    this.isDeleted = false,
  });

  final String id;
  final String title;
  final String body;
  final String badge;
  final DateTime updatedAt;
  final String? folderId;
  final String? folderName;
  final bool isPinned;
  final bool isArchived;
  final bool isDeleted;
}
