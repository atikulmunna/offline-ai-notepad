import 'local_model_task.dart';

class LocalModelSpec {
  const LocalModelSpec({
    required this.id,
    required this.task,
    required this.format,
    required this.backend,
    required this.assetPath,
    required this.packaged,
    required this.optionalDownload,
    required this.maxInputChars,
    this.tokenizerAssetPath,
    this.notes,
  });

  final String id;
  final LocalModelTask task;
  final String format;
  final String backend;
  final String assetPath;
  final String? tokenizerAssetPath;
  final bool packaged;
  final bool optionalDownload;
  final int maxInputChars;
  final String? notes;

  factory LocalModelSpec.fromJson(Map<String, dynamic> json) {
    return LocalModelSpec(
      id: json['id'] as String,
      task: LocalModelTaskX.fromJson(json['task'] as String),
      format: json['format'] as String,
      backend: json['backend'] as String,
      assetPath: json['asset_path'] as String,
      tokenizerAssetPath: json['tokenizer_asset_path'] as String?,
      packaged: json['packaged'] as bool? ?? false,
      optionalDownload: json['optional_download'] as bool? ?? false,
      maxInputChars: json['max_input_chars'] as int? ?? 4000,
      notes: json['notes'] as String?,
    );
  }
}
