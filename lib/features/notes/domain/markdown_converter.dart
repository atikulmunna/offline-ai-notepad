/// A note parsed from Markdown: an optional title (from a leading `# H1`), the
/// Quill delta ops for the body, and a plain-text projection for search/AI.
class MarkdownNote {
  const MarkdownNote({
    required this.title,
    required this.deltaOps,
    required this.plainText,
  });

  final String? title;
  final List<Map<String, dynamic>> deltaOps;
  final String plainText;
}

/// Converts between Quill delta and Markdown, both directions, for import/export.
///
/// Pure and dependency-free. Covers the formatting the editor can produce and
/// that Markdown can represent: bold, italic, strikethrough, headings, bullet /
/// ordered / checkbox lists, and blockquotes. Formatting with no Markdown
/// equivalent (underline, text color, highlight, alignment, indent) is dropped
/// on export, a deliberate, documented lossy edge rather than a failure.
class MarkdownConverter {
  const MarkdownConverter._();

  // ---- Delta -> Markdown -----------------------------------------------------

  static String deltaToMarkdown(List<dynamic> ops, {String? title}) {
    final lines = <String>[];
    final inline = StringBuffer();
    var orderedCounter = 0;

    void flush(Map<String, dynamic>? blockAttrs) {
      final content = inline.toString();
      inline.clear();
      if (blockAttrs?['list'] == 'ordered') {
        orderedCounter += 1;
      } else {
        orderedCounter = 0;
      }
      lines.add(_formatBlock(content, blockAttrs, orderedCounter));
    }

    for (final op in ops) {
      if (op is! Map) {
        continue;
      }
      final insert = op['insert'];
      if (insert is! String) {
        continue; // embeds (e.g. images) are not represented in v1
      }
      final attrs = (op['attributes'] as Map?)?.cast<String, dynamic>();
      final segments = insert.split('\n');
      for (var i = 0; i < segments.length; i++) {
        if (segments[i].isNotEmpty) {
          inline.write(_applyInline(segments[i], attrs));
        }
        if (i < segments.length - 1) {
          flush(attrs);
        }
      }
    }
    if (inline.isNotEmpty) {
      flush(null);
    }

    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }

    final body = lines.join('\n');
    final heading =
        (title != null && title.trim().isNotEmpty) ? '# ${title.trim()}' : null;
    if (heading != null) {
      return body.isEmpty ? '$heading\n' : '$heading\n\n$body\n';
    }
    return body.isEmpty ? '' : '$body\n';
  }

  static String _applyInline(String text, Map<String, dynamic>? attrs) {
    if (attrs == null) {
      return text;
    }
    var value = text;
    if (attrs['strike'] == true) {
      value = '~~$value~~';
    }
    if (attrs['italic'] == true) {
      value = '_${value}_';
    }
    if (attrs['bold'] == true) {
      value = '**$value**';
    }
    return value;
  }

  static String _formatBlock(
    String content,
    Map<String, dynamic>? attrs,
    int orderedCounter,
  ) {
    if (attrs == null) {
      return content;
    }
    switch (attrs['list']) {
      case 'bullet':
        return '- $content';
      case 'ordered':
        return '$orderedCounter. $content';
      case 'unchecked':
        return '- [ ] $content';
      case 'checked':
        return '- [x] $content';
    }
    switch (attrs['header']) {
      case 1:
        return '# $content';
      case 2:
        return '## $content';
      case 3:
        return '### $content';
    }
    if (attrs['blockquote'] == true) {
      return '> $content';
    }
    return content;
  }

  // ---- Markdown -> Note ------------------------------------------------------

  static MarkdownNote markdownToNote(String markdown) {
    final rawLines = markdown.replaceAll('\r\n', '\n').split('\n');

    var start = 0;
    while (start < rawLines.length && rawLines[start].trim().isEmpty) {
      start += 1;
    }

    String? title;
    if (start < rawLines.length) {
      final match = RegExp(r'^#\s+(.*)').firstMatch(rawLines[start]);
      if (match != null) {
        title = match.group(1)!.trim();
        start += 1;
        if (start < rawLines.length && rawLines[start].trim().isEmpty) {
          start += 1;
        }
      }
    }

    final ops = <Map<String, dynamic>>[];
    final plain = StringBuffer();
    for (final line in rawLines.sublist(start)) {
      final (blockAttrs, content) = _parseBlock(line);
      for (final op in _parseInline(content)) {
        ops.add(op);
        plain.write(op['insert']);
      }
      ops.add(
        blockAttrs == null
            ? {'insert': '\n'}
            : {'insert': '\n', 'attributes': blockAttrs},
      );
      plain.write('\n');
    }
    if (ops.isEmpty) {
      ops.add({'insert': '\n'});
    }

    return MarkdownNote(
      title: (title == null || title.isEmpty) ? null : title,
      deltaOps: ops,
      plainText: plain.toString().trim(),
    );
  }

  static (Map<String, dynamic>?, String) _parseBlock(String line) {
    final checkbox =
        RegExp(r'^\s*[-*]\s+\[([ xX])\]\s+(.*)').firstMatch(line);
    if (checkbox != null) {
      final checked = checkbox.group(1)!.toLowerCase() == 'x';
      return ({'list': checked ? 'checked' : 'unchecked'}, checkbox.group(2)!);
    }
    final bullet = RegExp(r'^\s*[-*]\s+(.*)').firstMatch(line);
    if (bullet != null) {
      return ({'list': 'bullet'}, bullet.group(1)!);
    }
    final ordered = RegExp(r'^\s*\d+\.\s+(.*)').firstMatch(line);
    if (ordered != null) {
      return ({'list': 'ordered'}, ordered.group(1)!);
    }
    final h3 = RegExp(r'^###\s+(.*)').firstMatch(line);
    if (h3 != null) {
      return ({'header': 3}, h3.group(1)!);
    }
    final h2 = RegExp(r'^##\s+(.*)').firstMatch(line);
    if (h2 != null) {
      return ({'header': 2}, h2.group(1)!);
    }
    final h1 = RegExp(r'^#\s+(.*)').firstMatch(line);
    if (h1 != null) {
      return ({'header': 1}, h1.group(1)!);
    }
    final quote = RegExp(r'^>\s+(.*)').firstMatch(line);
    if (quote != null) {
      return ({'blockquote': true}, quote.group(1)!);
    }
    return (null, line);
  }

  static final _inlinePattern = RegExp(
    r'(\*\*(.+?)\*\*)|(~~(.+?)~~)|(\*(.+?)\*)|(_(.+?)_)',
  );

  static List<Map<String, dynamic>> _parseInline(String text) {
    final ops = <Map<String, dynamic>>[];
    var index = 0;
    for (final match in _inlinePattern.allMatches(text)) {
      if (match.start > index) {
        ops.add({'insert': text.substring(index, match.start)});
      }
      final Map<String, dynamic> attrs;
      final String inner;
      if (match.group(1) != null) {
        attrs = {'bold': true};
        inner = match.group(2)!;
      } else if (match.group(3) != null) {
        attrs = {'strike': true};
        inner = match.group(4)!;
      } else if (match.group(5) != null) {
        attrs = {'italic': true};
        inner = match.group(6)!;
      } else {
        attrs = {'italic': true};
        inner = match.group(8)!;
      }
      ops.add({'insert': inner, 'attributes': attrs});
      index = match.end;
    }
    if (index < text.length) {
      ops.add({'insert': text.substring(index)});
    }
    return ops;
  }
}
