import '../domain/note_summarizer.dart';

class LocalNoteSummarizer implements NoteSummarizer {
  @override
  Future<String> summarize({
    String? title,
    required String body,
  }) async {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return 'Add a little more detail and I can summarize it locally.';
    }

    final sentences = normalized
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    final fallbackEnd = normalized.length > 120 ? 120 : normalized.length;

    final opening = sentences.isNotEmpty
        ? sentences.first.trim()
        : normalized.substring(0, fallbackEnd);
    final secondary = sentences.length > 1 ? sentences[1].trim() : null;
    final titleLead = title == null || title.trim().isEmpty ? null : title.trim();

    final parts = <String>[
      if (titleLead != null) '$titleLead:',
      opening,
      if (secondary != null && secondary != opening) secondary,
    ];

    return parts.join(' ').trim();
  }
}
