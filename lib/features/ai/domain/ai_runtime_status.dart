class AiRuntimeStatus {
  const AiRuntimeStatus({
    required this.runtimeLabel,
    required this.modelVersion,
    required this.isLocalOnly,
    required this.isReady,
    required this.packagedRuntimeReady,
    required this.summaryEnabled,
    required this.embeddingEnabled,
    required this.runtimeProfile,
    required this.packagedModels,
    required this.installedModels,
    required this.totalModels,
    this.summaryModelId,
    this.embeddingModelId,
  });

  final String runtimeLabel;
  final String modelVersion;
  final bool isLocalOnly;
  final bool isReady;
  final bool packagedRuntimeReady;
  final bool summaryEnabled;
  final bool embeddingEnabled;
  final String runtimeProfile;
  final int packagedModels;
  final int installedModels;
  final int totalModels;
  final String? summaryModelId;
  final String? embeddingModelId;
}
