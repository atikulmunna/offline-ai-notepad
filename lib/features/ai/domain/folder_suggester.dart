import 'note_suggestions.dart';

/// Proposes a folder for the current note by a similarity-weighted vote over
/// where its nearest neighbors live. Pure and dependency-free; abstains (returns
/// null) unless the evidence is strong enough to avoid noisy suggestions.
class FolderSuggester {
  const FolderSuggester({
    this.minVoters = 2,
    this.minShare = 0.5,
  });

  /// Fewest neighbors that must share the winning folder before we suggest it.
  final int minVoters;

  /// The winning folder must hold at least this share of the total similarity
  /// weight among filed neighbors.
  final double minShare;

  /// [neighbors] are similar notes, best match first, each carrying the folder
  /// it lives in (null when unfiled) and a non-negative similarity [weight].
  FolderSuggestion? suggest(
    List<({String? id, String? name, double weight})> neighbors,
  ) {
    final weightById = <String, double>{};
    final votersById = <String, int>{};
    final nameById = <String, String>{};
    var totalWeight = 0.0;

    for (final neighbor in neighbors) {
      final id = neighbor.id;
      final name = neighbor.name;
      if (id == null || name == null || name.isEmpty || neighbor.weight <= 0) {
        continue;
      }
      weightById[id] = (weightById[id] ?? 0) + neighbor.weight;
      votersById[id] = (votersById[id] ?? 0) + 1;
      nameById[id] = name;
      totalWeight += neighbor.weight;
    }

    if (totalWeight <= 0) {
      return null;
    }

    String? bestId;
    var bestWeight = 0.0;
    for (final entry in weightById.entries) {
      if (entry.value > bestWeight) {
        bestWeight = entry.value;
        bestId = entry.key;
      }
    }

    if (bestId == null) {
      return null;
    }
    if ((votersById[bestId] ?? 0) < minVoters) {
      return null;
    }
    if (bestWeight / totalWeight < minShare) {
      return null;
    }

    return FolderSuggestion(id: bestId, name: nameById[bestId]!);
  }
}
