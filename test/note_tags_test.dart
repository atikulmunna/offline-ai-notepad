import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai_notepad/features/notes/data/in_memory_notes_repository.dart';

void main() {
  group('Tags', () {
    test('getOrCreateTag creates once and dedupes case-insensitively',
        () async {
      final repo = InMemoryNotesRepository();
      final a = await repo.getOrCreateTag('Work');
      final b = await repo.getOrCreateTag('work');

      expect(a.id, b.id);
      expect(await repo.listTags(), hasLength(1));
    });

    test('setNoteTags shows tags on previews and supports filtering', () async {
      final repo = InMemoryNotesRepository();
      final id = await repo.createNote(body: 'A note to tag');
      final work = await repo.getOrCreateTag('Work');
      await repo.setNoteTags(noteId: id, tagIds: [work.id]);

      final all = await repo.listNotes();
      final tagged = all.firstWhere((preview) => preview.id == id);
      expect(tagged.tags.map((t) => t.name), ['Work']);

      final filtered = await repo.listNotes(tagId: work.id);
      expect(filtered.any((preview) => preview.id == id), isTrue);
      expect(
        filtered.every((preview) => preview.tags.any((t) => t.id == work.id)),
        isTrue,
      );

      final none = await repo.listNotes(tagId: 'does-not-exist');
      expect(none, isEmpty);
    });

    test('setNoteTags replaces the previous assignment', () async {
      final repo = InMemoryNotesRepository();
      final id = await repo.createNote(body: 'note');
      final a = await repo.getOrCreateTag('Alpha');
      final b = await repo.getOrCreateTag('Beta');

      await repo.setNoteTags(noteId: id, tagIds: [a.id]);
      await repo.setNoteTags(noteId: id, tagIds: [b.id]);

      final doc = await repo.getNote(id);
      expect(doc, isNotNull);
      expect(doc!.tags.map((t) => t.name), ['Beta']);
    });
  });
}
