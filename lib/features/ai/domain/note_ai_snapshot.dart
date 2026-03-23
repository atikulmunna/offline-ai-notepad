import 'embedding_status.dart';

class NoteAiSnapshot {
  const NoteAiSnapshot({
    required this.summary,
    required this.embeddingStatus,
    required this.modelVersion,
    required this.updatedAt,
  });

  final String? summary;
  final EmbeddingStatus embeddingStatus;
  final String? modelVersion;
  final DateTime? updatedAt;

  bool get hasSummary => summary != null && summary!.trim().isNotEmpty;
}
