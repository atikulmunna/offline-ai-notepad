class OnnxModelContract {
  const OnnxModelContract({
    required this.inputNames,
    required this.outputNames,
    required this.maxSequenceLength,
    this.tokenizerType,
    this.decoderType,
    this.supportsGreedyDecode = false,
    this.padTokenId,
    this.unkTokenId,
    this.bosTokenId,
    this.eosTokenId,
  });

  final List<String> inputNames;
  final List<String> outputNames;
  final int maxSequenceLength;
  final String? tokenizerType;
  final String? decoderType;
  final bool supportsGreedyDecode;
  final int? padTokenId;
  final int? unkTokenId;
  final int? bosTokenId;
  final int? eosTokenId;

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
      decoderType: json['decoder_type'] as String?,
      supportsGreedyDecode: json['supports_greedy_decode'] as bool? ?? false,
      padTokenId: json['pad_token_id'] as int?,
      unkTokenId: json['unk_token_id'] as int?,
      bosTokenId: json['bos_token_id'] as int?,
      eosTokenId: json['eos_token_id'] as int?,
    );
  }
}
