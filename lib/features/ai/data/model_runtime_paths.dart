import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves the on-device directory where model files live at runtime.
///
/// Both the asset stager (for bundled models) and the downloader (for
/// on-demand models) write into the same `<app-support>/ai_models/<id>/`
/// layout so the native runtime finds files at a single, stable location.
class ModelRuntimePaths {
  const ModelRuntimePaths();

  /// The shared `ai_models` root, or null on platforms without a writable
  /// application-support directory (e.g. web).
  Future<String?> runtimeRoot() async {
    try {
      final supportDirectory = await getApplicationSupportDirectory();
      final root = p.join(supportDirectory.path, 'ai_models');
      await Directory(root).create(recursive: true);
      return root;
    } on MissingPluginException {
      return null;
    } on UnsupportedError {
      return null;
    }
  }

  /// The directory for a specific model id, created if needed. Null when no
  /// writable runtime root is available.
  Future<String?> modelDir(String modelId) async {
    final root = await runtimeRoot();
    if (root == null) {
      return null;
    }
    final dir = p.join(root, modelId);
    await Directory(dir).create(recursive: true);
    return dir;
  }
}
