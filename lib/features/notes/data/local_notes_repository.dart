import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_schema.dart';
import '../domain/note_collection.dart';
import '../domain/note_document.dart';
import '../domain/note_folder.dart';
import '../domain/note_preview.dart';
import '../domain/notes_repository.dart';
import 'folder_record.dart';
import 'note_record.dart';

class LocalNotesRepository implements NotesRepository {
  LocalNotesRepository(this._database);

  final AppDatabase _database;

  static final _seedFolders = [
    FolderRecord(
      id: 'product',
      name: 'Product',
      icon: 'lightbulb',
      createdAt: DateTime(2026, 3, 21, 8, 30),
    ),
    FolderRecord(
      id: 'private',
      name: 'Private',
      icon: 'lock',
      createdAt: DateTime(2026, 3, 21, 8, 35),
    ),
    FolderRecord(
      id: 'research',
      name: 'Research',
      icon: 'search',
      createdAt: DateTime(2026, 3, 21, 8, 40),
    ),
  ];

  static final _seedNotes = [
    NoteRecord(
      id: 'research-ideas',
      title: 'Research ideas',
      body: 'Compare local vector search options and keep a graceful fallback when device support gets messy.',
      folderId: 'research',
      folderName: 'Research',
      isPinned: true,
      createdAt: DateTime(2026, 3, 21, 9, 0),
      updatedAt: DateTime(2026, 3, 21, 9, 45),
    ),
    NoteRecord(
      id: 'release-checklist',
      title: 'Release checklist',
      body: 'Finish Android toolchain, scaffold architecture, and start note CRUD before AI integration.',
      folderId: 'product',
      folderName: 'Product',
      createdAt: DateTime(2026, 3, 21, 10, 0),
      updatedAt: DateTime(2026, 3, 21, 10, 30),
    ),
    NoteRecord(
      id: 'privacy-copy',
      title: 'Privacy copy',
      body: 'Keep the onboarding promise simple: your notes stay on device unless you explicitly export them.',
      folderId: 'private',
      folderName: 'Private',
      createdAt: DateTime(2026, 3, 21, 11, 0),
      updatedAt: DateTime(2026, 3, 21, 11, 5),
    ),
  ];

  @override
  Future<List<NotePreview>> listNotes({
    NoteCollection collection = NoteCollection.active,
    String searchQuery = '',
    String? folderId,
    bool pinnedOnly = false,
  }) async {
    await _seedCoreData();

    final buffer = StringBuffer('''
SELECT notes.*, folders.name AS folder_name
FROM ${DatabaseSchema.notesTable} notes
LEFT JOIN ${DatabaseSchema.foldersTable} folders
ON folders.id = notes.folder_id
''');

    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    switch (collection) {
      case NoteCollection.active:
        whereClauses.add('notes.is_deleted = 0 AND notes.is_archived = 0');
      case NoteCollection.archived:
        whereClauses.add('notes.is_deleted = 0 AND notes.is_archived = 1');
      case NoteCollection.trash:
        whereClauses.add('notes.is_deleted = 1');
    }

    if (folderId != null && folderId != 'all') {
      whereClauses.add('notes.folder_id = ?');
      whereArgs.add(folderId);
    }

    if (pinnedOnly) {
      whereClauses.add('notes.is_pinned = 1');
    }

    final query = searchQuery.trim();
    if (query.isNotEmpty) {
      whereClauses.add('(LOWER(COALESCE(notes.title, \'\')) LIKE ? OR LOWER(notes.body) LIKE ?)');
      final match = '%${query.toLowerCase()}%';
      whereArgs.add(match);
      whereArgs.add(match);
    }

    if (whereClauses.isNotEmpty) {
      buffer.write(' WHERE ${whereClauses.join(' AND ')}');
    }

    buffer.write(' ORDER BY notes.is_pinned DESC, notes.updated_at DESC LIMIT 100');

    final rows = await _database.rawQuery(buffer.toString(), whereArgs);

    return rows.map(NoteRecord.fromMap).map((note) => note.toPreview()).toList(growable: false);
  }

