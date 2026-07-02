import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_schema.dart';
import '../../ai/providers/ai_providers.dart';
import '../../security/data/note_protection_service.dart';
import '../domain/note_collection.dart';
import '../domain/note_document.dart';
import '../domain/note_folder.dart';
import '../domain/note_preview.dart';
import '../domain/note_search_mode.dart';
import '../domain/note_tag.dart';
import '../domain/notes_repository.dart';
import 'folder_record.dart';
import 'note_record.dart';
import 'semantic_note_search.dart';
import 'vector_note_search.dart';

class LocalNotesRepository implements NotesRepository {
  LocalNotesRepository(this._database, this._ref);

  final AppDatabase _database;
  final Ref _ref;

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
    NoteSearchMode searchMode = NoteSearchMode.keyword,
    String? folderId,
    String? tagId,
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

    if (tagId != null) {
      buffer.write(
        'JOIN ${DatabaseSchema.noteTagsTable} nt ON nt.note_id = notes.id\n',
      );
      whereClauses.add('nt.tag_id = ?');
      whereArgs.add(tagId);
    }

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

    if (whereClauses.isNotEmpty) {
      buffer.write(' WHERE ${whereClauses.join(' AND ')}');
    }

    buffer.write(' ORDER BY notes.is_pinned DESC, notes.updated_at DESC LIMIT 100');

    final rows = await _database.rawQuery(buffer.toString(), whereArgs);
    final notes = <NoteRecord>[];
    for (final row in rows) {
      notes.add(await _readRecord(NoteRecord.fromMap(row)));
    }

    final List<NotePreview> previews;
    if (query.isEmpty) {
      previews = notes.map((note) => note.toPreview()).toList(growable: false);
    } else if (searchMode == NoteSearchMode.semantic) {
      previews = await _rankSemantic(notes, query);
    } else {
      previews = notes
          .where((note) {
            final haystack =
                '${note.title ?? ''}\n${note.body}\n${note.summary ?? ''}'
                    .toLowerCase();
            return haystack.contains(query.toLowerCase());
          })
          .map((note) => note.toPreview())
          .toList(growable: false);
    }

