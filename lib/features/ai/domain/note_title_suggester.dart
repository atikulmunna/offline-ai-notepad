/// Derives a concise title from a note's body, for notes the user left
/// untitled. Pure and dependency-free so it can be unit tested; deliberately
/// conservative, returning null rather than a low-quality guess.
class NoteTitleSuggester {
  const NoteTitleSuggester({
    this.maxLength = 60,
    this.minBodyLength = 12,
  });

  /// Longest suggested title; longer leads are trimmed at a word boundary.
  final int maxLength;

  /// Below this trimmed body length there isn't enough to title, so we abstain.
  final int minBodyLength;

  String? suggest(String body) {
    // Collapse runs of horizontal whitespace (incl. non-breaking spaces) but
    // keep newlines so the first-line heuristic still works.
    final normalized = body.replaceAll(RegExp(r'[^\S\n]+'), ' ').trim();
    if (normalized.length < minBodyLength) {
      return null;
    }

    // Prefer the first non-empty line; fall back to the whole body collapsed.
    final firstLine = normalized
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    final source = firstLine.isEmpty ? normalized : firstLine;

    // Strip leading list/markdown markers ("#", "-", "*", "1.", ">").
    var candidate = source.replaceFirst(
      RegExp(r'^\s*([#>*\-•]+|\d+[.)])\s*'),
      '',
    );

    // A title is a single line: cut at the first sentence break if the lead is
    // long, so we don't title with a whole paragraph.
    final sentenceEnd = RegExp(r'[.!?](\s|$)').firstMatch(candidate);
    if (sentenceEnd != null && sentenceEnd.start + 1 >= minBodyLength) {
      candidate = candidate.substring(0, sentenceEnd.start).trim();
    }

    candidate = candidate.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (candidate.length < minBodyLength) {
      return null;
    }

    candidate = _truncate(candidate, maxLength);
    // Drop a trailing comma/colon/semicolon left by truncation.
    candidate = candidate.replaceAll(RegExp(r'[,;:]\s*$'), '').trim();
    return candidate.isEmpty ? null : candidate;
  }

  static String _truncate(String input, int max) {
    if (input.length <= max) {
      return input;
    }
    var cut = input.substring(0, max);
    final lastSpace = cut.lastIndexOf(' ');
    if (lastSpace > max ~/ 2) {
      cut = cut.substring(0, lastSpace);
    }
    return cut.trimRight();
  }
}
