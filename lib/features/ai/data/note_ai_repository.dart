import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_schema.dart';
import '../../security/data/note_protection_service.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/embedding_status.dart';
import '../domain/note_ai_snapshot.dart';
import '../domain/note_embedding_metadata.dart';
import 'embedding_codec.dart';

class NoteAiRepository {
  NoteAiRepository(this._database, this._ref);

  final AppDatabase _database;
  final Ref _ref;

  Future<NoteAiSnapshot?> getSnapshot(String noteId) async {
    final noteRows = await _database.query(
      DatabaseSchema.notesTable,
      where: 'id = ?',
      whereArgs: [noteId],
      limit: 1,
    );
    if (noteRows.isEmpty) {
      return null;
    }

    final embeddingRows = await _database.query(
      DatabaseSchema.embeddingsTable,
      where: 'note_id = ?',
      whereArgs: [noteId],
      limit: 1,
    );

    final note = noteRows.first;
    final embedding = embeddingRows.isEmpty ? null : embeddingRows.first;

    final updatedMillis = embedding?['updated_at'] as int? ?? note['updated_at'] as int?;

    return NoteAiSnapshot(
      summary: await _ref
          .read(noteProtectionServiceProvider)
          .unprotect(note['summary'] as String?),
      embeddingStatus: EmbeddingStatusX.fromDb(embedding?['status'] as String?),
      modelVersion: embedding?['model_ver'] as String?,
      updatedAt: updatedMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(updatedMillis),
    );
  }

  Future<void> saveSummary({
    required String noteId,
    required String summary,
  }) async {
    final protectedSummary =
        await _ref.read(noteProtectionServiceProvider).protect(summary);
    await _database.update(
      DatabaseSchema.notesTable,
      {'summary': protectedSummary},
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  Future<void> saveEmbeddingMetadata(NoteEmbeddingMetadata metadata) {
    final vector = metadata.embedding;
    return _database.insert(
      DatabaseSchema.embeddingsTable,
      {
        'note_id': metadata.noteId,
        'model_ver': metadata.modelVersion,
        'status': metadata.status.dbValue,
        'embedding': vector == null ? null : EmbeddingCodec.encode(vector),
        'dim': metadata.dim,
        'created_at': metadata.createdAt.millisecondsSinceEpoch,
        'updated_at': metadata.updatedAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Loads decoded embedding vectors keyed by note id for every indexed note.
  /// Notes without a stored vector are omitted so callers fall back to lexical.
  Future<Map<String, Float32List>> loadAllEmbeddings() async {
    final rows = await _database.rawQuery(
      'SELECT note_id, embedding FROM ${DatabaseSchema.embeddingsTable} '
      'WHERE embedding IS NOT NULL',
    );
    final result = <String, Float32List>{};
    for (final row in rows) {
      final blob = row['embedding'];
      if (blob is Uint8List && blob.isNotEmpty) {
        result[row['note_id'] as String] = EmbeddingCodec.decode(blob);
      }
    }
    return result;
  }

  /// Marks a note's embedding as queued without discarding any vector already
  /// stored, so it stays searchable while a fresh vector is recomputed.
  Future<void> markEmbeddingQueued(String noteId, String modelVersion) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = await _database.update(
      DatabaseSchema.embeddingsTable,
      {'status': EmbeddingStatus.queued.dbValue, 'updated_at': now},
      where: 'note_id = ?',
      whereArgs: [noteId],
    );
    if (updated == 0) {
      await _database.insert(
        DatabaseSchema.embeddingsTable,
        {
          'note_id': noteId,
          'model_ver': modelVersion,
          'status': EmbeddingStatus.queued.dbValue,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Returns notes that need embedding (re)computation: never indexed, indexed
  /// under a different model version, or missing a stored vector. Title/body are
  /// decrypted so they can be fed straight to the indexer.
  Future<List<({String id, String? title, String body})>> notesNeedingEmbedding(
    String modelVersion, {
    int limit = 200,
  }) async {
    final rows = await _database.rawQuery(
      '''
SELECT notes.id, notes.title, notes.body
FROM ${DatabaseSchema.notesTable} notes
LEFT JOIN ${DatabaseSchema.embeddingsTable} emb ON emb.note_id = notes.id
WHERE notes.is_deleted = 0
  AND (
    emb.note_id IS NULL
    OR emb.status != ?
    OR emb.embedding IS NULL
    OR emb.model_ver != ?
  )
ORDER BY notes.updated_at DESC
LIMIT ?
''',
      [EmbeddingStatus.indexed.dbValue, modelVersion, limit],
    );

    final protection = _ref.read(noteProtectionServiceProvider);
    final result = <({String id, String? title, String body})>[];
    for (final row in rows) {
      result.add((
        id: row['id'] as String,
        title: await protection.unprotect(row['title'] as String?),
        body: (await protection.unprotect(row['body'] as String?)) ?? '',
      ));
    }
    return result;
  }

  Future<Float32List?> loadEmbedding(String noteId) async {
    final rows = await _database.rawQuery(
      'SELECT embedding FROM ${DatabaseSchema.embeddingsTable} '
      'WHERE note_id = ? AND embedding IS NOT NULL LIMIT 1',
      [noteId],
    );
    if (rows.isEmpty) {
      return null;
    }
    final blob = rows.first['embedding'];
    if (blob is Uint8List && blob.isNotEmpty) {
      return EmbeddingCodec.decode(blob);
    }
    return null;
  }
}
