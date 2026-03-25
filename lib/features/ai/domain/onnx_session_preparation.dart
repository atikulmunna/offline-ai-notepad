class OnnxSessionPreparation {
  const OnnxSessionPreparation({
    required this.nativeLibraryLinked,
    required this.modelExists,
    required this.tokenizerExists,
    required this.ready,
    required this.platform,
    this.modelPath,
    this.tokenizerPath,
    this.message,
  });

  final bool nativeLibraryLinked;
  final bool modelExists;
  final bool tokenizerExists;
  final bool ready;
  final String platform;
  final String? modelPath;
  final String? tokenizerPath;
  final String? message;
}
