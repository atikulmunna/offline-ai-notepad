class OnnxSummaryResponse {
  const OnnxSummaryResponse({
    required this.summary,
    required this.engine,
    this.usedInputNames = const [],
    this.usedOutputNames = const [],
    this.message,
  });

  final String summary;
  final String engine;
  final List<String> usedInputNames;
  final List<String> usedOutputNames;
  final String? message;
}
