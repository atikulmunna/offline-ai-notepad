class OnnxRuntimeCapability {
  const OnnxRuntimeCapability({
    required this.bridgeAvailable,
    required this.nativeLibraryLinked,
    required this.platform,
    this.message,
  });

  final bool bridgeAvailable;
  final bool nativeLibraryLinked;
  final String platform;
  final String? message;

  bool get isUsable => bridgeAvailable && nativeLibraryLinked;
}
