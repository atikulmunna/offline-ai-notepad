import 'dart:typed_data';

/// Packs/unpacks embedding vectors for compact BLOB storage in SQLite.
/// Vectors are stored little-endian as raw float32 bytes.
class EmbeddingCodec {
  const EmbeddingCodec._();

  static Uint8List encode(Float32List vector) {
    final bytes = ByteData(vector.length * 4);
    for (var i = 0; i < vector.length; i++) {
      bytes.setFloat32(i * 4, vector[i], Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  static Float32List decode(Uint8List bytes) {
    final count = bytes.lengthInBytes ~/ 4;
    final data = ByteData.sublistView(bytes);
    final vector = Float32List(count);
    for (var i = 0; i < count; i++) {
      vector[i] = data.getFloat32(i * 4, Endian.little);
    }
    return vector;
  }
}
