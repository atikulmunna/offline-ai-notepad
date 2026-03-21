import '../domain/note_preview.dart';
import '../domain/notes_repository.dart';

class InMemoryNotesRepository implements NotesRepository {
  static const _notes = [
    NotePreview(
      id: 'research-ideas',
      title: 'Research ideas',
      body: 'Compare local vector search options and keep a graceful fallback when device support gets messy.',
      badge: 'Pinned',
      isPinned: true,
    ),
    NotePreview(
      id: 'release-checklist',
      title: 'Release checklist',
      body: 'Finish Android toolchain, scaffold architecture, and start note CRUD before AI integration.',
      badge: 'Today',
    ),
    NotePreview(
      id: 'privacy-copy',
      title: 'Privacy copy',
      body: 'Keep the onboarding promise simple: your notes stay on device unless you explicitly export them.',
      badge: 'Draft',
    ),
  ];

  @override
  Future<List<NotePreview>> listNotes() async {
    return _notes;
  }
}
