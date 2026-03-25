enum LocalModelTask {
  summarization,
  embedding,
}

extension LocalModelTaskX on LocalModelTask {
  String get jsonValue => switch (this) {
        LocalModelTask.summarization => 'summarization',
        LocalModelTask.embedding => 'embedding',
      };

  String get label => switch (this) {
        LocalModelTask.summarization => 'Summarization',
        LocalModelTask.embedding => 'Embeddings',
      };

  static LocalModelTask fromJson(String value) {
    return switch (value) {
      'embedding' => LocalModelTask.embedding,
      _ => LocalModelTask.summarization,
    };
  }
}
