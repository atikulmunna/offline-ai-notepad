# Competitive Roadmap

Features to make Offline AI Notepad competitive with established note apps
(Notion, OneNote, Apple Notes, Google Keep, Obsidian, Standard Notes).

## Strategy

We will not out-feature cloud suites on their turf (collaboration, infinite
databases, cross-platform polish). Our moat is the one thing they structurally
cannot match: **real AI that runs fully on-device, offline, and private**.

Two workstreams run against that thesis:

1. **Moat** — deepen the on-device AI so it does things no cloud app can do
   privately. Most of this reuses embeddings and models we already load.
2. **Table stakes** — close the gaps whose *absence* gets us dismissed in the
   first five minutes, even if they are not differentiators.

We work these **one task at a time, top to bottom**. Each task lists why it
matters, scope, technical approach, and dependencies. Status legend:
`[ ]` not started · `[~]` in progress · `[x]` done.

---

## Track A — Moat: On-Device AI

### A1. Ask Your Notes (RAG Q&A)  `[x]`
**Why:** Highest differentiation, lowest incremental cost. No cloud notes app
can answer questions over your library privately. We already store per-note
embeddings in SQLite, so ~80% of the retrieval half exists.

**Scope:** A chat/query surface where a natural-language question returns an
answer synthesized from the user's own notes, with citation links back to the
source notes.

**Approach:**
- Embed the question with the existing MiniLM path.
- Retrieve top-K notes by cosine (reuse `vector_note_search.dart`).
- Assemble a grounded prompt (retrieved chunks + question) and generate with an
  on-device instruct/summarizer model; start by reusing the summarizer, then
  evaluate a small instruct model if quality is weak.
- Render the answer with tap-through citations to source notes.
- Fall back to a "top matching notes" list (no synthesis) when no native model
  is available (non-Android / model missing).

**Dependencies:** existing embeddings + ONNX runtime. Benefits from A5 chunking.

### A2. Auto-Everything on Save  `[~]`
**Why:** Turns AI from a button you press into an assistant that quietly
organizes. Uses models already loaded.

**Scope:** On save (debounced), optionally: auto-title untitled notes,
auto-generate/refresh a summary, and suggest a folder and tags.

**Status (v1 shipped):** title + folder suggestions surfaced as non-destructive
tappable chips in the editor (debounced after typing), gated by a persisted
"Smart suggestions" toggle in the Appearance sheet. Deferred: auto-summary on
save (battery-sensitive; summary already exists as a manual action) and tag
suggestions (blocked on B3 tags).

**Approach:**
- Reuse the summarizer for title + summary generation.
- Folder/tag suggestion via nearest-neighbor over existing note embeddings
  (which folder/tags do the most-similar notes have?).
- Suggestions are non-destructive: surface them, let the user accept.
- Respect a per-feature toggle in Appearance/Settings.

**Dependencies:** B3 (tags) for tag suggestions.

### A3. Smart "Related Notes"  `[x]`
**Why:** Cheap, feels magical, gives Obsidian-style connection without manual
`[[links]]`. Pure reuse of similarity we already compute.

**Scope:** A "See also" strip at the bottom of each note showing the most
semantically similar notes.

**Approach:** Cosine top-N over stored embeddings, excluding self; cache per
note and invalidate on edit. Static list in the editor (no live compute on the
typing path).

**Dependencies:** existing embeddings.

### A4. On-Device Voice → Note  `[ ]`
**Why:** Voice memos that become searchable text with no cloud round-trip is a
strong, demoable hook.

**Scope:** Record audio, transcribe offline, create a note; optionally
auto-summarize the transcript.

**Approach:** Add a small Whisper (or equivalent) ONNX model to the manifest,
delivered on demand like the current models. Feed the transcript through the
existing summarizer. Android-first; graceful "not available" elsewhere.

**Dependencies:** model export/delivery pipeline (existing pattern).

### A5. On-Device OCR  `[ ]`
**Why:** Snap a whiteboard/receipt/page and make it semantically searchable —
pairs directly with existing search.

**Scope:** Import an image, extract text on-device, store as note body (keep the
image as an attachment), index for search.

**Approach:** On-device OCR (ML Kit on Android, or an ONNX OCR model to stay
runtime-consistent). Extracted text flows into the normal embed-on-save path.

**Dependencies:** B2 (image attachments).

---

## Track B — Table Stakes

### B1. Checklists / To-Do Items  `[x]`
**Why:** The #1 thing people do in Keep/Apple Notes; absence is disqualifying.
**Scope:** Tappable checkbox list items inside a note; check/uncheck persists.
**Approach:** Use flutter_quill's list/checkbox attributes; ensure the plain-text
`body` projection stays sensible for search/AI.

### B2. Images & Attachments  `[ ]`
**Why:** Baseline expectation; also unlocks A5 (OCR).
**Scope:** Insert images inline; store files locally; show in editor and preview.
**Approach:** Local file storage with a DB reference; embed in the Quill delta;
keep binaries out of the text body. Consider size/perf on the note list.

### B3. Tags  `[ ]`
**Why:** Flexible complement to folders; feeds A2 auto-tagging.
**Scope:** Add/remove tags on a note; filter/search by tag.
**Approach:** Tags table already anticipated in the schema (Epic 2). Add UI +
query paths; wire into search filters.

### B4. Quick Capture (Widget + Share Sheet)  `[ ]`
**Why:** Capture friction kills note apps; established apps all have this.
**Scope:** Android home-screen widget for a new note, and register as an Android
share target ("share to notepad" from any app).
**Approach:** Native Android widget + share-intent handling bridged into the
note-create flow. Android-only.

### B5. Reminders / Due Dates  `[ ]`
**Why:** Common expectation for actionable notes.
**Scope:** Attach a reminder/due date to a note; local notification fires.
**Approach:** Local notifications plugin; store due date on the note; simple
"upcoming" filter.

### B6. Markdown Import/Export  `[ ]`
**Why:** Wins the Obsidian/Joplin crowd and reinforces the no-lock-in privacy
story.
**Scope:** Export notes to Markdown and import Markdown files.
**Approach:** Quill delta ↔ Markdown conversion; batch export; import into the
create flow.

---

## Track C — Strategic Fork: Sync (decide before building)

Established apps win on "it's on all my devices." We are offline-only with
encrypted backup today. This is a real product decision, not just an
engineering one — **pick a lane before committing:**

- **C-a. Local-only + effortless E2E backup/transfer** — keep the privacy story
  pure; make encrypted backup/restore trivial (QR/file transfer between
  devices). Lower risk.
- **C-b. E2E-encrypted sync** (à la Standard Notes) — real multi-device sync
  without giving up privacy. Higher effort, higher payoff.

Not scheduled as a task yet; needs an explicit decision first.

---

## Track D — Moonshots (later)

### D1. Daily/Weekly Digest  `[ ]`
On-device summary of everything written in a period.

### D2. Auto-Clustering  `[ ]`
Group loose notes into suggested folders via embedding clustering.

### D3. Stylus / Handwriting  `[ ]`
Only worth it for S Pen (Ultra/tablet) targets — the S23+ has no stylus. Deprioritized.

---

## Suggested build order

1. **A1 — Ask Your Notes** (flagship differentiator, reuses existing embeddings)
2. **B1 — Checklists** (fast table-stakes win, high daily-use value)
3. **A3 — Related Notes** (cheap, high delight, pure reuse)
4. **B3 — Tags** → unblocks **A2 — Auto-everything**
5. **B4 — Quick Capture** (reduces capture friction)
6. Then: B2 → A5, B2/B5/B6, A4, and revisit Track C.
