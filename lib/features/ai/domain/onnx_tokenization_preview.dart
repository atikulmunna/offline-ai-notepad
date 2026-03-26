class OnnxTokenizationPreview {
  const OnnxTokenizationPreview({
    required this.ready,
    required this.tokenizerLoaded,
    required this.inputIds,
    required this.attentionMask,
    required this.sequenceLength,
    this.message,
  });

  final bool ready;
  final bool tokenizerLoaded;
  final List<int> inputIds;
  final List<int> attentionMask;
  final int sequenceLength;
  final String? message;
}
