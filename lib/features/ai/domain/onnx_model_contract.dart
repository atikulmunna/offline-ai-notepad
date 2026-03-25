class OnnxModelContract {
  const OnnxModelContract({
    required this.inputNames,
    required this.outputNames,
    required this.maxSequenceLength,
    this.tokenizerType,
  });

  final List<String> inputNames;
  final List<String> outputNames;
  final int maxSequenceLength;
  final String? tokenizerType;

  factory OnnxModelContract.fromJson(Map<String, dynamic> json) {
    return OnnxModelContract(
      inputNames: (json['input_names'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(growable: false),
      outputNames: (json['output_names'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(growable: false),
      maxSequenceLength: json['max_sequence_length'] as int? ?? 512,
      tokenizerType: json['tokenizer_type'] as String?,
    );
  }
}
