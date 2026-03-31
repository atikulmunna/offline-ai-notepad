import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai_notepad/features/notes/data/in_memory_notes_repository.dart';
import 'package:offline_ai_notepad/features/notes/domain/note_search_mode.dart';

void main() {
  test('semantic search can surface related release notes', () async {
    final repository = InMemoryNotesRepository();

    final results = await repository.listNotes(
      searchQuery: 'launch plan',
      searchMode: NoteSearchMode.semantic,
    );

    expect(results, isNotEmpty);
    expect(results.first.id, 'release-checklist');
  });

  test('semantic search can connect privacy with security language', () async {
    final repository = InMemoryNotesRepository();

    final results = await repository.listNotes(
      searchQuery: 'security',
      searchMode: NoteSearchMode.semantic,
    );

    expect(results, isNotEmpty);
    expect(results.first.id, 'privacy-copy');
  });
}
