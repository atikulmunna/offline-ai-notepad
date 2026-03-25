import 'local_model_spec.dart';

class LocalModelInstallation {
  const LocalModelInstallation({
    required this.spec,
    required this.modelAssetPresent,
    required this.tokenizerAssetPresent,
  });

  final LocalModelSpec spec;
  final bool modelAssetPresent;
  final bool tokenizerAssetPresent;

  bool get isInstalled {
    if (!modelAssetPresent) {
      return false;
    }
    if (spec.tokenizerAssetPath != null && !tokenizerAssetPresent) {
      return false;
    }
    return true;
  }
}