    return _attachTags(previews);
  }

  /// Ranks notes by meaning. Prefers native vector (cosine) similarity when an
  /// embedding runtime is available, then appends lexically-matched notes that
  /// lack a vector yet (e.g. pending backfill). Falls back entirely to the
  /// lexical [SemanticNoteSearch] when the query cannot be embedded.
  Future<List<NotePreview>> _rankSemantic(
    List<NoteRecord> notes,
    String query,
  ) async {
    final previews = notes.map((note) => note.toPreview()).toList(growable: false);

    final embedder = await _ref.read(noteQueryEmbedderProvider.future);
    final queryVector = await embedder?.embedQuery(query);

    if (queryVector != null && queryVector.isNotEmpty) {
      final allVectors =
          await _ref.read(noteAiRepositoryProvider).loadAllEmbeddings();
      final vectors = <String, Float32List>{};
      for (final preview in previews) {
        final vector = allVectors[preview.id];
        if (vector != null && vector.length == queryVector.length) {
          vectors[preview.id] = vector;
        }
      }

      if (vectors.isNotEmpty) {
        final withVector =
            previews.where((preview) => vectors.containsKey(preview.id));
        final withoutVector =
            previews.where((preview) => !vectors.containsKey(preview.id));
        final ranked = VectorNoteSearch.cosineRank(
          noteVectors: vectors,
          queryVector: queryVector,
          notes: withVector,
        );
        final lexicalRest = SemanticNoteSearch.rank(
          notes: withoutVector,
          query: query,
        );
        return [...ranked, ...lexicalRest];
      }
    }

    return SemanticNoteSearch.rank(notes: previews, query: query);
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

  @override
  Future<NoteFolder> createFolder(String name) async {
    final now = DateTime.now();
    final folder = FolderRecord(
      id: 'folder-${now.microsecondsSinceEpoch}',
      name: name.trim(),
      icon: 'folder',
      createdAt: now,
    );
    await _database.insert(
      DatabaseSchema.foldersTable,
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return folder.toFolder();
  }

  @override
  Future<NoteFolder?> renameFolder({
    required String id,
    required String name,
  }) async {
    await _seedCoreData();
    final rows = await _database.query(
      DatabaseSchema.foldersTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }

    final existing = FolderRecord.fromMap(rows.first);
    final updated = FolderRecord(
      id: existing.id,
      name: name.trim(),
      icon: existing.icon,
      createdAt: existing.createdAt,
    );
    await _database.update(
      DatabaseSchema.foldersTable,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    return updated.toFolder();
  }

  @override
  Future<List<NoteTag>> listTags() async {
    final rows = await _database.query(
      DatabaseSchema.tagsTable,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(_tagFromRow).toList(growable: false);
  }

  @override
  Future<NoteTag> getOrCreateTag(String name) async {
    final trimmed = name.trim();
    final existing = await _database.query(
      DatabaseSchema.tagsTable,
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return _tagFromRow(existing.first);
    }

    final tag = NoteTag(
      id: 'tag-${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      colorHex: _colorForName(trimmed),
    );
    await _database.insert(
      DatabaseSchema.tagsTable,
      {
        'id': tag.id,
        'name': tag.name,
        'color_hex': tag.colorHex,
        'is_custom': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return tag;
  }

  @override
  Future<void> setNoteTags({
    required String noteId,
    required List<String> tagIds,
  }) async {
    await _database.delete(
      DatabaseSchema.noteTagsTable,
      where: 'note_id = ?',
      whereArgs: [noteId],
    );
    for (final tagId in tagIds.toSet()) {
      await _database.insert(
        DatabaseSchema.noteTagsTable,
        {'note_id': noteId, 'tag_id': tagId, 'source': 'user'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Batch-loads tags for the given note ids, keyed by note id.
  Future<Map<String, List<NoteTag>>> _tagsForNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) {
      return const {};
    }
    final placeholders = List.filled(noteIds.length, '?').join(',');
    final rows = await _database.rawQuery(
      '''
SELECT nt.note_id AS note_id, t.id AS id, t.name AS name, t.color_hex AS color_hex
FROM ${DatabaseSchema.noteTagsTable} nt
JOIN ${DatabaseSchema.tagsTable} t ON t.id = nt.tag_id
WHERE nt.note_id IN ($placeholders)
ORDER BY t.name COLLATE NOCASE ASC
''',
      noteIds,
    );

    final result = <String, List<NoteTag>>{};
    for (final row in rows) {
      final noteId = row['note_id'] as String;
      (result[noteId] ??= <NoteTag>[]).add(_tagFromRow(row));
    }
    return result;
  }

  Future<List<NotePreview>> _attachTags(List<NotePreview> previews) async {
    if (previews.isEmpty) {
      return previews;
    }
    final tags = await _tagsForNotes(
      previews.map((preview) => preview.id).toList(growable: false),
    );
    return previews
        .map((preview) => preview.withTags(tags[preview.id] ?? const []))
        .toList(growable: false);
  }

  NoteTag _tagFromRow(Map<String, Object?> row) {
    return NoteTag(
      id: row['id'] as String,
      name: row['name'] as String,
      colorHex: (row['color_hex'] as String?) ?? '#607D8B',
    );
  }

  static const _tagPalette = [
    '#E57373',
    '#F06292',
    '#BA68C8',
    '#7986CB',
    '#4FC3F7',
    '#4DB6AC',
    '#81C784',
    '#FFB74D',
    '#A1887F',
    '#90A4AE',
  ];

  String _colorForName(String name) {
    if (name.isEmpty) {
      return '#607D8B';
    }
    final hash = name.toLowerCase().codeUnits.fold<int>(0, (a, b) => a + b);
    return _tagPalette[hash % _tagPalette.length];
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
    String? bodyDelta,
    String? folderId,
  }) async {
    final now = DateTime.now();
    final id = 'note-${now.microsecondsSinceEpoch}';
    final folder = await _folderForId(folderId);
    await upsert(await _writeRecord(
      NoteRecord(
        id: id,
        title: title,
        body: body,
        bodyDelta: bodyDelta,
        folderId: folder?.id,
        folderName: folder?.name,
        createdAt: now,
        updatedAt: now,
      ),
    ));
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

    final record = await _readRecord(NoteRecord.fromMap(rows.first));
    final tags = await _tagsForNotes([record.id]);
    return record.toDocument(tags: tags[record.id] ?? const []);
  }

  @override
  Future<void> updateNote({
    required String id,
    String? title,
    required String body,
    String? bodyDelta,
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
      bodyDelta: bodyDelta,
      summary: existing.summary,
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
      (await _writeRecord(updated)).toMap(),
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
      bodyDelta: existing.bodyDelta,
      summary: existing.summary,
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
      (await _writeRecord(updated)).toMap(),
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
      bodyDelta: existing.bodyDelta,
      summary: existing.summary,
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
      (await _writeRecord(updated)).toMap(),
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
      bodyDelta: existing.bodyDelta,
      summary: existing.summary,
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
      (await _writeRecord(updated)).toMap(),
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
      bodyDelta: existing.bodyDelta,
      summary: existing.summary,
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
      (await _writeRecord(updated)).toMap(),
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

  Future<NoteRecord> _readRecord(NoteRecord record) async {
    final protection = _ref.read(noteProtectionServiceProvider);
    return NoteRecord(
      id: record.id,
      title: await protection.unprotect(record.title),
      body: (await protection.unprotect(record.body)) ?? '',
      bodyDelta: await protection.unprotect(record.bodyDelta),
      summary: await protection.unprotect(record.summary),
      folderId: record.folderId,
      folderName: record.folderName,
      isPinned: record.isPinned,
      isArchived: record.isArchived,
      isDeleted: record.isDeleted,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      deletedAt: record.deletedAt,
    );
  }

  Future<NoteRecord> _writeRecord(NoteRecord record) async {
    final protection = _ref.read(noteProtectionServiceProvider);
    return NoteRecord(
      id: record.id,
      title: await protection.protect(record.title),
      body: (await protection.protect(record.body)) ?? record.body,
      bodyDelta: await protection.protect(record.bodyDelta),
      summary: await protection.protect(record.summary),
      folderId: record.folderId,
      folderName: record.folderName,
      isPinned: record.isPinned,
      isArchived: record.isArchived,
      isDeleted: record.isDeleted,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      deletedAt: record.deletedAt,
    );
  }
}
