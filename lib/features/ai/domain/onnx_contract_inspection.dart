class OnnxContractInspection {
  const OnnxContractInspection({
    required this.available,
    required this.matchesManifest,
    required this.actualInputNames,
    required this.actualOutputNames,
    this.message,
  });

  final bool available;
  final bool matchesManifest;
  final List<String> actualInputNames;
  final List<String> actualOutputNames;
  final String? message;
}
