/// Describes how an optional (non-bundled) model's files are fetched at runtime.
///
/// The binaries are hosted on a GitHub release rather than bundled in the APK,
/// so the app stays small and downloads the models on first use.
class ModelDownloadSpec {
  const ModelDownloadSpec({
    required this.baseUrl,
    required this.totalBytes,
    required this.files,
  });

  /// Base URL that each file's [ModelDownloadFile.remote] is appended to.
  final String baseUrl;

  /// Sum of every file's byte size — used for progress + the UI size hint.
  final int totalBytes;

  final List<ModelDownloadFile> files;

  factory ModelDownloadSpec.fromJson(Map<String, dynamic> json) {
    final rawFiles = (json['files'] as List<dynamic>? ?? const []);
    final files = rawFiles
        .map((item) => ModelDownloadFile.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    return ModelDownloadSpec(
      baseUrl: (json['base_url'] as String? ?? '').trim(),
      totalBytes:
          json['total_bytes'] as int? ?? files.fold(0, (sum, f) => sum + f.bytes),
      files: files,
    );
  }
}

class ModelDownloadFile {
  const ModelDownloadFile({
    required this.name,
    required this.remote,
    required this.sha256,
    required this.bytes,
  });

  /// Local filename the native runtime expects (e.g. `model.onnx`).
  final String name;

  /// Filename of the asset on the remote host (may be prefixed to avoid
  /// collisions between models that share a local name).
  final String remote;

  /// Lowercase hex SHA-256 of the file, verified after download.
  final String sha256;

  final int bytes;

  factory ModelDownloadFile.fromJson(Map<String, dynamic> json) {
    return ModelDownloadFile(
      name: json['name'] as String,
      remote: json['remote'] as String? ?? json['name'] as String,
      sha256: (json['sha256'] as String? ?? '').toLowerCase(),
      bytes: json['bytes'] as int? ?? 0,
    );
  }
}
