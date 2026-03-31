import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai_notepad/features/security/data/backup_cipher.dart';

void main() {
  test('backup cipher round-trips with the same passphrase', () async {
    final cipher = BackupCipher();
    final source = utf8.encode('native note backup payload');

    final encrypted = await cipher.encrypt(
      clearBytes: source,
      passphrase: 'purple-secret',
    );
    final decrypted = await cipher.decrypt(
      encryptedBytes: encrypted,
      passphrase: 'purple-secret',
    );

    expect(utf8.decode(decrypted), 'native note backup payload');
  });

  test('backup cipher rejects the wrong passphrase', () async {
    final cipher = BackupCipher();
    final encrypted = await cipher.encrypt(
      clearBytes: utf8.encode('private notes'),
      passphrase: 'right-passphrase',
    );

    expect(
      () => cipher.decrypt(
        encryptedBytes: encrypted,
        passphrase: 'wrong-passphrase',
      ),
      throwsA(isA<Object>()),
    );
  });
}
