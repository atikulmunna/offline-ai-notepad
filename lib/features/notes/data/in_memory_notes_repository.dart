import 'note_record.dart';
import '../domain/note_preview.dart';
import '../domain/notes_repository.dart';

class InMemoryNotesRepository implements NotesRepository {
  static final _notes = [
    NoteRecord(
      id: 'research-ideas',
      title: 'Research ideas',
      body: 'Compare local vector search options and keep a graceful fallback when device support gets messy.',
      isPinned: true,
      createdAt: DateTime(2026, 3, 21, 9, 0),
      updatedAt: DateTime(2026, 3, 21, 9, 45),
    ),
    NoteRecord(
      id: 'release-checklist',
      title: 'Release checklist',
      body: 'Finish Android toolchain, scaffold architecture, and start note CRUD before AI integration.',
      createdAt: DateTime(2026, 3, 21, 10, 0),
      updatedAt: DateTime(2026, 3, 21, 10, 30),
    ),
    NoteRecord(
      id: 'privacy-copy',
      title: 'Privacy copy',
      body: 'Keep the onboarding promise simple: your notes stay on device unless you explicitly export them.',
      createdAt: DateTime(2026, 3, 21, 11, 0),
      updatedAt: DateTime(2026, 3, 21, 11, 5),
    ),
  ];

  @override
  Future<List<NotePreview>> listNotes() async {
    return _notes.map((note) => note.toPreview()).toList(growable: false);
  }

  @override
  Future<void> createNote({
    String? title,
    required String body,
  }) async {
    final now = DateTime.now();
    _notes.insert(
      0,
      NoteRecord(
        id: 'note-${now.microsecondsSinceEpoch}',
        title: title,
        body: body,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
