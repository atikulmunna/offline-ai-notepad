import '../domain/note_document.dart';
import '../domain/note_preview.dart';

class NoteRecord {
  const NoteRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.summary,
    this.folderId,
    this.isPinned = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.deletedAt,
  });

  final String id;
  final String? title;
  final String body;
  final String? summary;
  final String? folderId;
  final bool isPinned;
  final bool isArchived;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'summary': summary,
      'folder_id': folderId,
      'is_pinned': isPinned ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
    };
  }

  factory NoteRecord.fromMap(Map<String, Object?> map) {
    return NoteRecord(
      id: map['id']! as String,
      title: map['title'] as String?,
      body: map['body']! as String,
      summary: map['summary'] as String?,
      folderId: map['folder_id'] as String?,
      isPinned: (map['is_pinned']! as int) == 1,
      isArchived: (map['is_archived']! as int) == 1,
      isDeleted: (map['is_deleted']! as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['deleted_at']! as int),
    );
  }

  NotePreview toPreview() {
    return NotePreview(
      id: id,
      title: (title == null || title!.trim().isEmpty) ? 'Untitled note' : title!,
      body: body,
      badge: isPinned ? 'Pinned' : 'Draft',
      updatedAt: updatedAt,
      isPinned: isPinned,
    );
  }

  NoteDocument toDocument() {
    return NoteDocument(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isPinned: isPinned,
    );
  }
}
