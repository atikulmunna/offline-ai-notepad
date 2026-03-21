class DatabaseSchema {
  static const databaseName = 'offline_ai_notepad.db';
  static const databaseVersion = 1;

  static const notesTable = 'notes';
  static const foldersTable = 'folders';
  static const tagsTable = 'tags';
  static const noteTagsTable = 'note_tags';
  static const embeddingsTable = 'embeddings';

  static const createNotesTable = '''
CREATE TABLE notes (
  id TEXT PRIMARY KEY,
  title TEXT,
  body TEXT NOT NULL,
  summary TEXT,
  folder_id TEXT,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  is_archived INTEGER NOT NULL DEFAULT 0,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);
''';

  static const createFoldersTable = '''
CREATE TABLE folders (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT DEFAULT 'folder',
  created_at INTEGER NOT NULL
);
''';

  static const createTagsTable = '''
CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  color_hex TEXT DEFAULT '#607D8B',
  is_custom INTEGER NOT NULL DEFAULT 0
);
''';

  static const createNoteTagsTable = '''
CREATE TABLE note_tags (
  note_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  confidence REAL,
  source TEXT DEFAULT 'ai',
  PRIMARY KEY (note_id, tag_id),
  FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);
''';

  static const createEmbeddingsTable = '''
CREATE TABLE embeddings (
  note_id TEXT PRIMARY KEY,
  model_ver TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
);
''';

  static const allCreateStatements = [
    createNotesTable,
    createFoldersTable,
    createTagsTable,
    createNoteTagsTable,
    createEmbeddingsTable,
  ];
}
