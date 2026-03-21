# Offline AI Notepad

Offline-first mobile notepad with on-device AI summarization, semantic search, and encrypted local storage.

## Status

Early project setup. The initial public repository intentionally excludes local planning documents such as the SRS.

## Development Environment

- Flutter SDK baseline: `3.41.5` on the stable channel
- Dart SDK: `3.11.3`
- Recommended policy: stay on the `3.41.x` stable line unless a plugin or CI compatibility issue forces a temporary pin to `3.40.x`

### Why not `3.40.x` by default?

`3.40` is not the current stable line for this setup. We are standardizing on `3.41.5`, which is newer and already installed locally. We should only fall back to `3.40.x` if a dependency compatibility issue appears and we need a short-term stability pin.

## Vision

- Private note-taking by default
- On-device AI assistance without mandatory cloud dependency
- Encrypted local storage and portable encrypted backups
- Fast, mobile-friendly search across notes
