import 'note_tag.dart';

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
    this.tags = const [],
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
  final List<NoteTag> tags;

  NotePreview withTags(List<NoteTag> tags) {
    return NotePreview(
      id: id,
      title: title,
      body: body,
      badge: badge,
      updatedAt: updatedAt,
      folderId: folderId,
      folderName: folderName,
      isPinned: isPinned,
      isArchived: isArchived,
      isDeleted: isDeleted,
      tags: tags,
    );
  }
}
