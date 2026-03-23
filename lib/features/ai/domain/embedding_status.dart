enum EmbeddingStatus {
  missing,
  queued,
  indexed,
  failed,
}

extension EmbeddingStatusX on EmbeddingStatus {
  String get dbValue => switch (this) {
        EmbeddingStatus.missing => 'missing',
        EmbeddingStatus.queued => 'queued',
        EmbeddingStatus.indexed => 'indexed',
        EmbeddingStatus.failed => 'failed',
      };

  String get label => switch (this) {
        EmbeddingStatus.missing => 'Not indexed',
        EmbeddingStatus.queued => 'Queued',
        EmbeddingStatus.indexed => 'Indexed',
        EmbeddingStatus.failed => 'Needs retry',
      };

  static EmbeddingStatus fromDb(String? value) {
    return switch (value) {
      'queued' => EmbeddingStatus.queued,
      'indexed' => EmbeddingStatus.indexed,
      'failed' => EmbeddingStatus.failed,
      _ => EmbeddingStatus.missing,
    };
  }
}
