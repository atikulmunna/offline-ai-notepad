import 'dart:typed_data';

import '../domain/embedding_status.dart';
import '../domain/local_model_stage.dart';
import '../domain/note_embedding_indexer.dart';
import '../domain/note_embedding_metadata.dart';
import '../domain/note_query_embedder.dart';
import '../domain/onnx_runtime_capability.dart';
import 'onnx_method_channel_client.dart';

/// Computes real sentence embeddings through the native ONNX bridge
/// (all-MiniLM-L6-v2). Falls back to [_fallback] when the native runtime or a
/// staged embedding model is unavailable, or when inference returns nothing.
class OnnxNoteEmbeddingIndexer
    implements NoteEmbeddingIndexer, NoteQueryEmbedder {
  OnnxNoteEmbeddingIndexer({
    required OnnxMethodChannelClient methodChannelClient,
    required LocalModelStage? embeddingStage,
    required OnnxRuntimeCapability capability,
    required NoteEmbeddingIndexer fallback,
  })  : _client = methodChannelClient,
        _embeddingStage = embeddingStage,
        _capability = capability,
        _fallback = fallback;

  /// Bump when the embedding model or tokenization changes so existing notes are
  /// re-indexed (their stored vectors become stale against this version).
  static const modelVersion = 'minilm-l6-v2-onnx-v1';

  final OnnxMethodChannelClient _client;
  final LocalModelStage? _embeddingStage;
  final OnnxRuntimeCapability _capability;
  final NoteEmbeddingIndexer _fallback;

  @override
  Future<NoteEmbeddingMetadata> indexNote({
    required String noteId,
    String? title,
    required String body,
  }) async {
    final vector = await _embed(_composeText(title, body));
    if (vector != null && vector.isNotEmpty) {
      final now = DateTime.now();
      return NoteEmbeddingMetadata(
        noteId: noteId,
        status: EmbeddingStatus.indexed,
        modelVersion: modelVersion,
        embedding: vector,
        dim: vector.length,
        createdAt: now,
        updatedAt: now,
      );
    }

    return _fallback.indexNote(noteId: noteId, title: title, body: body);
  }

  @override
  Future<Float32List?> embedQuery(String text) => _embed(text.trim());

  Future<Float32List?> _embed(String text) async {
    final stage = _embeddingStage;
    if (text.isEmpty ||
        !_capability.isUsable ||
        stage == null ||
        !stage.isStaged ||
        stage.stagedModelPath == null) {
      return null;
    }
    final contract = stage.installation.spec.onnxContract;
    final vector = await _client.generateEmbedding(
      modelPath: stage.stagedModelPath!,
      tokenizerPath: stage.stagedTokenizerPath,
      text: text,
      maxSequenceLength: contract?.maxSequenceLength,
    );
    if (vector == null || vector.isEmpty) {
      return null;
    }
    return Float32List.fromList(vector);
  }

  String _composeText(String? title, String body) {
    final trimmedTitle = title?.trim() ?? '';
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty) {
      return trimmedBody;
    }
    if (trimmedBody.isEmpty) {
      return trimmedTitle;
    }
    return '$trimmedTitle\n$trimmedBody';
  }
}
