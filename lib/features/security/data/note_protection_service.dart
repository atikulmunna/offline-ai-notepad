import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_schema.dart';
import '../providers/app_lock_providers.dart';

final noteProtectionServiceProvider = Provider<NoteProtectionService>((ref) {
  return NoteProtectionService(ref);
});

class NoteProtectionService {
  NoteProtectionService(this._ref);

  final Ref _ref;
  final AesGcm _cipher = AesGcm.with256bits();
  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );

  static const _envelopePrefix = 'enc::';

  Future<bool> get isEnabled async {
    final settings = _ref.read(appLockControllerProvider.notifier).settings;
    return settings?.isEnabled ?? false;
  }

  Future<String?> protect(String? value) async {
    if (value == null) {
      return null;
    }

    if (!await isEnabled) {
      return value;
    }

    if (_looksEncrypted(value)) {
      return value;
    }

    final secretKey = await _secretKey();
    final secretBox = await _cipher.encrypt(
      utf8.encode(value),
      secretKey: secretKey,
    );
    final envelope = jsonEncode({
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    });
    return '$_envelopePrefix$envelope';
  }

  Future<String?> unprotect(String? value) async {
    if (value == null || value.isEmpty) {
      return value;
    }
    if (!_looksEncrypted(value)) {
      return value;
    }

    final secretKey = await _secretKey();
    final decoded = jsonDecode(value.substring(_envelopePrefix.length))
        as Map<String, dynamic>;
    final secretBox = SecretBox(
      base64Decode(decoded['cipherText'] as String),
      nonce: base64Decode(decoded['nonce'] as String),
      mac: Mac(base64Decode(decoded['mac'] as String)),
    );
    final clearBytes = await _cipher.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return utf8.decode(clearBytes);
  }

  Future<void> encryptExistingNotes(AppDatabase database) async {
    if (!await isEnabled) {
      return;
    }

    final rows = await database.query(DatabaseSchema.notesTable);
    for (final row in rows) {
      final body = row['body'] as String?;
      if (body == null || _looksEncrypted(body)) {
        continue;
      }
      await database.update(
        DatabaseSchema.notesTable,
        {
          'title': await protect(row['title'] as String?),
          'body': await protect(body),
          'body_delta': await protect(row['body_delta'] as String?),
          'summary': await protect(row['summary'] as String?),
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<void> decryptExistingNotes(AppDatabase database) async {
    final rows = await database.query(DatabaseSchema.notesTable);
    for (final row in rows) {
      final body = row['body'] as String?;
      if (body == null || !_looksEncrypted(body)) {
        continue;
      }
      await database.update(
        DatabaseSchema.notesTable,
        {
          'title': await unprotect(row['title'] as String?),
          'body': await unprotect(body),
          'body_delta': await unprotect(row['body_delta'] as String?),
          'summary': await unprotect(row['summary'] as String?),
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  bool _looksEncrypted(String value) => value.startsWith(_envelopePrefix);

  Future<SecretKey> _secretKey() async {
    final controller = _ref.read(appLockControllerProvider.notifier);
    final sessionPin = controller.sessionPin;
    final settings = controller.settings;

    if (sessionPin == null || settings?.saltBase64 == null) {
      throw StateError('A valid unlocked app-lock session is required.');
    }

    final key = await _pbkdf2.deriveKeyFromPassword(
      password: sessionPin,
      nonce: base64Decode(settings!.saltBase64!),
    );
    return key;
  }
}
