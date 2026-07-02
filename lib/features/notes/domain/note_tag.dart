/// A label that can be attached to notes for organization and filtering.
class NoteTag {
  const NoteTag({
    required this.id,
    required this.name,
    this.colorHex = '#607D8B',
  });

  final String id;
  final String name;
  final String colorHex;

  @override
  bool operator ==(Object other) =>
      other is NoteTag && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
