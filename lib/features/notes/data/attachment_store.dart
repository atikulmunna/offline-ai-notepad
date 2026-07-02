import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Local storage for note image attachments.
///
/// Picked images are copied into a stable `attachments/` folder under the app
/// documents directory and referenced from the Quill delta by file name only,
/// so the note's searchable text stays free of binary data and the reference
/// survives even if the absolute documents path changes between launches.
class AttachmentStore {
  AttachmentStore();

  Directory? _dir;
  final _random = Random();

  /// Ensures the attachments directory exists and caches its path so [resolve]
  /// can run synchronously from the image embed builder.
  Future<Directory> ensureReady() async {
    final cached = _dir;
    if (cached != null) {
      return cached;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  /// The cached attachments directory path, or null before [ensureReady] runs.
  String? get directoryPath => _dir?.path;

  /// Copies [sourcePath] into the attachments folder under a unique name and
  /// returns the stored file name (not a full path).
  Future<String> importImage(String sourcePath) async {
    final dir = await ensureReady();
    final ext = p.extension(sourcePath).toLowerCase();
    final safeExt = ext.isEmpty ? '.img' : ext;
    final name = 'img_${DateTime.now().millisecondsSinceEpoch}_'
        '${_random.nextInt(1 << 31)}$safeExt';
    final dest = p.join(dir.path, name);
    await File(sourcePath).copy(dest);
    return name;
  }

  /// Resolves a stored file name to an absolute path, or null if the directory
  /// has not been prepared yet ([ensureReady] not awaited).
  String? resolve(String fileName) {
    final base = _dir?.path;
    if (base == null) {
      return null;
    }
    return p.join(base, fileName);
  }
}
