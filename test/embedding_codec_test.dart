import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai_notepad/features/ai/data/embedding_codec.dart';

void main() {
  test('encode/decode round-trips a float32 vector exactly', () {
    final original = Float32List.fromList([0.0, 1.0, -1.0, 0.25, -0.125, 3.5]);

    final bytes = EmbeddingCodec.encode(original);
    final decoded = EmbeddingCodec.decode(bytes);

    expect(bytes.lengthInBytes, original.length * 4);
    expect(decoded.length, original.length);
    for (var i = 0; i < original.length; i++) {
      expect(decoded[i], original[i]);
    }
  });

  test('decode handles an empty vector', () {
    final decoded = EmbeddingCodec.decode(Uint8List(0));
    expect(decoded, isEmpty);
  });
}
