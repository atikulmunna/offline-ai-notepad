class OnnxTokenizerInspection {
  const OnnxTokenizerInspection({
    required this.available,
    required this.vocabSize,
    this.modelType,
    this.preTokenizerType,
    this.normalizerType,
    this.message,
  });

  final bool available;
  final int vocabSize;
  final String? modelType;
  final String? preTokenizerType;
  final String? normalizerType;
  final String? message;
}
