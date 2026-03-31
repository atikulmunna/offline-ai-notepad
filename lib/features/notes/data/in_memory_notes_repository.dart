import '../domain/note_collection.dart';
import '../domain/note_document.dart';
import '../domain/note_folder.dart';
import '../domain/note_search_mode.dart';
import 'note_record.dart';
import '../domain/note_preview.dart';
import '../domain/notes_repository.dart';
import 'semantic_note_search.dart';

class InMemoryNotesRepository implements NotesRepository {
  static final _folders = [
    NoteFolder(id: 'all', name: 'All Notes', icon: 'folder'),
    NoteFolder(id: 'product', name: 'Product', icon: 'lightbulb'),
    NoteFolder(id: 'private', name: 'Private', icon: 'lock'),
    NoteFolder(id: 'research', name: 'Research', icon: 'search'),
  ];

  static final _notes = [
    NoteRecord(
      id: 'research-ideas',
      title: 'Research ideas',
      body: 'Compare local vector search options and keep a graceful fallback when device support gets messy.',
      folderId: 'research',
      folderName: 'Research',
      isPinned: true,
      createdAt: DateTime(2026, 3, 21, 9, 0),
      updatedAt: DateTime(2026, 3, 21, 9, 45),
    ),
    NoteRecord(
      id: 'release-checklist',
      title: 'Release checklist',
      body: 'Finish Android toolchain, scaffold architecture, and start note CRUD before AI integration.',
      folderId: 'product',
      folderName: 'Product',
      createdAt: DateTime(2026, 3, 21, 10, 0),
      updatedAt: DateTime(2026, 3, 21, 10, 30),
    ),
    NoteRecord(
      id: 'privacy-copy',
      title: 'Privacy copy',
      body: 'Keep the onboarding promise simple: your notes stay on device unless you explicitly export them.',
      folderId: 'private',
      folderName: 'Private',
      createdAt: DateTime(2026, 3, 21, 11, 0),
      updatedAt: DateTime(2026, 3, 21, 11, 5),
    ),
  ];

