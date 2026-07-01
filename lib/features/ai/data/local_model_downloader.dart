import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../domain/local_model_spec.dart';
import '../domain/model_download_spec.dart';
import 'model_runtime_paths.dart';

/// Progress callback: [received] and [total] are cumulative byte counts across
/// every file being downloaded in the current operation.
typedef ModelDownloadProgress = void Function(int received, int total);

/// Downloads on-demand model files (hosted on a GitHub release) into the shared
/// runtime directory, verifying each file's SHA-256 before it is committed.
class LocalModelDownloader {
  LocalModelDownloader({
    ModelRuntimePaths paths = const ModelRuntimePaths(),
    HttpClient Function()? httpClientFactory,
  })  : _paths = paths,
        _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final ModelRuntimePaths _paths;
  final HttpClient Function() _httpClientFactory;

  /// True when every file for [spec] is already present on disk at the expected
  /// size. A cheap check used to decide whether a download is needed.
  Future<bool> isDownloaded(LocalModelSpec spec) async {
    final download = spec.download;
    if (download == null) {
      return false;
    }
    final dir = await _paths.modelDir(spec.id);
    if (dir == null) {
      return false;
    }
    for (final file in download.files) {
      final target = File(p.join(dir, file.name));
      if (!await target.exists()) {
        return false;
      }
      if (file.bytes > 0 && await target.length() != file.bytes) {
        return false;
      }
    }
    return true;
  }

  /// The total bytes still to download for the given specs (files already
  /// present are excluded). Used to show an accurate size hint.
  Future<int> pendingBytes(Iterable<LocalModelSpec> specs) async {
    var total = 0;
    for (final spec in specs) {
      final download = spec.download;
      if (download == null) {
        continue;
      }
      final dir = await _paths.modelDir(spec.id);
      for (final file in download.files) {
        final target = dir == null ? null : File(p.join(dir, file.name));
        final present = target != null &&
            await target.exists() &&
            (file.bytes == 0 || await target.length() == file.bytes);
        if (!present) {
          total += file.bytes;
        }
      }
    }
    return total;
  }

  /// Downloads every not-yet-present file for [specs]. Throws on network or
  /// integrity failure; already-complete files are skipped.
  Future<void> downloadAll(
    List<LocalModelSpec> specs, {
    ModelDownloadProgress? onProgress,
  }) async {
    final downloadable =
        specs.where((spec) => spec.download != null).toList(growable: false);
    final total = downloadable.fold<int>(
      0,
      (sum, spec) => sum + spec.download!.totalBytes,
    );

    final client = _httpClientFactory();
    var completedBytes = 0;
    try {
      for (final spec in downloadable) {
        final dir = await _paths.modelDir(spec.id);
        if (dir == null) {
          throw const ModelDownloadException(
            'No writable storage available for model downloads.',
          );
        }
        for (final file in spec.download!.files) {
          final target = File(p.join(dir, file.name));
          if (await _isValid(target, file)) {
            completedBytes += file.bytes;
            onProgress?.call(completedBytes, total);
            continue;
          }
          await _downloadFile(
            client: client,
            spec: spec.download!,
            file: file,
            target: target,
            onChunk: (chunk) {
              completedBytes += chunk;
              onProgress?.call(completedBytes, total);
            },
          );
        }
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _isValid(File target, ModelDownloadFile file) async {
    if (!await target.exists()) {
      return false;
    }
    if (file.bytes > 0 && await target.length() != file.bytes) {
      return false;
    }
    return true;
  }

  Future<void> _downloadFile({
    required HttpClient client,
    required ModelDownloadSpec spec,
    required ModelDownloadFile file,
    required File target,
    required void Function(int chunk) onChunk,
  }) async {
    final url = Uri.parse('${spec.baseUrl}${file.remote}');
    final partFile = File('${target.path}.part');
    if (await partFile.exists()) {
      await partFile.delete();
    }

    final request = await client.getUrl(url);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw ModelDownloadException(
        'Download failed for ${file.name} (HTTP ${response.statusCode}).',
      );
    }

    final sink = partFile.openWrite();
    final digestSink = _DigestSink();
    final digestInput = sha256.startChunkedConversion(digestSink);
    try {
      await for (final chunk in response) {
        sink.add(chunk);
        digestInput.add(chunk);
        onChunk(chunk.length);
      }
      await sink.flush();
    } finally {
      await sink.close();
      digestInput.close();
    }

    final actual = digestSink.value.toString();
    if (file.sha256.isNotEmpty && actual != file.sha256) {
      await partFile.delete();
      throw ModelDownloadException(
        'Checksum mismatch for ${file.name}. Expected ${file.sha256}, got $actual.',
      );
    }

    if (await target.exists()) {
      await target.delete();
    }
    await partFile.rename(target.path);
  }
}

class ModelDownloadException implements Exception {
  const ModelDownloadException(this.message);
  final String message;
  @override
  String toString() => 'ModelDownloadException: $message';
}

/// Captures the final [Digest] from a chunked SHA-256 conversion without
/// pulling in `package:convert` just for `AccumulatorSink`.
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
