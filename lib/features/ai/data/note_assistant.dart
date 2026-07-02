import 'dart:typed_data';

import '../../notes/data/vector_note_search.dart';
import '../../notes/domain/note_preview.dart';
import '../../notes/domain/note_tag.dart';
import '../domain/folder_suggester.dart';
import '../domain/note_suggestions.dart';
import '../domain/note_query_embedder.dart';
import '../domain/note_title_suggester.dart';
import '../domain/tag_suggester.dart';

/// The on-device "assistant" that proposes a title, a folder, and tags for the
/// note being written. Titles come from the body text (pure heuristic); folders
/// and tags come from the note's nearest semantic neighbors. Everything runs
/// locally and is offered non-destructively for the user to accept.
class NoteAssistant {
  NoteAssistant({
    required NoteQueryEmbedder? embedder,
    required Future<List<NotePreview>> Function() loadNotes,
    required Future<Map<String, Float32List>> Function() loadVectors,
    NoteTitleSuggester titleSuggester = const NoteTitleSuggester(),
    FolderSuggester folderSuggester = const FolderSuggester(),
    TagSuggester tagSuggester = const TagSuggester(),
    int neighborK = 8,
  })  : _embedder = embedder,
        _loadNotes = loadNotes,
        _loadVectors = loadVectors,
        _titleSuggester = titleSuggester,
        _folderSuggester = folderSuggester,
        _tagSuggester = tagSuggester,
        _neighborK = neighborK;

  final NoteQueryEmbedder? _embedder;
  final Future<List<NotePreview>> Function() _loadNotes;
  final Future<Map<String, Float32List>> Function() _loadVectors;
  final NoteTitleSuggester _titleSuggester;
  final FolderSuggester _folderSuggester;
  final TagSuggester _tagSuggester;
  final int _neighborK;

  Future<NoteSuggestions> suggest({
    required String noteId,
    required String currentTitle,
    required String body,
    required String? currentFolderId,
    List<NoteTag> currentTags = const [],
  }) async {
    final title =
        currentTitle.trim().isEmpty ? _titleSuggester.suggest(body) : null;

    final needFolder = currentFolderId == null;
    FolderSuggestion? folder;
    var tags = const <NoteTag>[];

    // Folder and tag suggestions both draw on the note's nearest neighbors, so
    // embed once and reuse the ranking for both.
    final neighbors = await _neighbors(noteId: noteId, body: body);
    if (neighbors.isNotEmpty) {
      if (needFolder) {
        folder = _folderSuggester.suggest(
          neighbors
              .map((entry) => (
                    id: entry.note.folderId,
                    name: entry.note.folderName,
                    weight: entry.score,
                  ))
              .toList(growable: false),
        );
      }
      tags = _tagSuggester.suggest(
        neighbors: neighbors
            .map((entry) => (tags: entry.note.tags, weight: entry.score))
            .toList(growable: false),
        exclude: currentTags.map((tag) => tag.id).toSet(),
      );
    }

    return NoteSuggestions(title: title, folder: folder, tags: tags);
  }

  Future<List<({NotePreview note, double score})>> _neighbors({
    required String noteId,
    required String body,
  }) async {
    final embedder = _embedder;
    if (embedder == null || body.trim().isEmpty) {
      return const [];
    }

    final queryVector = await embedder.embedQuery(body);
    if (queryVector == null || queryVector.isEmpty) {
      return const [];
    }

    final vectors = await _loadVectors();
    final notes = await _loadNotes();
    final others = notes.where((note) => note.id != noteId);

    return VectorNoteSearch.cosineRankScored(
      noteVectors: vectors,
      queryVector: queryVector,
      notes: others,
    ).take(_neighborK).toList(growable: false);
  }
}
