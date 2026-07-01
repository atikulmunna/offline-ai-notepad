import 'package:flutter/services.dart';

import '../domain/local_model_installation.dart';
import '../domain/local_model_manifest.dart';
import '../domain/local_model_spec.dart';
import 'local_model_downloader.dart';

class LocalModelInstallationChecker {
  LocalModelInstallationChecker({
    AssetBundle? bundle,
    LocalModelDownloader? downloader,
  })  : _bundle = bundle,
        _downloader = downloader ?? LocalModelDownloader();

  final AssetBundle? _bundle;
  final LocalModelDownloader _downloader;

  Future<List<LocalModelInstallation>> check(LocalModelManifest manifest) async {
    final bundle = _bundle ?? rootBundle;
    final assetManifest = await AssetManifest.loadFromAssetBundle(bundle);
    final assets = assetManifest.listAssets();

    final installations = <LocalModelInstallation>[];
    for (final spec in manifest.models) {
      installations.add(await _checkSpec(spec, assets));
    }
    return installations;
  }

  Future<LocalModelInstallation> _checkSpec(
    LocalModelSpec spec,
    List<String> assets,
  ) async {
    // On-demand models are "installed" once their files have been downloaded
    // into the runtime directory, not when they exist in the asset bundle.
    if (spec.isDownloadable) {
      final downloaded = await _downloader.isDownloaded(spec);
      return LocalModelInstallation(
        spec: spec,
        modelAssetPresent: downloaded,
        tokenizerAssetPresent: downloaded,
      );
    }

    final modelAssetPresent = assets.contains(spec.assetPath);
    final tokenizerAssetPresent = spec.tokenizerAssetPath == null
        ? true
        : assets.contains(spec.tokenizerAssetPath!);

    return LocalModelInstallation(
      spec: spec,
      modelAssetPresent: modelAssetPresent,
      tokenizerAssetPresent: tokenizerAssetPresent,
    );
  }
}
