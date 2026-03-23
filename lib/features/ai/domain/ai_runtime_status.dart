class AiRuntimeStatus {
  const AiRuntimeStatus({
    required this.runtimeLabel,
    required this.modelVersion,
    required this.isLocalOnly,
    required this.isReady,
    required this.summaryEnabled,
    required this.embeddingEnabled,
  });

  final String runtimeLabel;
  final String modelVersion;
  final bool isLocalOnly;
  final bool isReady;
  final bool summaryEnabled;
  final bool embeddingEnabled;
}
