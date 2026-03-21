import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_schema.dart';
import '../domain/note_document.dart';
import '../domain/note_preview.dart';
import '../domain/notes_repository.dart';
import 'note_record.dart';

class LocalNotesRepository implements NotesRepository {
  LocalNotesRepository(this._database);

  final AppDatabase _database;

  static final _seedNotes = [
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
    await _database.seedIfEmpty(
      table: DatabaseSchema.notesTable,
      rows: _seedNotes.map((note) => note.toMap()).toList(growable: false),
    );

    final rows = await _database.query(
      DatabaseSchema.notesTable,
      orderBy: 'is_pinned DESC, updated_at DESC',
      limit: 50,
    );

    return rows
        .map(NoteRecord.fromMap)
        .where((note) => !note.isDeleted && !note.isArchived)
        .map((note) => note.toPreview())
        .toList(growable: false);
  }

  Future<void> upsert(NoteRecord note) {
    return _database.insert(
      DatabaseSchema.notesTable,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<String> createNote({
    String? title,
    required String body,
  }) async {
    final now = DateTime.now();
    final id = 'note-${now.microsecondsSinceEpoch}';
    await upsert(
      NoteRecord(
        id: id,
        title: title,
        body: body,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  @override
  Future<NoteDocument?> getNote(String id) async {
    await _database.seedIfEmpty(
      table: DatabaseSchema.notesTable,
      rows: _seedNotes.map((note) => note.toMap()).toList(growable: false),
    );

    final rows = await _database.query(
      DatabaseSchema.notesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return NoteRecord.fromMap(rows.first).toDocument();
  }

  @override
  Future<void> updateNote({
    required String id,
    String? title,
    required String body,
  }) async {
    final existing = await getNote(id);
    if (existing == null) {
      return;
    }

    final updated = NoteRecord(
      id: existing.id,
      title: title,
      body: body,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );

    await _database.update(
      DatabaseSchema.notesTable,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
