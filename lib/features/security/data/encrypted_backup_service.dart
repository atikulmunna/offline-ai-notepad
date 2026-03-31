import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/database/database_schema.dart';
import 'backup_cipher.dart';
import 'note_protection_service.dart';

final encryptedBackupServiceProvider = Provider<EncryptedBackupService>((ref) {
  return EncryptedBackupService(
    database: ref.watch(appDatabaseProvider),
    protectionService: ref.watch(noteProtectionServiceProvider),
    cipher: BackupCipher(),
  );
});

class EncryptedBackupService {
  EncryptedBackupService({
    required AppDatabase database,
    required NoteProtectionService protectionService,
    required BackupCipher cipher,
  })  : _database = database,
        _protectionService = protectionService,
        _cipher = cipher;

  final AppDatabase _database;
  final NoteProtectionService _protectionService;
  final BackupCipher _cipher;

  Future<String> exportEncryptedBackup({
    required String passphrase,
  }) async {
    final payload = await _buildExportPayload();
    final encrypted = await _cipher.encrypt(
      clearBytes: utf8.encode(jsonEncode(payload)),
      passphrase: passphrase,
    );

    final directory = await getTemporaryDirectory();
    final fileName =
        'nativenote-backup-${DateTime.now().millisecondsSinceEpoch}.nnbak';
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(encrypted, flush: true);
    return file.path;
  }

  Future<void> shareBackupFile(String path) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: 'NativeNote encrypted backup',
      ),
    );
  }

  Future<bool> importEncryptedBackup({
    required String passphrase,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['nnbak', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return false;
    }

    final selected = result.files.single;
    final encryptedBytes = selected.bytes ??
        await File(selected.path!).readAsBytes();
    final clearBytes = await _cipher.decrypt(
      encryptedBytes: encryptedBytes,
      passphrase: passphrase,
    );
    final decoded =
        jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
    await _restoreFromPayload(decoded);
    return true;
  }

  Future<Map<String, Object?>> _buildExportPayload() async {
    final folderRows = await _database.query(DatabaseSchema.foldersTable);
    final noteRows = await _database.query(DatabaseSchema.notesTable);

    final exportedNotes = <Map<String, Object?>>[];
    for (final row in noteRows) {
      exportedNotes.add({
        'id': row['id'],
        'title': await _protectionService.unprotect(row['title'] as String?),
        'body': await _protectionService.unprotect(row['body'] as String?),
        'body_delta':
            await _protectionService.unprotect(row['body_delta'] as String?),
        'summary':
            await _protectionService.unprotect(row['summary'] as String?),
        'folder_id': row['folder_id'],
        'is_pinned': row['is_pinned'],
        'is_archived': row['is_archived'],
        'is_deleted': row['is_deleted'],
        'created_at': row['created_at'],
        'updated_at': row['updated_at'],
        'deleted_at': row['deleted_at'],
      });
    }

    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'folders': folderRows,
      'notes': exportedNotes,
    };
  }

  Future<void> _restoreFromPayload(Map<String, dynamic> payload) async {
    final folders = (payload['folders'] as List<dynamic>? ?? const []);
    final notes = (payload['notes'] as List<dynamic>? ?? const []);

    for (final folder in folders.cast<Map<String, dynamic>>()) {
      await _database.insert(
        DatabaseSchema.foldersTable,
        Map<String, Object?>.from(folder),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final note in notes.cast<Map<String, dynamic>>()) {
      final storedNote = {
        'id': note['id'],
        'title': await _protectionService.protect(note['title'] as String?),
        'body': await _protectionService.protect(note['body'] as String?),
        'body_delta':
            await _protectionService.protect(note['body_delta'] as String?),
        'summary':
            await _protectionService.protect(note['summary'] as String?),
        'folder_id': note['folder_id'],
        'is_pinned': note['is_pinned'],
        'is_archived': note['is_archived'],
        'is_deleted': note['is_deleted'],
        'created_at': note['created_at'],
        'updated_at': note['updated_at'],
        'deleted_at': note['deleted_at'],
      };
      await _database.insert(
        DatabaseSchema.notesTable,
        storedNote,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
