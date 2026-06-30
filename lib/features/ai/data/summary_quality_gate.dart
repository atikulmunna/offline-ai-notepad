/// Pure heuristic gate that decides whether a generative summary candidate is
/// good enough to show, or whether the caller should fall back to the extractive
/// summary. Kept dependency-free so it can be unit tested against real failure
/// strings captured from the on-device model.
class SummaryQualityGate {
  const SummaryQualityGate();

  static const _stopwords = <String>{
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'but',
    'by',
    'for',
    'from',
    'in',
    'into',
    'is',
    'it',
    'its',
    'main',
    'note',
    'of',
    'on',
    'or',
    'subject',
    'that',
    'the',
    'their',
    'there',
    'these',
    'this',
    'those',
    'to',
    'was',
    'were',
    'which',
    'with',
  };

  /// Returns true when [candidate] reads like a genuine, on-topic summary of the
  /// note. Returns false for empty, degenerate, off-topic, or low-effort output.
  bool isUseful(
    String? candidate, {
    String? title,
    required String body,
    required String fallbackSummary,
  }) {
    if (candidate == null || candidate.isEmpty) {
      return false;
    }

    final normalizedCandidate = _normalize(candidate);
    if (normalizedCandidate.length < 24) {
      return false;
    }
    if (normalizedCandidate.length > 320) {
      return false;
    }

    final words = normalizedCandidate
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.length < 6) {
      return false;
    }
    if (words.length > 55) {
      return false;
    }

    final normalizedFallback = _normalize(fallbackSummary);
    if (normalizedCandidate == normalizedFallback) {
      return false;
    }

    final normalizedTitle = _normalize(title ?? '');
    if (normalizedTitle.isNotEmpty &&
        (normalizedCandidate == normalizedTitle ||
            normalizedCandidate.startsWith('$normalizedTitle:'))) {
      return false;
    }

    final normalizedBody = _normalize(body);
    if (normalizedBody.isNotEmpty &&
        normalizedBody.startsWith(normalizedCandidate) &&
        normalizedCandidate.length < 80) {
      return false;
    }
    if (_bodyContainsCandidate(
      normalizedBody: normalizedBody,
      normalizedCandidate: normalizedCandidate,
    )) {
      return false;
    }

    if (RegExp(r'^\s*(summary|summarize)\s*:\s*', caseSensitive: false)
        .hasMatch(normalizedCandidate)) {
      return false;
    }
    if (RegExp(
      r'\b(main subject|subject of this note|this note is|the main idea)\b',
      caseSensitive: false,
    ).hasMatch(normalizedCandidate)) {
      return false;
    }
    if (RegExp(r'^(it|this|these|they|there)\b', caseSensitive: false)
        .hasMatch(normalizedCandidate)) {
      return false;
    }
    if (RegExp(r'[:;]\s*$').hasMatch(normalizedCandidate)) {
      return false;
    }

    final punctuationHeavy =
        RegExp(r'^[\p{L}\p{N}\s,&;:/()-]+$', unicode: true).hasMatch(
      normalizedCandidate,
    );
    final sentenceLike = RegExp(r'[.!?]').hasMatch(normalizedCandidate);
    final hasVerbLikeTerm = RegExp(
      r'\b(is|are|was|were|be|been|being|has|have|had|will|would|could|should|can|may|might|do|does|did|announced|said|plans|launched|revealed|showed|found|used|uses|helps|improves|includes)\b',
      caseSensitive: false,
    ).hasMatch(normalizedCandidate);
    final semicolonCount = ';'.allMatches(normalizedCandidate).length;
    if (!sentenceLike && (!hasVerbLikeTerm || punctuationHeavy)) {
      return false;
    }
    if (semicolonCount >= 2) {
      return false;
    }
    if (_looksLikeKeywordList(normalizedCandidate)) {
      return false;
    }
    // A small generative model degenerates into loops ("X of a X of a ...") or
    // shouty hallucinations ("DISCOVERATION: DISCLAIMER: ..."); reject both so we
    // fall back to the extractive summary.
    if (_hasExcessiveRepetition(normalizedCandidate)) {
      return false;
    }
    if (_looksShouty(candidate)) {
      return false;
    }
    if (_listMarkerHeavy(normalizedCandidate)) {
      return false;
    }
    if (!_hasBodyOverlap(
      normalizedCandidate: normalizedCandidate,
      normalizedBody: normalizedBody,
      normalizedTitle: normalizedTitle,
    )) {
      return false;
    }

