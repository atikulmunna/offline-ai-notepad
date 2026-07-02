/// Normalizes the raw plain-text projection of a note body.
///
/// Collapses non-breaking spaces (U+00A0) to normal spaces and strips embed
/// object-replacement characters (U+FFFC) so image/attachment embeds never
/// leak into the searchable/AI-indexed text. Kept pure so it can be unit
/// tested without spinning up the Quill editor.
String normalizeNoteBodyText(String raw) {
  return raw
      .replaceAll('\u{00A0}', ' ')
      .replaceAll('\u{FFFC}', '')
      .trim();
}
