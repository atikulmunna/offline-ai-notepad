# Offline AI Notepad

Offline AI Notepad is a privacy-first note-taking app built with Flutter. It stores notes locally, supports rich-text editing, and adds on-device AI features such as note summarization without requiring a cloud account or an always-on internet connection.

This project is being built as an offline-first product, which means the app should remain useful even when network access is unavailable. Notes, folders, archive/trash flows, rich-text formatting, and local persistence work independently of any remote backend. AI features are also designed around local model execution instead of a hosted API.

## Why This Project Exists

Most modern note apps either depend heavily on cloud sync or treat AI as a server-side feature. This project explores a different direction:

- your notes live on your device by default
- core note-taking should still work without internet
- AI assistance should be local whenever possible
- the architecture should allow model upgrades without rewriting the app

The current codebase focuses on building a solid local-first foundation first, then layering in on-device AI safely and incrementally.

## Current Status

This is an active work-in-progress project with a functioning app foundation.

What already works:

- note creation and editing
- rich-text note body formatting
- note folders
- pin, archive, trash, restore, and permanent delete flows
- local persistence with SQLite
- on-device AI summary workflow
- local model manifest, installation checks, and runtime staging
- Android ONNX bridge scaffolding for local model execution

What is still evolving:

- summary quality from the native ONNX path
- semantic search and embeddings UX polish
- encryption and export/import hardening
- developer diagnostics cleanup in some AI surfaces

## Core Features

### Note Management

- Create, edit, and save notes locally
- Organize notes into folders
- Pin important notes
- Archive notes you want to keep but hide from the main list
- Move notes to trash and restore or delete them permanently
- Search by note title or body text

### Rich Text Editing

The note body now supports formatting through a rich-text editor.

Available formatting includes:

- bold
- italic
- underline
- strikethrough
- text color
- highlight/background color
- clear formatting

The app stores:

- a plain-text body for search, previews, and AI processing
- a rich-text delta for editor formatting and restoration

This allows the app to keep useful plain-text workflows while preserving formatted note content.

### Local AI Summary

Each note has an AI Summary section that can generate a short recap of the current note.

Important design goals:

- no cloud API is required for the summary feature
- model/runtime setup is handled locally
- if the native AI path is not ready or returns weak output, the app falls back to a local summarization path instead of failing completely

This is why the summary feature is usable today, even though the native ONNX generation loop is still being refined.

## How The App Works

### 1. Data Storage

The app uses SQLite for local persistence.

Notes currently store:

- `title`
- `body` as plain text
- `body_delta` as rich-text content
- `summary`
- folder relationship
- pin/archive/delete state
- timestamps

This split lets the app:

- render rich text in the editor
- keep search simple and fast
- pass plain text into local AI summarization

### 2. Note Editor

The note editor uses:

- a standard text field for the title
- a folder picker
- a `flutter_quill` rich-text editor for the note body

Autosave watches title and body changes. When the note contains content, it persists updates locally after a short delay.

### 3. AI Runtime Layer

The app does not hard-code itself to one AI SDK. Instead, it talks to an internal runtime abstraction.

That means the stack looks like this:

- Flutter UI
- app feature layer
- `AiRuntime` interface
- local runtime implementation
- model files staged on device

This is important because it keeps the product architecture stable even if the low-level inference backend changes later.

### 4. Local Model Pipeline

The current project includes:

- a model manifest
- installation checks
- packaged asset staging
- Android ONNX runtime bridge code
- FLAN-T5 small local summarization experiments

The app can inspect whether model assets exist, whether they were staged to a runtime directory, and whether the native runtime is available.

## AI Stack Overview

The current local AI path is based on ONNX Runtime for Android, with FLAN-T5-small as the first summarization target.

High-level flow:

1. the app checks the local model manifest
2. packaged model assets are validated
3. assets are staged into a runtime-friendly directory
4. the Android bridge prepares ONNX sessions
5. a summary is generated locally
6. if native output is weak or unavailable, the app falls back to a local summarizer

This staged approach is intentional. It keeps the app usable while the native inference path is still being improved.

## Project Structure

This is the most important structure to understand as a newcomer:

```text
lib/
  app/                      App shell and theme
  core/                     Shared infrastructure such as database setup
  features/
    ai/                     AI runtime, model manifest, staging, summary flow
    notes/                  Notes domain, repositories, views, editor, actions

android/
  app/src/main/kotlin/      Android ONNX bridge and native runtime code

assets/
  models/                   Manifest and locally staged model asset slots

docs/
  DEVELOPMENT_SETUP.md      Local dev environment notes
  LOCAL_MODEL_SETUP.md      How local model export/staging works
  ARCHITECTURE_NOTES.md     Architectural direction and tradeoffs
```

