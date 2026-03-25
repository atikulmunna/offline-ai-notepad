import 'local_model_installation.dart';

class LocalModelStage {
  const LocalModelStage({
    required this.installation,
    this.stagedModelPath,
    this.stagedTokenizerPath,
    this.runtimeDirectory,
    this.errorMessage,
  });

  final LocalModelInstallation installation;
  final String? stagedModelPath;
  final String? stagedTokenizerPath;
  final String? runtimeDirectory;
  final String? errorMessage;

  bool get isStaged {
    if (stagedModelPath == null) {
      return false;
    }
    if (installation.spec.tokenizerAssetPath != null &&
        stagedTokenizerPath == null) {
      return false;
    }
    return true;
  }
}