  @override
  Future<List<NotePreview>> listNotes({
    NoteCollection collection = NoteCollection.active,
    String searchQuery = '',
    NoteSearchMode searchMode = NoteSearchMode.keyword,
    String? folderId,
    bool pinnedOnly = false,
  }) async {
    final query = searchQuery.trim().toLowerCase();

    final filtered = _notes.where((note) {
      final matchesCollection = switch (collection) {
        NoteCollection.active => !note.isDeleted && !note.isArchived,
        NoteCollection.archived => !note.isDeleted && note.isArchived,
        NoteCollection.trash => note.isDeleted,
      };
      final matchesFolder = folderId == null || folderId == 'all'
          ? true
          : note.folderId == folderId;
      final matchesPinned = !pinnedOnly || note.isPinned;
      final matchesQuery = searchMode == NoteSearchMode.semantic
          ? true
          : query.isEmpty ||
              '${note.title ?? ''}\n${note.body}'.toLowerCase().contains(query);
      return matchesCollection &&
          matchesFolder &&
          matchesPinned &&
          matchesQuery;
    }).toList(growable: false)
      ..sort((a, b) {
        final pinCompare = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
        if (pinCompare != 0) {
          return pinCompare;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });

    final previews =
        filtered.map((note) => note.toPreview()).toList(growable: false);
    if (query.isNotEmpty && searchMode == NoteSearchMode.semantic) {
      return SemanticNoteSearch.rank(
        notes: previews,
        query: query,
      );
    }
    return previews;
  }

  @override
  Future<List<NoteFolder>> listFolders() async {
    return _folders.where((folder) => folder.id != 'all').toList(growable: false);
  }

  @override
  Future<NoteFolder> createFolder(String name) async {
    final folder = NoteFolder(
      id: 'folder-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      icon: 'folder',
    );
    _folders.add(folder);
    return folder;
  }

  @override
  Future<NoteFolder?> renameFolder({
    required String id,
    required String name,
  }) async {
    final index = _folders.indexWhere((folder) => folder.id == id);
    if (index == -1) {
      return null;
    }

    final updated = NoteFolder(
      id: _folders[index].id,
      name: name.trim(),
      icon: _folders[index].icon,
    );
    _folders[index] = updated;

    for (var i = 0; i < _notes.length; i++) {
      final note = _notes[i];
      if (note.folderId != id) {
        continue;
      }
      _notes[i] = NoteRecord(
        id: note.id,
        title: note.title,
        body: note.body,
        bodyDelta: note.bodyDelta,
        summary: note.summary,
        folderId: note.folderId,
        folderName: updated.name,
        isPinned: note.isPinned,
        isArchived: note.isArchived,
        isDeleted: note.isDeleted,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        deletedAt: note.deletedAt,
      );
    }

    return updated;
  }

  @override
  Future<String> createNote({
    String? title,
    required String body,
    String? bodyDelta,
    String? folderId,
  }) async {
    final now = DateTime.now();
    final id = 'note-${now.microsecondsSinceEpoch}';
    final folder = _lookupFolder(folderId);
    _notes.insert(
      0,
      NoteRecord(
        id: id,
        title: title,
        body: body,
        bodyDelta: bodyDelta,
        folderId: folder?.id,
        folderName: folder?.name,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  @override
  Future<NoteDocument?> getNote(String id) async {
    for (final note in _notes) {
      if (note.id == id) {
        return note.toDocument();
      }
    }
    return null;
  }

  @override
  Future<void> updateNote({
    required String id,
    String? title,
    required String body,
    String? bodyDelta,
    String? folderId,
  }) async {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index == -1) {
      return;
    }

    final current = _notes[index];
    final folder = _lookupFolder(folderId);
    _notes[index] = NoteRecord(
      id: current.id,
      title: title,
      body: body,
      bodyDelta: bodyDelta,
      summary: current.summary,
      folderId: folder?.id,
      folderName: folder?.name,
      isPinned: current.isPinned,
      isArchived: current.isArchived,
      isDeleted: current.isDeleted,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: current.deletedAt,
    );
  }

  @override
  Future<void> togglePin({
    required String id,
    required bool value,
  }) async {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index == -1) {
      return;
    }

    final current = _notes[index];
    _notes[index] = NoteRecord(
      id: current.id,
      title: current.title,
      body: current.body,
      bodyDelta: current.bodyDelta,
      summary: current.summary,
      folderId: current.folderId,
      folderName: current.folderName,
      isPinned: value,
      isArchived: current.isArchived,
      isDeleted: current.isDeleted,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: current.deletedAt,
    );
    _notes.sort((a, b) {
      final pinCompare = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
      if (pinCompare != 0) {
        return pinCompare;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  @override
  Future<void> setArchived({
    required String id,
    required bool value,
  }) async {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index == -1) {
      return;
    }

    final current = _notes[index];
    _notes[index] = NoteRecord(
      id: current.id,
      title: current.title,
      body: current.body,
      bodyDelta: current.bodyDelta,
      summary: current.summary,
      folderId: current.folderId,
      folderName: current.folderName,
      isPinned: current.isPinned,
      isArchived: value,
      isDeleted: false,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: null,
    );
  }

  @override
  Future<void> moveToTrash(String id) async {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index == -1) {
      return;
    }

    final current = _notes[index];
    _notes[index] = NoteRecord(
      id: current.id,
      title: current.title,
      body: current.body,
      bodyDelta: current.bodyDelta,
      summary: current.summary,
      folderId: current.folderId,
      folderName: current.folderName,
      isPinned: false,
      isArchived: false,
      isDeleted: true,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: DateTime.now(),
    );
  }

  @override
  Future<void> restoreFromTrash(String id) async {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index == -1) {
      return;
    }

    final current = _notes[index];
    _notes[index] = NoteRecord(
      id: current.id,
      title: current.title,
      body: current.body,
      bodyDelta: current.bodyDelta,
      summary: current.summary,
      folderId: current.folderId,
      folderName: current.folderName,
      isPinned: current.isPinned,
      isArchived: false,
      isDeleted: false,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: null,
    );
  }

  @override
  Future<void> deletePermanently(String id) async {
    _notes.removeWhere((note) => note.id == id);
  }

  NoteFolder? _lookupFolder(String? folderId) {
    if (folderId == null) {
      return null;
    }
    for (final folder in _folders) {
      if (folder.id == folderId) {
        return folder;
      }
    }
    return null;
  }
}
