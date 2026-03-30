import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/local_model_installation.dart';
import '../domain/local_model_stage.dart';

class LocalModelAssetStager {
  const LocalModelAssetStager({
    AssetBundle? bundle,
  }) : _bundle = bundle;

  final AssetBundle? _bundle;

  Future<List<LocalModelStage>> stageAll(
    List<LocalModelInstallation> installations,
  ) async {
    if (installations.isEmpty) {
      return const [];
    }

    String? runtimeDirectory;
    try {
      final supportDirectory = await getApplicationSupportDirectory();
      runtimeDirectory = p.join(supportDirectory.path, 'ai_models');
      await Directory(runtimeDirectory).create(recursive: true);
    } on MissingPluginException {
      runtimeDirectory = null;
    } on UnsupportedError {
      runtimeDirectory = null;
    }

    final results = <LocalModelStage>[];
    for (final installation in installations) {
      if (!installation.isInstalled) {
        results.add(LocalModelStage(
          installation: installation,
          runtimeDirectory: runtimeDirectory,
          errorMessage: 'Model assets are not bundled yet.',
        ));
        continue;
      }

      if (runtimeDirectory == null) {
        results.add(LocalModelStage(
          installation: installation,
          errorMessage: 'Writable runtime directory unavailable.',
        ));
        continue;
      }

      results.add(
        await _stageSingle(
          installation: installation,
          runtimeDirectory: runtimeDirectory,
        ),
      );
    }
    return results;
  }

  Future<LocalModelStage> _stageSingle({
    required LocalModelInstallation installation,
    required String runtimeDirectory,
  }) async {
    final bundle = _bundle ?? rootBundle;
    final modelDir = p.join(runtimeDirectory, installation.spec.id);
    await Directory(modelDir).create(recursive: true);

    try {
      final stagedModelPath = await _copyAsset(
        bundle: bundle,
        assetPath: installation.spec.assetPath,
        targetDirectory: modelDir,
      );
      String? stagedTokenizerPath;
      if (installation.spec.tokenizerAssetPath != null) {
        stagedTokenizerPath = await _copyAsset(
          bundle: bundle,
          assetPath: installation.spec.tokenizerAssetPath!,
          targetDirectory: modelDir,
        );
      }
      await _copyCompanionAssets(
        bundle: bundle,
        installation: installation,
        targetDirectory: modelDir,
      );

      return LocalModelStage(
        installation: installation,
        stagedModelPath: stagedModelPath,
        stagedTokenizerPath: stagedTokenizerPath,
        runtimeDirectory: modelDir,
      );
    } catch (error) {
      return LocalModelStage(
        installation: installation,
        runtimeDirectory: modelDir,
        errorMessage: '$error',
      );
    }
  }

  Future<void> _copyCompanionAssets({
    required AssetBundle bundle,
    required LocalModelInstallation installation,
    required String targetDirectory,
  }) async {
    final modelAssetDirectory = p.dirname(installation.spec.assetPath);
    final companionAssetPaths = <String>{
      p.join(modelAssetDirectory, 'encoder_model.onnx'),
      p.join(modelAssetDirectory, 'config.json'),
      p.join(modelAssetDirectory, 'tokenizer_config.json'),
      p.join(modelAssetDirectory, 'generation_config.json'),
      p.join(modelAssetDirectory, 'special_tokens_map.json'),
      p.join(modelAssetDirectory, 'spiece.model'),
    };

    companionAssetPaths.remove(installation.spec.assetPath);
    if (installation.spec.tokenizerAssetPath != null) {
      companionAssetPaths.remove(installation.spec.tokenizerAssetPath);
    }

    for (final assetPath in companionAssetPaths) {
      try {
        await _copyAsset(
          bundle: bundle,
          assetPath: assetPath,
          targetDirectory: targetDirectory,
        );
      } catch (_) {
        // Some model folders may not provide every companion file.
      }
    }
  }

  Future<String> _copyAsset({
    required AssetBundle bundle,
    required String assetPath,
    required String targetDirectory,
  }) async {
    final bytes = await bundle.load(assetPath);
    final targetPath = p.join(targetDirectory, p.basename(assetPath));
    final file = File(targetPath);
    await file.create(recursive: true);
    await file.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    return file.path;
  }
}