  @override
  Future<List<NoteFolder>> listFolders() async {
    await _seedCoreData();

    final rows = await _database.query(
      DatabaseSchema.foldersTable,
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(FolderRecord.fromMap).map((folder) => folder.toFolder()).toList(growable: false);
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
    String? folderId,
  }) async {
    final now = DateTime.now();
    final id = 'note-${now.microsecondsSinceEpoch}';
    final folder = await _folderForId(folderId);
    await upsert(
      NoteRecord(
        id: id,
        title: title,
        body: body,
        folderId: folder?.id,
        folderName: folder?.name,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  @override
  Future<NoteDocument?> getNote(String id) async {
    await _seedCoreData();

    final rows = await _database.rawQuery(
      '''
SELECT notes.*, folders.name AS folder_name
FROM ${DatabaseSchema.notesTable} notes
LEFT JOIN ${DatabaseSchema.foldersTable} folders
ON folders.id = notes.folder_id
WHERE notes.id = ?
LIMIT 1
''',
      [id],
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
    String? folderId,
  }) async {
    final existing = await getNote(id);
    if (existing == null) {
      return;
    }
    final folder = await _folderForId(folderId);

    final updated = NoteRecord(
      id: existing.id,
      title: title,
      body: body,
      folderId: folder?.id,
      folderName: folder?.name,
      isPinned: existing.isPinned,
      isArchived: existing.isArchived,
      isDeleted: existing.isDeleted,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: existing.deletedAt,
    );

    await _database.update(
      DatabaseSchema.notesTable,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> togglePin({
    required String id,
    required bool value,
  }) async {
    final existing = await getNote(id);
    if (existing == null) {
      return;
    }

    final updated = NoteRecord(
      id: existing.id,
      title: existing.title,
      body: existing.body,
      folderId: existing.folderId,
      isPinned: value,
      isArchived: existing.isArchived,
      isDeleted: existing.isDeleted,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: existing.deletedAt,
    );

    await _database.update(
      DatabaseSchema.notesTable,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> setArchived({
    required String id,
    required bool value,
  }) async {
    final existing = await getNote(id);
    if (existing == null) {
      return;
    }

    final updated = NoteRecord(
      id: existing.id,
      title: existing.title,
      body: existing.body,
      folderId: existing.folderId,
      isPinned: existing.isPinned,
      isArchived: value,
      isDeleted: false,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: null,
    );

    await _database.update(
      DatabaseSchema.notesTable,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> moveToTrash(String id) async {
    final existing = await getNote(id);
    if (existing == null) {
      return;
    }

    final updated = NoteRecord(
      id: existing.id,
      title: existing.title,
      body: existing.body,
      folderId: existing.folderId,
      isPinned: false,
      isArchived: false,
      isDeleted: true,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: DateTime.now(),
    );

    await _database.update(
      DatabaseSchema.notesTable,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> restoreFromTrash(String id) async {
    final existing = await getNote(id);
    if (existing == null) {
      return;
    }

    final updated = NoteRecord(
      id: existing.id,
      title: existing.title,
      body: existing.body,
      folderId: existing.folderId,
      isPinned: existing.isPinned,
      isArchived: false,
      isDeleted: false,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: null,
    );

    await _database.update(
      DatabaseSchema.notesTable,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deletePermanently(String id) {
    return _database.delete(
      DatabaseSchema.notesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _seedCoreData() async {
    await _database.seedIfEmpty(
      table: DatabaseSchema.foldersTable,
      rows: _seedFolders.map((folder) => folder.toMap()).toList(growable: false),
    );
    await _database.seedIfEmpty(
      table: DatabaseSchema.notesTable,
      rows: _seedNotes.map((note) => note.toMap()).toList(growable: false),
    );
  }

  Future<FolderRecord?> _folderForId(String? folderId) async {
    if (folderId == null) {
      return null;
    }
    await _seedCoreData();
    final rows = await _database.query(
      DatabaseSchema.foldersTable,
      where: 'id = ?',
      whereArgs: [folderId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return FolderRecord.fromMap(rows.first);
  }
}
