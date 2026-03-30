import '../domain/note_summarizer.dart';

class LocalNoteSummarizer implements NoteSummarizer {
  static const _stopwords = <String>{
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
    'has',
    'he',
    'in',
    'is',
    'it',
    'its',
    'of',
    'on',
    'that',
    'the',
    'to',
    'was',
    'were',
    'will',
    'with',
  };

  @override
  Future<String> summarize({
    String? title,
    required String body,
  }) async {
    final normalized = _normalize(body);
    if (normalized.isEmpty) {
      return 'Add a little more detail and I can summarize it locally.';
    }

    final cleanedTitle = _cleanFragment(title ?? '');
    final sentences = normalized
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map(_cleanFragment)
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    if (sentences.isEmpty) {
      return normalized;
    }

    final titleTerms = _keywords(cleanedTitle);
    final scored = <({String sentence, double score})>[];
    for (var index = 0; index < sentences.length; index += 1) {
      final sentence = sentences[index];
      final terms = _keywords(sentence);
      var score = terms.length.toDouble();
      if (titleTerms.isNotEmpty) {
        score += titleTerms.intersection(terms).length * 2.0;
      }
      if (index == 0) {
        score += 1.25;
      }
      if (sentence.length > 180) {
        score -= 1.0;
      }
      if (_looksLikeDateline(sentence)) {
        score -= 3.0;
      }
      scored.add((sentence: sentence, score: score));
    }

    scored.sort((left, right) => right.score.compareTo(left.score));
    final chosen = <String>[];
    for (final candidate in scored) {
      if (_isTooSimilar(candidate.sentence, cleanedTitle)) {
        continue;
      }
      if (chosen.any((existing) => _isTooSimilar(existing, candidate.sentence))) {
        continue;
      }
      chosen.add(candidate.sentence);
      if (chosen.length == 2) {
        break;
      }
    }

    if (chosen.isEmpty) {
      chosen.add(sentences.first);
    }

    return chosen.join(' ').trim();
  }

  String _normalize(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _cleanFragment(String input) {
    var output = _normalize(input);
    output = output.replaceFirst(
      RegExp(r'^\s*(summary|summarize)\s*:\s*', caseSensitive: false),
      '',
    );
    output = output.replaceFirst(
      RegExp(r'^\s*\((reuters|ap|afp)\)\s*[-:]\s*', caseSensitive: false),
      '',
    );
    output = output.replaceFirst(
      RegExp(r'^\s*[A-Z][a-zA-Z\s.-]{1,24}\s*\([^)]*\)\s*[-:]\s*'),
      '',
    );
    output = output.replaceFirst(
      RegExp(r'^\s*\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\s*[-:]\s*'),
      '',
    );
    return output.trim();
  }

  Set<String> _keywords(String input) {
    return input
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((part) => part.length > 2 && !_stopwords.contains(part))
        .toSet();
  }

  bool _looksLikeDateline(String input) {
    return RegExp(
      r'^\(?[A-Z][a-zA-Z]+\)?\s*[-:]\s|\(\s*(reuters|ap|afp)\s*\)',
      caseSensitive: false,
    ).hasMatch(input);
  }

  bool _isTooSimilar(String left, String right) {
    if (left.isEmpty || right.isEmpty) {
      return false;
    }
    final leftTerms = _keywords(left);
    final rightTerms = _keywords(right);
    if (leftTerms.isEmpty || rightTerms.isEmpty) {
      return left.toLowerCase() == right.toLowerCase();
    }
    final overlap = leftTerms.intersection(rightTerms).length;
    final smaller = leftTerms.length < rightTerms.length
        ? leftTerms.length
        : rightTerms.length;
    return smaller > 0 && overlap / smaller >= 0.8;
  }
}
