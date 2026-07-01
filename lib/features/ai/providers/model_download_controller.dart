import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_providers.dart';

enum ModelDownloadStatus { idle, downloading, completed, failed }

class ModelDownloadState {
  const ModelDownloadState({
    this.status = ModelDownloadStatus.idle,
    this.received = 0,
    this.total = 0,
    this.error,
  });

  final ModelDownloadStatus status;
  final int received;
  final int total;
  final String? error;

  bool get isDownloading => status == ModelDownloadStatus.downloading;

  /// 0..1 progress fraction, or null when the total is not yet known.
  double? get fraction {
    if (total <= 0) {
      return null;
    }
    return (received / total).clamp(0.0, 1.0);
  }

  ModelDownloadState copyWith({
    ModelDownloadStatus? status,
    int? received,
    int? total,
    String? error,
  }) {
    return ModelDownloadState(
      status: status ?? this.status,
      received: received ?? this.received,
      total: total ?? this.total,
      error: error,
    );
  }
}

/// Drives the on-demand download of the optional ONNX models and refreshes the
/// installation/staging providers so the runtime picks them up when finished.
class ModelDownloadController extends StateNotifier<ModelDownloadState> {
  ModelDownloadController(this._ref) : super(const ModelDownloadState());

  final Ref _ref;

  Future<void> downloadModels() async {
    if (state.isDownloading) {
      return;
    }
    try {
      final manifest = await _ref.read(localModelManifestProvider.future);
      final specs =
          manifest.models.where((model) => model.isDownloadable).toList();
      if (specs.isEmpty) {
        state = state.copyWith(status: ModelDownloadStatus.completed);
        return;
      }

      final total =
          specs.fold<int>(0, (sum, spec) => sum + spec.download!.totalBytes);
      state = ModelDownloadState(
        status: ModelDownloadStatus.downloading,
        received: 0,
        total: total,
      );

      final downloader = _ref.read(localModelDownloaderProvider);
      await downloader.downloadAll(
        specs,
        onProgress: (received, resolvedTotal) {
          state = state.copyWith(received: received, total: resolvedTotal);
        },
      );

      // Recompute installation/staging state so the AI runtime, indexer, and
      // query embedder start using the freshly downloaded models, and refresh
      // the needs-download flag so the prompt dismisses itself.
      _ref.invalidate(localModelInstallationsProvider);
      _ref.invalidate(localModelStagesProvider);
      _ref.invalidate(modelsNeedDownloadProvider);

      state = state.copyWith(status: ModelDownloadStatus.completed);
    } catch (error) {
      state = state.copyWith(
        status: ModelDownloadStatus.failed,
        error: error.toString(),
      );
    }
  }

  void reset() {
    state = const ModelDownloadState();
  }
}

final modelDownloadControllerProvider =
    StateNotifierProvider<ModelDownloadController, ModelDownloadState>((ref) {
  return ModelDownloadController(ref);
});

/// True when at least one optional model still needs downloading. Drives
/// whether the download prompt is shown.
final modelsNeedDownloadProvider = FutureProvider<bool>((ref) async {
  final manifest = await ref.watch(localModelManifestProvider.future);
  final downloadable =
      manifest.models.where((model) => model.isDownloadable).toList();
  if (downloadable.isEmpty) {
    return false;
  }
  final downloader = ref.watch(localModelDownloaderProvider);
  for (final spec in downloadable) {
    if (!await downloader.isDownloaded(spec)) {
      return true;
    }
  }
  return false;
});