## Technology Stack

- Flutter
- Dart
- Riverpod
- SQLite via `sqflite`
- `flutter_quill` for rich-text editing
- ONNX Runtime Android for local model inference

## Getting Started

### Prerequisites

You should have:

- Flutter installed
- Android Studio or another Android SDK installation if you want Android builds
- a working Dart/Flutter toolchain

This repo currently uses:

- Flutter `3.41.5`
- Dart `3.11.3`

See [docs/DEVELOPMENT_SETUP.md](docs/DEVELOPMENT_SETUP.md) for environment notes.

### Install Dependencies

From the project root:

```powershell
flutter pub get
```

### Run The App

### Windows

```powershell
flutter run -d windows
```

If Windows build fails with a symlink warning, enable Developer Mode in Windows settings first.

### Chrome

```powershell
flutter run -d chrome
```

### Android Emulator

1. Start an emulator from Android Studio Device Manager, or launch one manually.
2. Verify Flutter can see it:

```powershell
flutter devices
```

3. Run the app:

```powershell
flutter run
```

If the emulator is unstable, a cold boot usually helps.

### Android Notes

If Android tooling is partially configured, you may need:

```powershell
flutter doctor
flutter doctor --android-licenses
```

### Rich Text Formatting Guide

Inside a note:

1. open or create a note
2. tap in the body editor
3. use the formatting toolbar above the editor

You can apply styles like:

- bold
- italic
- underline
- strikethrough
- text color
- background highlight

Formatting is stored with the note and should return when the note is reopened.

### Local AI Model Setup

Large model binaries are intentionally kept out of normal Git history.

To export and stage the local FLAN-T5 small summarization model:

```powershell
.\scripts\export_flan_t5_small.ps1
```

That script:

1. exports `google/flan-t5-small` to ONNX
2. quantizes the encoder and decoder
3. copies the generated files into the expected local asset staging area
4. makes the tokenizer/config files available for runtime inspection

See [docs/LOCAL_MODEL_SETUP.md](docs/LOCAL_MODEL_SETUP.md) for more detail.

### What Happens When You Tap “Generate Summary”

At a simple level:

1. the note is saved locally if needed
2. the app reads the plain-text version of the note body
3. the AI runtime tries the local ONNX path
4. if the ONNX result is weak or unavailable, the app falls back to a local summary path
5. the result is stored on the note and shown in the editor

This means the summary feature can still feel responsive even while the native AI path is being improved.

### Newbie FAQ

### Why store both plain text and rich text?

Rich text is good for the editor. Plain text is simpler for search, previews, and AI processing. Keeping both is a practical tradeoff.

### Why not just call an AI API?

Because the goal of this project is offline, privacy-first AI. A hosted API would weaken that core product promise.

### Why are there AI details in the editor?

Because the local model/runtime pipeline is still under active development. The UI has already been simplified, but some diagnostics are still intentionally accessible while the native path is being tuned.

### Why does the summary quality vary?

The app currently prefers the native ONNX path when it looks usable, but falls back when output is clearly weak. That makes the feature usable today, while the native decoder/tokenization path continues to mature.

## Known Limitations

- Native ONNX summary quality is still being tuned
- Android emulators can be unstable for heavier local model work
- Some setup steps are still more developer-oriented than end-user polished
- The AI surface is ahead of the final product polish in a few places

## Documentation

- [docs/DEVELOPMENT_SETUP.md](docs/DEVELOPMENT_SETUP.md)
- [docs/LOCAL_MODEL_SETUP.md](docs/LOCAL_MODEL_SETUP.md)
- [docs/ARCHITECTURE_NOTES.md](docs/ARCHITECTURE_NOTES.md)
- [docs/IMPLEMENTATION_BACKLOG.md](docs/IMPLEMENTATION_BACKLOG.md)

## Repository Notes

- Local planning artifacts such as the SRS are intentionally not tracked in Git.
- Large local model files are also intentionally excluded from standard Git history.

## Summary

Offline AI Notepad is a Flutter-based experiment in private, offline-first note-taking with local AI assistance. It already has a solid local product core, a functioning rich-text editor, and a serious on-device AI architecture. The remaining work is mostly about improving summary quality, reducing debug-heavy surfaces, and continuing the transition from a capable prototype into a polished product.
