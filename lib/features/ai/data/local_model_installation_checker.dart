import 'package:flutter/services.dart';

import '../domain/local_model_installation.dart';
import '../domain/local_model_manifest.dart';

class LocalModelInstallationChecker {
  const LocalModelInstallationChecker({
    AssetBundle? bundle,
  }) : _bundle = bundle;

  final AssetBundle? _bundle;

  Future<List<LocalModelInstallation>> check(LocalModelManifest manifest) async {
    final bundle = _bundle ?? rootBundle;
    final assetManifest = await AssetManifest.loadFromAssetBundle(bundle);

    return manifest.models.map((spec) {
      final modelAssetPresent = assetManifest.listAssets().contains(spec.assetPath);
      final tokenizerAssetPresent = spec.tokenizerAssetPath == null
          ? true
          : assetManifest.listAssets().contains(spec.tokenizerAssetPath!);

      return LocalModelInstallation(
        spec: spec,
        modelAssetPresent: modelAssetPresent,
        tokenizerAssetPresent: tokenizerAssetPresent,
      );
    }).toList(growable: false);
  }
}
