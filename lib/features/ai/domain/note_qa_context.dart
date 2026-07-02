import '../../notes/domain/note_preview.dart';
import 'note_qa.dart';

/// The assembled input for answering a question over notes: the grounded
/// [context] text fed to the summarizer/answerer, plus the [citations] that
/// context was drawn from (best match first).
class NoteQaContext {
  const NoteQaContext({
    required this.context,
    required this.citations,
  });

  final String context;
  final List<NoteQaCitation> citations;

  bool get isEmpty => citations.isEmpty;
}

/// Pure assembly of retrieved notes into a bounded context window and citation
/// list. Kept dependency-free so it can be unit tested without a runtime.
class NoteQaContextBuilder {
  const NoteQaContextBuilder({
    this.maxNotes = 5,
    this.maxCharsPerNote = 700,
    this.maxTotalChars = 2600,
    this.snippetChars = 200,
  });

  /// How many top-ranked notes to draw from at most.
  final int maxNotes;

  /// Character cap for each note's contribution to the context window.
  final int maxCharsPerNote;

  /// Overall character cap for the assembled context (keeps the summarizer
  /// input bounded regardless of how many notes matched).
  final int maxTotalChars;

  /// Character cap for the human-facing citation excerpt.
  final int snippetChars;

  NoteQaContext build({
    required String question,
    required List<({NotePreview note, double? score})> ranked,
  }) {
    final questionTerms = _terms(question);
    final citations = <NoteQaCitation>[];
    final blocks = <String>[];
    var total = 0;

    for (final entry in ranked) {
      if (citations.length >= maxNotes || total >= maxTotalChars) {
        break;
      }
      final note = entry.note;
      final body = _collapse(note.body);
      if (body.isEmpty) {
        continue;
      }
      final title = _collapse(note.title);

      final remaining = maxTotalChars - total;
      final budget = remaining < maxCharsPerNote ? remaining : maxCharsPerNote;
      final excerpt = _truncate(body, budget);
      final block = title.isEmpty ? excerpt : '$title. $excerpt';
      blocks.add(block);
      total += block.length;

      citations.add(
        NoteQaCitation(
          noteId: note.id,
          title: title.isEmpty ? 'Untitled note' : title,
          snippet: _snippet(body, questionTerms),
          score: entry.score,
        ),
      );
    }

    return NoteQaContext(
      context: blocks.join('\n\n'),
      citations: citations,
    );
  }

  /// Picks the note sentence most relevant to the question terms for display,
  /// falling back to the note's opening text when nothing overlaps.
  String _snippet(String body, Set<String> questionTerms) {
    if (questionTerms.isNotEmpty) {
      final sentences = body.split(RegExp(r'(?<=[.!?])\s+'));
      String? best;
      var bestScore = 0;
      for (final sentence in sentences) {
        final overlap = _terms(sentence).intersection(questionTerms).length;
        if (overlap > bestScore) {
          bestScore = overlap;
          best = sentence.trim();
        }
      }
      if (best != null && bestScore > 0) {
        return _truncate(best, snippetChars);
      }
    }
    return _truncate(body, snippetChars);
  }

  static String _collapse(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Truncates at a word boundary and appends an ellipsis when cut.
  static String _truncate(String input, int max) {
    if (max <= 0 || input.length <= max) {
      return input;
    }
    var cut = input.substring(0, max);
    final lastSpace = cut.lastIndexOf(' ');
    if (lastSpace > max ~/ 2) {
      cut = cut.substring(0, lastSpace);
    }
    return '${cut.trimRight()}…';
  }

  static Set<String> _terms(String input) {
    return input
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((part) => part.length > 2)
        .toSet();
  }
}
