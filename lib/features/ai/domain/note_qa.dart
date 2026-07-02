/// A note that contributed to an "Ask your notes" answer, with a short excerpt
/// and (when available) the semantic similarity score that surfaced it.
class NoteQaCitation {
  const NoteQaCitation({
    required this.noteId,
    required this.title,
    required this.snippet,
    this.score,
  });

  final String noteId;
  final String title;
  final String snippet;

  /// Cosine similarity to the question in [0, 1], or null when the note was
  /// retrieved lexically (no vector available).
  final double? score;
}

/// How an "Ask your notes" request resolved.
enum NoteQaOutcome {
  /// An answer was synthesized from the user's notes.
  answered,

  /// The question was blank.
  emptyQuestion,

  /// The library has no notes to search.
  noNotes,

  /// Notes exist, but none were relevant to the question.
  noMatches,
}

/// The result of asking a question over the note library: a grounded answer
/// plus the notes it was drawn from.
class NoteQaAnswer {
  const NoteQaAnswer({
    required this.question,
    required this.answer,
    required this.citations,
    required this.outcome,
  });

  const NoteQaAnswer.emptyQuestion(this.question)
      : answer = '',
        citations = const [],
        outcome = NoteQaOutcome.emptyQuestion;

  const NoteQaAnswer.noNotes(this.question)
      : answer = '',
        citations = const [],
        outcome = NoteQaOutcome.noNotes;

  const NoteQaAnswer.noMatches(this.question)
      : answer = '',
        citations = const [],
        outcome = NoteQaOutcome.noMatches;

  const NoteQaAnswer.answered({
    required this.question,
    required this.answer,
    required this.citations,
  }) : outcome = NoteQaOutcome.answered;

  final String question;

  /// The synthesized answer text. Empty for every non-[answered] outcome.
  final String answer;

  /// The notes the answer was grounded in, best match first.
  final List<NoteQaCitation> citations;

  final NoteQaOutcome outcome;

  bool get hasAnswer => outcome == NoteQaOutcome.answered;
}
