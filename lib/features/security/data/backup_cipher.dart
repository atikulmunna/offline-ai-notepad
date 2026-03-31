import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class BackupCipher {
  BackupCipher();

  final AesGcm _cipher = AesGcm.with256bits();
  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );

  Future<List<int>> encrypt({
    required List<int> clearBytes,
    required String passphrase,
  }) async {
    final salt = _randomBytes(16);
    final key = await _deriveKey(passphrase, salt);
    final box = await _cipher.encrypt(clearBytes, secretKey: key);
    final envelope = jsonEncode({
      'version': 1,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
    return utf8.encode(envelope);
  }

  Future<List<int>> decrypt({
    required List<int> encryptedBytes,
    required String passphrase,
  }) async {
    final decoded =
        jsonDecode(utf8.decode(encryptedBytes)) as Map<String, dynamic>;
    final salt = base64Decode(decoded['salt'] as String);
    final key = await _deriveKey(passphrase, salt);
    final box = SecretBox(
      base64Decode(decoded['cipherText'] as String),
      nonce: base64Decode(decoded['nonce'] as String),
      mac: Mac(base64Decode(decoded['mac'] as String)),
    );
    return _cipher.decrypt(box, secretKey: key);
  }

  Future<SecretKey> _deriveKey(String passphrase, List<int> salt) {
    return _pbkdf2.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
