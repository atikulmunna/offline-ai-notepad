import '../domain/note_preview.dart';

class SemanticNoteSearch {
  const SemanticNoteSearch._();

  static List<NotePreview> rank({
    required Iterable<NotePreview> notes,
    required String query,
  }) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      final sorted = notes.toList(growable: false)
        ..sort((a, b) => _defaultSort(a, b));
      return sorted;
    }

    final queryTokens = _tokens(normalizedQuery);
    final expandedTokens = _expandTokens(queryTokens);
    final ranked = <({NotePreview note, double score})>[];

    for (final note in notes) {
      final title = _normalize(note.title);
      final body = _normalize(note.body);
      final folder = _normalize(note.folderName ?? '');
      final combined = '$title $body $folder';
      final titleTokens = _tokens(title);
      final bodyTokens = _tokens(body);
      final folderTokens = _tokens(folder);
      final combinedTokens = {...titleTokens, ...bodyTokens, ...folderTokens};

      var score = 0.0;
      if (title.contains(normalizedQuery)) {
        score += 7.5;
      }
      if (body.contains(normalizedQuery)) {
        score += 4.0;
      }
      if (folder.contains(normalizedQuery)) {
        score += 2.5;
      }

      for (final token in expandedTokens) {
        if (titleTokens.contains(token)) {
          score += 3.2;
        }
        if (bodyTokens.contains(token)) {
          score += 1.4;
        }
        if (folderTokens.contains(token)) {
          score += 1.1;
        }
      }

      final overlap = combinedTokens.intersection(expandedTokens).length;
      score += overlap * 0.8;

      final titleSimilarity = _diceCoefficient(titleTokens, expandedTokens);
      final bodySimilarity = _diceCoefficient(bodyTokens, expandedTokens);
      score += (titleSimilarity * 3.5) + (bodySimilarity * 1.7);

      if (queryTokens.length > 1) {
        final phraseBonus = _orderedTokenPhraseBonus(queryTokens, combined);
        score += phraseBonus;
      }

      if (score > 0) {
        ranked.add((note: note, score: score));
      }
    }

    ranked.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return _defaultSort(a.note, b.note);
    });

    return ranked.map((entry) => entry.note).toList(growable: false);
  }

  static int _defaultSort(NotePreview a, NotePreview b) {
    final pinCompare = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
    if (pinCompare != 0) {
      return pinCompare;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  }

  static String _normalize(String value) {
    final lowered = value.toLowerCase();
    final sanitized = lowered.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Set<String> _tokens(String value) {
    return value
        .split(' ')
        .where((token) => token.length > 1 && !_stopWords.contains(token))
        .expand((token) => {token, _stem(token)})
        .where((token) => token.isNotEmpty)
        .toSet();
  }

  static Set<String> _expandTokens(Set<String> tokens) {
    final expanded = <String>{...tokens};
    for (final token in tokens) {
      expanded.addAll(_conceptMap[token] ?? const <String>{});
    }
    return expanded;
  }

  static double _diceCoefficient(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) {
      return 0;
    }
    final intersection = a.intersection(b).length;
    return (2 * intersection) / (a.length + b.length);
  }

  static double _orderedTokenPhraseBonus(
    Set<String> queryTokens,
    String combinedText,
  ) {
    final terms = queryTokens.toList(growable: false);
    var hits = 0;
    for (var i = 0; i < terms.length - 1; i++) {
      if (combinedText.contains('${terms[i]} ${terms[i + 1]}')) {
        hits++;
      }
    }
    return hits * 1.25;
  }

  static String _stem(String token) {
    final value = token;
    if (value.length > 5 && value.endsWith('ing')) {
      return value.substring(0, value.length - 3);
    }
    if (value.length > 4 && value.endsWith('ed')) {
      return value.substring(0, value.length - 2);
    }
    if (value.length > 4 && value.endsWith('es')) {
      return value.substring(0, value.length - 2);
    }
    if (value.length > 3 && value.endsWith('s')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  static const Set<String> _stopWords = {
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'by',
    'for',
    'from',
    'how',
    'in',
    'into',
    'is',
    'it',
    'of',
    'on',
    'or',
    'that',
    'the',
    'this',
    'to',
    'with',
    'your',
  };

  static const Map<String, Set<String>> _conceptMap = {
    'idea': {'concept', 'brainstorm', 'plan', 'thinking'},
    'concept': {'idea', 'brainstorm', 'plan'},
    'meeting': {'discussion', 'agenda', 'sync', 'call'},
    'agenda': {'meeting', 'discussion', 'plan'},
    'task': {'todo', 'action', 'checklist', 'next'},
    'todo': {'task', 'checklist', 'action'},
    'summary': {'recap', 'overview', 'gist'},
    'recap': {'summary', 'overview', 'gist'},
    'privacy': {'security', 'private', 'local', 'offline'},
    'security': {'privacy', 'private', 'protection'},
    'research': {'study', 'explore', 'investigate'},
    'search': {'find', 'lookup', 'discover'},
    'note': {'memo', 'draft', 'writing'},
    'writing': {'draft', 'note', 'text'},
    'release': {'launch', 'ship', 'rollout'},
    'launch': {'release', 'ship'},
  };
}
