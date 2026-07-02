import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai_notepad/features/notes/domain/note_body_text.dart';

void main() {
  group('normalizeNoteBodyText', () {
    test('collapses non-breaking spaces to normal spaces', () {
      expect(normalizeNoteBodyText('a\u{00A0}b'), 'a b');
    });

    test('strips embed object-replacement characters', () {
      expect(normalizeNoteBodyText('before\u{FFFC}after'), 'beforeafter');
    });

    test('trims surrounding whitespace', () {
      expect(normalizeNoteBodyText('  hello  '), 'hello');
    });

    test('keeps ordinary text untouched', () {
      expect(normalizeNoteBodyText('meeting notes'), 'meeting notes');
    });
  });

  group('image embeds and the searchable body', () {
    test('an inserted image leaves no text in the normalized body', () {
      final document = Document()..insert(0, 'caption');
      // Insert an image block embed at the start of the document.
      document.insert(0, BlockEmbed.image('img_123.png'));

      final normalized =
          normalizeNoteBodyText(document.toPlainText());
      // The image contributes only an object-replacement char, which we strip.
      expect(normalized, 'caption');
      expect(normalized.contains('img_123.png'), isFalse);
      expect(normalized.contains('\u{FFFC}'), isFalse);
    });
  });
}
