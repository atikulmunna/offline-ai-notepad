import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_schema.dart';
import '../../security/data/note_protection_service.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/embedding_status.dart';
import '../domain/note_ai_snapshot.dart';
import '../domain/note_embedding_metadata.dart';

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
    return _database.insert(
      DatabaseSchema.embeddingsTable,
      {
        'note_id': metadata.noteId,
        'model_ver': metadata.modelVersion,
        'status': metadata.status.dbValue,
        'created_at': metadata.createdAt.millisecondsSinceEpoch,
        'updated_at': metadata.updatedAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
