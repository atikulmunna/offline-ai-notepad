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
        .map(_stripLeadIn)
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    if (sentences.isEmpty) {
      return normalized;
    }

    final titleTerms = _keywords(cleanedTitle);
    final bodyTerms = _keywords(normalized);
    final scored = <({String sentence, double score})>[];
    for (var index = 0; index < sentences.length; index += 1) {
      final sentence = sentences[index];
      final terms = _keywords(sentence);
      var score = terms.length.toDouble();
      if (titleTerms.isNotEmpty) {
        score += titleTerms.intersection(terms).length * 2.0;
      }
      score += bodyTerms.intersection(terms).length * 0.12;
      if (index == 0) {
        score += 0.65;
      }
      if (index == sentences.length - 1) {
        score += 1.35;
      } else if (index >= sentences.length - 2) {
        score += 0.8;
      }
      if (sentence.length > 180) {
        score -= 1.0;
      }
      if (sentence.length < 40) {
        score -= 0.75;
      }
      if (_looksLikeDateline(sentence)) {
        score -= 3.0;
      }
      if (_looksLikeFragment(sentence)) {
        score -= 2.5;
      }
      if (_looksPromotional(sentence)) {
        score -= 1.5;
      }
      if (_looksVagueLead(sentence)) {
        score -= 1.75;
      }
      if (_looksConclusionSentence(sentence)) {
        score += 1.9;
      }
      if (_looksConcreteOutcomeSentence(sentence)) {
        score += 1.2;
      }
      scored.add((sentence: sentence, score: score));
    }

    scored.sort((left, right) => right.score.compareTo(left.score));

    final openerCandidate = scored
        .where((candidate) => !_isTooSimilar(candidate.sentence, cleanedTitle))
        .firstOrNull;
    final openerSentence = openerCandidate?.sentence ?? sentences.first;

    String? followUpSentence;
    for (final candidate in scored) {
      if (_isTooSimilar(candidate.sentence, cleanedTitle)) {
        continue;
      }
      if (_isTooSimilar(candidate.sentence, openerSentence)) {
        continue;
      }
      if (_looksConclusionSentence(candidate.sentence) ||
          _containsContrastOrResolution(candidate.sentence) ||
          _looksConcreteOutcomeSentence(candidate.sentence)) {
        followUpSentence = candidate.sentence;
        break;
      }
    }

    followUpSentence ??= scored
        .map((candidate) => candidate.sentence)
        .where((sentence) =>
            !_isTooSimilar(sentence, cleanedTitle) &&
            !_isTooSimilar(sentence, openerSentence))
        .cast<String?>()
        .firstOrNull;

    final opener = _compressSentence(openerSentence);
    final followUp =
        followUpSentence != null ? _compressSentence(followUpSentence) : null;
    final lead = _buildLead(cleanedTitle, opener);

    if (followUp == null || _isTooSimilar(opener, followUp)) {
      return lead;
    }

    return '$lead $followUp'.trim();
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

  String _stripLeadIn(String input) {
    return input.replaceFirst(
      RegExp(
        r'^(this note|the note|this article|the article|this report)\s+(explains|describes|covers|discusses)\s+',
        caseSensitive: false,
      ),
      '',
    ).trim();
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

  bool _looksLikeFragment(String input) {
    if (RegExp(r'[.!?]$').hasMatch(input)) {
      return false;
    }
    return RegExp(r'^[\w\s,&;:/()-]+$').hasMatch(input);
  }

  bool _looksPromotional(String input) {
    return RegExp(
      r'\b(amazing|exciting|incredible|wonderful|beautifully|premium|perfect)\b',
      caseSensitive: false,
    ).hasMatch(input);
  }

  bool _looksVagueLead(String input) {
    return RegExp(
      r'^(it|this|these|they|there|he|she)\b',
      caseSensitive: false,
    ).hasMatch(input.trim());
  }

  bool _looksConclusionSentence(String input) {
    return RegExp(
      r'\b(therefore|overall|in conclusion|the key challenge|the main challenge|the future|as a result|while .* also|however .* also|the key point)\b',
      caseSensitive: false,
    ).hasMatch(input);
  }

  bool _containsContrastOrResolution(String input) {
    return RegExp(
      r'\b(however|but|while|at the same time|therefore|so|thus|overall|instead)\b',
      caseSensitive: false,
    ).hasMatch(input);
  }

  bool _looksConcreteOutcomeSentence(String input) {
    return RegExp(
      r'\b(help|helps|improve|improves|optimi[sz]e|optimi[sz]es|predict|predicts|reduce|reduces|forecast|forecasts|integrate|integrates|support|supports|manage|manages|efficient|efficiency|renewable|grid|energy use|power distribution)\b',
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

  String _compressSentence(String sentence) {
    final cleaned = sentence.trim();
    if (cleaned.length <= 160) {
      return cleaned;
    }

    final parts = cleaned.split(RegExp(r'(?<=[,;:])\s+'));
    final buffer = StringBuffer();
    for (final part in parts) {
      final candidate = buffer.isEmpty ? part : '${buffer.toString()} $part';
      if (candidate.length > 160) {
        break;
      }
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write(part);
    }

    final compressed = buffer.isEmpty ? cleaned.substring(0, 160) : buffer.toString();
    final normalized = compressed.replaceAll(RegExp(r'[,;:]\s*$'), '.').trim();
    return RegExp(r'[.!?]$').hasMatch(normalized) ? normalized : '$normalized.';
  }

  String _buildLead(String cleanedTitle, String opener) {
    if (cleanedTitle.isEmpty || _isTooSimilar(cleanedTitle, opener)) {
      return opener;
    }

    if (_looksVagueLead(opener)) {
      final normalizedTitle = cleanedTitle[0].toUpperCase() + cleanedTitle.substring(1);
      final rewritten = opener.replaceFirst(
        RegExp(r'^(it|this note|this|these|they)\b', caseSensitive: false),
        normalizedTitle,
      );
      return rewritten.trim();
    }

    final normalizedTitle = cleanedTitle[0].toUpperCase() + cleanedTitle.substring(1);
    if (RegExp(r'[.!?]$').hasMatch(normalizedTitle)) {
      return '$normalizedTitle ${opener.trim()}'.trim();
    }

    return '$normalizedTitle: ${opener.trim()}'.trim();
  }
}
