import '../../notes/domain/note_tag.dart';

/// Proposes tags for the current note from the tags its nearest semantic
/// neighbors carry, weighted by similarity. Pure and dependency-free. Tags are
/// additive and low-risk, so a single strong neighbor can surface one, but a
/// cumulative-weight floor keeps weak matches out.
class TagSuggester {
  const TagSuggester({
    this.minWeight = 0.6,
    this.maxSuggestions = 3,
  });

  /// Minimum summed similarity weight a tag needs across neighbors to surface.
  final double minWeight;

  /// Most tags to suggest at once.
  final int maxSuggestions;

  List<NoteTag> suggest({
    required List<({List<NoteTag> tags, double weight})> neighbors,
    Set<String> exclude = const {},
  }) {
    final weightById = <String, double>{};
    final tagById = <String, NoteTag>{};

    for (final neighbor in neighbors) {
      if (neighbor.weight <= 0) {
        continue;
      }
      for (final tag in neighbor.tags) {
        if (exclude.contains(tag.id)) {
          continue;
        }
        weightById[tag.id] = (weightById[tag.id] ?? 0) + neighbor.weight;
        tagById[tag.id] = tag;
      }
    }

    final ranked = weightById.entries
        .where((entry) => entry.value >= minWeight)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ranked
        .take(maxSuggestions)
        .map((entry) => tagById[entry.key]!)
        .toList(growable: false);
  }
}
