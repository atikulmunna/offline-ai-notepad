import 'dart:typed_data';

import '../../notes/data/vector_note_search.dart';
import '../../notes/domain/note_preview.dart';
import '../domain/folder_suggester.dart';
import '../domain/note_suggestions.dart';
import '../domain/note_query_embedder.dart';
import '../domain/note_title_suggester.dart';

/// The on-device "assistant" that proposes a title and a folder for the note
/// being written. Titles come from the body text (pure heuristic); folders come
/// from where the note's nearest semantic neighbors live. Everything runs
/// locally and is offered non-destructively for the user to accept.
class NoteAssistant {
  NoteAssistant({
    required NoteQueryEmbedder? embedder,
    required Future<List<NotePreview>> Function() loadNotes,
    required Future<Map<String, Float32List>> Function() loadVectors,
    NoteTitleSuggester titleSuggester = const NoteTitleSuggester(),
    FolderSuggester folderSuggester = const FolderSuggester(),
    int neighborK = 8,
  })  : _embedder = embedder,
        _loadNotes = loadNotes,
        _loadVectors = loadVectors,
        _titleSuggester = titleSuggester,
        _folderSuggester = folderSuggester,
        _neighborK = neighborK;

  final NoteQueryEmbedder? _embedder;
  final Future<List<NotePreview>> Function() _loadNotes;
  final Future<Map<String, Float32List>> Function() _loadVectors;
  final NoteTitleSuggester _titleSuggester;
  final FolderSuggester _folderSuggester;
  final int _neighborK;

  Future<NoteSuggestions> suggest({
    required String noteId,
    required String currentTitle,
    required String body,
    required String? currentFolderId,
  }) async {
    final title =
        currentTitle.trim().isEmpty ? _titleSuggester.suggest(body) : null;

    FolderSuggestion? folder;
    if (currentFolderId == null) {
      folder = await _suggestFolder(noteId: noteId, body: body);
    }

    return NoteSuggestions(title: title, folder: folder);
  }

  Future<FolderSuggestion?> _suggestFolder({
    required String noteId,
    required String body,
  }) async {
    final embedder = _embedder;
    if (embedder == null || body.trim().isEmpty) {
      return null;
    }

    final queryVector = await embedder.embedQuery(body);
    if (queryVector == null || queryVector.isEmpty) {
      return null;
    }

    final vectors = await _loadVectors();
    final notes = await _loadNotes();
    final others = notes.where((note) => note.id != noteId);

    final ranked = VectorNoteSearch.cosineRankScored(
      noteVectors: vectors,
      queryVector: queryVector,
      notes: others,
    );

    final neighbors = ranked
        .take(_neighborK)
        .map((entry) => (
              id: entry.note.folderId,
              name: entry.note.folderName,
              weight: entry.score,
            ))
        .toList(growable: false);

    return _folderSuggester.suggest(neighbors);
  }
}
