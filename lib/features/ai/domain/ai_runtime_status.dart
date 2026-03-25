class AiRuntimeStatus {
  const AiRuntimeStatus({
    required this.runtimeLabel,
    required this.modelVersion,
    required this.isLocalOnly,
    required this.isReady,
    required this.packagedRuntimeReady,
    required this.nativeBackendLinked,
    required this.nativeSessionReady,
    required this.contractMatchesManifest,
    required this.summaryEnabled,
    required this.embeddingEnabled,
    required this.runtimeProfile,
    required this.packagedModels,
    required this.installedModels,
    required this.stagedModels,
    required this.totalModels,
    this.summaryModelId,
    this.embeddingModelId,
    this.runtimeDirectory,
    this.capabilityMessage,
    this.sessionMessage,
    this.contractMessage,
    this.tokenizationMessage,
    this.actualInputNames = const [],
    this.actualOutputNames = const [],
    this.previewInputIds = const [],
    this.previewAttentionMask = const [],
  });

  final String runtimeLabel;
  final String modelVersion;
  final bool isLocalOnly;
  final bool isReady;
  final bool packagedRuntimeReady;
  final bool nativeBackendLinked;
  final bool nativeSessionReady;
  final bool contractMatchesManifest;
  final bool summaryEnabled;
  final bool embeddingEnabled;
  final String runtimeProfile;
  final int packagedModels;
  final int installedModels;
  final int stagedModels;
  final int totalModels;
  final String? summaryModelId;
  final String? embeddingModelId;
  final String? runtimeDirectory;
  final String? capabilityMessage;
  final String? sessionMessage;
  final String? contractMessage;
  final String? tokenizationMessage;
  final List<String> actualInputNames;
  final List<String> actualOutputNames;
  final List<int> previewInputIds;
  final List<int> previewAttentionMask;
}
