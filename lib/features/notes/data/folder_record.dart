import '../domain/note_folder.dart';

class FolderRecord {
  const FolderRecord({
    required this.id,
    required this.name,
    required this.icon,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String icon;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory FolderRecord.fromMap(Map<String, Object?> map) {
    return FolderRecord(
      id: map['id']! as String,
      name: map['name']! as String,
      icon: (map['icon'] as String?) ?? 'folder',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
    );
  }

  NoteFolder toFolder() {
    return NoteFolder(
      id: id,
      name: name,
      icon: icon,
    );
  }
}
