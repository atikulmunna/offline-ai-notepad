# Implementation Backlog

## Epic 1: Project Foundation

### Story 1.1: Initialize Flutter application structure
- Create the Flutter app in the repository root.
- Add the core folder structure for `core`, `features`, and `ai`.
- Configure linting and baseline analysis.

### Story 1.2: Establish architecture boundaries
- Define repository, service, and use case interfaces.
- Separate presentation, domain, data, and runtime concerns.
- Add placeholder modules for notes, search, folders, settings, and AI.

### Story 1.3: Add CI baseline
- Run formatting, static analysis, and tests on push.
- Keep the pipeline lightweight until mobile builds are added.

## Epic 2: Local Notes v1

### Story 2.1: Define database schema and migrations
- Create notes, folders, tags, and embedding metadata tables.
- Add migration support for future schema evolution.

### Story 2.2: Implement encrypted note storage
- Encrypt note title, body, and summary fields at rest.
- Store the local encryption key using platform-protected storage.
- Document import/export encryption separately from device storage encryption.

### Story 2.3: Build note CRUD flows
- Create, edit, archive, pin, delete, and restore notes.
- Preserve timestamps and folder assignment.

### Story 2.4: Add autosave editor
- Use a plain-text editor for v1.
- Autosave without blocking the UI.
- Recover safely after interruption.

### Story 2.5: Add keyword search and filters
- Integrate SQLite FTS.
- Support folder and date filtering.

## Epic 3: On-Device AI v1

### Story 3.1: Summarization runtime abstraction
- Define an inference interface for summarization.
- Ensure the app can hide or disable AI gracefully.

### Story 3.2: Embedding generation and index queue
- Generate embeddings asynchronously after note save.
- Track embedding states as `pending`, `ready`, `stale`, or `failed`.
- Support reindexing after note updates or model-version changes.

### Story 3.3: Semantic search
- Query the vector store when available.
- Fall back gracefully if the vector runtime is unavailable.

## Epic 4: Backup and Release Readiness

### Story 4.1: Encrypted export/import
- Export note data using a passphrase-derived key.
- Re-encrypt imported content with the current device key.

### Story 4.2: QA and performance validation
- Benchmark note save, search, startup, and inference latency.
- Validate low-memory behavior and no-data-loss paths.

### Story 4.3: Accessibility and onboarding
- Add privacy-first onboarding.
- Validate text scaling, contrast, and essential accessibility behavior.
