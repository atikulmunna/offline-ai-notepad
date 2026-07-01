import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai_notepad/features/ai/domain/local_model_spec.dart';

void main() {
  group('LocalModelSpec download parsing', () {
    Map<String, dynamic> baseJson() => {
          'id': 'falconsai-summarizer-en-v1',
          'task': 'summarization',
          'format': 'onnx',
          'backend': 'onnx-runtime',
          'asset_path':
              'assets/models/falconsai-summarizer-en-v1/model.onnx',
          'tokenizer_asset_path':
              'assets/models/falconsai-summarizer-en-v1/tokenizer.json',
          'packaged': false,
          'optional_download': true,
          'download': {
            'base_url': 'https://example.com/releases/models-v1/',
            'total_bytes': 96390582,
            'files': [
              {
                'name': 'model.onnx',
                'remote': 'falconsai-summarizer-en-v1__model.onnx',
                'sha256': 'ABCDEF',
                'bytes': 58450196,
              },
              {
                'name': 'tokenizer.json',
                'remote': 'falconsai-summarizer-en-v1__tokenizer.json',
                'sha256': 'deadbeef',
                'bytes': 2422267,
              },
            ],
          },
        };

    test('parses the download block and marks the model downloadable', () {
      final spec = LocalModelSpec.fromJson(baseJson());

      expect(spec.isDownloadable, isTrue);
      expect(spec.download, isNotNull);
      expect(spec.download!.totalBytes, 96390582);
      expect(spec.download!.files, hasLength(2));

      final first = spec.download!.files.first;
      expect(first.name, 'model.onnx');
      expect(first.remote, 'falconsai-summarizer-en-v1__model.onnx');
      expect(first.bytes, 58450196);
      // Checksums are normalized to lowercase for comparison after download.
      expect(first.sha256, 'abcdef');
    });

    test('a packaged model without a download block is not downloadable', () {
      final json = baseJson()
        ..['packaged'] = true
        ..['optional_download'] = false
        ..remove('download');

      final spec = LocalModelSpec.fromJson(json);
      expect(spec.isDownloadable, isFalse);
      expect(spec.download, isNull);
    });

    test('total_bytes falls back to the sum of file sizes when omitted', () {
      final json = baseJson();
      (json['download'] as Map<String, dynamic>).remove('total_bytes');

      final spec = LocalModelSpec.fromJson(json);
      expect(spec.download!.totalBytes, 58450196 + 2422267);
    });
  });
}
