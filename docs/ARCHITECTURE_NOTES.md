# Architecture Notes

## v1 shape

- Plain-text offline note app first.
- AI features are additive, not foundational.
- The app must remain useful when no model loads successfully.

## Module outline

- `core`: cross-cutting concerns such as crypto, database, errors, and shared utilities
- `features/notes`: note entities, repositories, use cases, and UI
- `features/search`: keyword and semantic search orchestration
- `features/folders`: folder management
- `features/settings`: model info, security, theme, and backup preferences
- `ai/summarization`: summarization interface and runtime integration
- `ai/embedding`: embedding generation and vector indexing
- `ai/runtime`: ONNX/TFLite wrappers and isolate coordination

## Critical engineering rules

- Never persist plaintext note content intentionally.
- Keep note CRUD independent from AI availability.
- Prefer fallback behavior over hard failure for semantic features.
