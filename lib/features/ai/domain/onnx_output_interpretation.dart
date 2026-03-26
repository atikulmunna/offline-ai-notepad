class OnnxOutputInterpretation {
  const OnnxOutputInterpretation({
    required this.available,
    required this.decoderType,
    required this.canAttemptDecode,
    this.message,
  });

  final bool available;
  final String decoderType;
  final bool canAttemptDecode;
  final String? message;
}
