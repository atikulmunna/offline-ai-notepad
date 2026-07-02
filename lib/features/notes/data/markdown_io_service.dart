import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/markdown_converter.dart';

/// File I/O for Markdown import/export. Serialization/parsing lives in the pure
/// [MarkdownConverter]; this service only touches the file system and share/pick
/// plugins.
class MarkdownIoService {
  const MarkdownIoService();

  /// Writes the note as a `.md` file and opens the system share sheet.
  Future<void> shareNoteAsMarkdown({
    String? title,
    required List<dynamic> deltaOps,
  }) async {
    final markdown = MarkdownConverter.deltaToMarkdown(deltaOps, title: title);
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, _fileName(title)));
    await file.writeAsString(markdown, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: title ?? 'Note'),
    );
  }

  /// Lets the user pick a Markdown file and returns it parsed, or null if the
  /// picker was cancelled. Falls back to the file name for the title when the
  /// document has no leading `# H1`.
  Future<MarkdownNote?> pickMarkdownFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['md', 'markdown', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final selected = result.files.single;
    final content = selected.bytes != null
        ? utf8.decode(selected.bytes!)
        : await File(selected.path!).readAsString();
    final note = MarkdownConverter.markdownToNote(content);
    if (note.title != null) {
      return note;
    }

    final base = p.basenameWithoutExtension(selected.name).trim();
    return MarkdownNote(
      title: base.isEmpty ? null : base,
      deltaOps: note.deltaOps,
      plainText: note.plainText,
    );
  }

  String _fileName(String? title) {
    final base = (title == null || title.trim().isEmpty) ? 'note' : title.trim();
    final safe = base
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    return '${safe.isEmpty ? 'note' : safe}.md';
  }
}
