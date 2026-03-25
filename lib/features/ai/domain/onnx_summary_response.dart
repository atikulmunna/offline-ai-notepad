class OnnxSummaryResponse {
  const OnnxSummaryResponse({
    required this.summary,
    required this.engine,
    this.message,
  });

  final String summary;
  final String engine;
  final String? message;
}