    return true;
  }

  /// Rejects degenerate output where a bigram or content word repeats — the
  /// signature failure mode of greedy decoding on a small seq2seq model.
  bool _hasExcessiveRepetition(String value) {
    final words = value
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.length < 4) {
      return false;
    }

    final bigramCounts = <String, int>{};
    for (var i = 0; i < words.length - 1; i++) {
      final bigram = '${words[i]} ${words[i + 1]}';
      final count = (bigramCounts[bigram] ?? 0) + 1;
      bigramCounts[bigram] = count;
      if (count >= 3) {
        return true;
      }
    }

    final wordCounts = <String, int>{};
    for (final word in words) {
      if (word.length <= 2 || _stopwords.contains(word)) {
        continue;
      }
      final count = (wordCounts[word] ?? 0) + 1;
      wordCounts[word] = count;
      if (count >= 4) {
        return true;
      }
    }
    return false;
  }

  /// Rejects output dominated by ALL-CAPS tokens (e.g. "DISCLAIMER MEDICAL
  /// REQUIREMENTS"), which real summaries do not produce.
  bool _looksShouty(String value) {
    final words = value
        .split(RegExp(r'\s+'))
        .where((word) => RegExp(r'[A-Za-z]').hasMatch(word))
        .toList(growable: false);
    if (words.length < 4) {
      return false;
    }
    final shouted = words
        .where((word) =>
            word.length >= 3 &&
            word == word.toUpperCase() &&
            word != word.toLowerCase())
        .length;
    return shouted / words.length >= 0.4;
  }

  /// Rejects enumerated list scaffolding like "(A) ... (B) ..." that the model
  /// emits when it loses the summarization thread.
  bool _listMarkerHeavy(String value) {
    return RegExp(r'\(\s*[a-zA-Z0-9]\s*\)').allMatches(value).length >= 2;
  }

  String _normalize(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _bodyContainsCandidate({
    required String normalizedBody,
    required String normalizedCandidate,
  }) {
    if (normalizedCandidate.length < 96) {
      return false;
    }
    return normalizedBody.contains(normalizedCandidate);
  }

  bool _looksLikeKeywordList(String value) {
    final commaCount = ','.allMatches(value).length;
    final semicolonCount = ';'.allMatches(value).length;
    final sentenceCount = RegExp(r'[.!?]').allMatches(value).length;
    final hasColonLead = value.contains(':') && !RegExp(r'[.!?]').hasMatch(value);
    return (commaCount >= 3 && sentenceCount == 0) ||
        (semicolonCount >= 1 && sentenceCount == 0) ||
        hasColonLead;
  }

  bool _hasBodyOverlap({
    required String normalizedCandidate,
    required String normalizedBody,
    required String normalizedTitle,
  }) {
    final candidateTerms = _keywords(normalizedCandidate);
    if (candidateTerms.isEmpty) {
      return false;
    }
    final bodyTerms = _keywords(normalizedBody);
    final titleTerms = _keywords(normalizedTitle);
    final overlap = candidateTerms.intersection({...bodyTerms, ...titleTerms});
    // Require both an absolute floor and a healthy share of the summary's own
    // content words to come from the note. Off-topic hallucinations clear the
    // floor by coincidence but score poorly on the ratio.
    if (overlap.length < 2) {
      return false;
    }
    return overlap.length / candidateTerms.length >= 0.34;
  }

  Set<String> _keywords(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((part) => part.length > 2 && !_stopwords.contains(part))
        .toSet();
  }
}
