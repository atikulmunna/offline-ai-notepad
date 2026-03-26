class OnnxRunPreview {
  const OnnxRunPreview({
    required this.ready,
    required this.outputNames,
    required this.outputShapes,
    this.message,
  });

  final bool ready;
  final List<String> outputNames;
  final List<String> outputShapes;
  final String? message;
}
