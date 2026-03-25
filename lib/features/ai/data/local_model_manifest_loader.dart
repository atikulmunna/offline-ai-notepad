import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/local_model_manifest.dart';

class LocalModelManifestLoader {
  const LocalModelManifestLoader({
    AssetBundle? bundle,
    this.assetPath = 'assets/models/manifest.json',
  }) : _bundle = bundle;

  final AssetBundle? _bundle;
  final String assetPath;

  Future<LocalModelManifest> load() async {
    final bundle = _bundle ?? rootBundle;
    final raw = await bundle.loadString(assetPath);
    return LocalModelManifest.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }
}
