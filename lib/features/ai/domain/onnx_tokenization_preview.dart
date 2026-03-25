class OnnxTokenizationPreview {
  const OnnxTokenizationPreview({
    required this.ready,
    required this.inputIds,
    required this.attentionMask,
    required this.sequenceLength,
    this.message,
  });

  final bool ready;
  final List<int> inputIds;
  final List<int> attentionMask;
  final int sequenceLength;
  final String? message;
}
