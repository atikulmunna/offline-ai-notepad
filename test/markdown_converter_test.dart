import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai_notepad/features/notes/domain/markdown_converter.dart';

void main() {
  group('deltaToMarkdown', () {
    test('renders inline bold, italic, strikethrough', () {
      final md = MarkdownConverter.deltaToMarkdown([
        {'insert': 'Plain '},
        {'insert': 'bold', 'attributes': {'bold': true}},
        {'insert': ' and '},
        {'insert': 'gone', 'attributes': {'strike': true}},
        {'insert': '\n'},
      ]);
      expect(md.trim(), 'Plain **bold** and ~~gone~~');
    });

    test('renders bullet, ordered, and checkbox lists', () {
      final md = MarkdownConverter.deltaToMarkdown([
        {'insert': 'one'},
        {'insert': '\n', 'attributes': {'list': 'bullet'}},
        {'insert': 'first'},
        {'insert': '\n', 'attributes': {'list': 'ordered'}},
        {'insert': 'second'},
        {'insert': '\n', 'attributes': {'list': 'ordered'}},
        {'insert': 'done'},
        {'insert': '\n', 'attributes': {'list': 'checked'}},
        {'insert': 'todo'},
        {'insert': '\n', 'attributes': {'list': 'unchecked'}},
      ]);
      expect(md.trim().split('\n'), [
        '- one',
        '1. first',
        '2. second',
        '- [x] done',
        '- [ ] todo',
      ]);
    });

    test('prepends the title as an H1', () {
      final md = MarkdownConverter.deltaToMarkdown(
        [
          {'insert': 'Body text\n'},
        ],
        title: 'My Note',
      );
      expect(md, startsWith('# My Note\n\n'));
      expect(md, contains('Body text'));
    });
  });

  group('markdownToNote', () {
    test('extracts a leading H1 as the title', () {
      final note = MarkdownConverter.markdownToNote('# Groceries\n\nMilk\nEggs');
      expect(note.title, 'Groceries');
      expect(note.plainText, 'Milk\nEggs');
    });

    test('parses checkbox items into checklist ops', () {
      final note = MarkdownConverter.markdownToNote('- [ ] todo\n- [x] done');
      final blocks = note.deltaOps
          .where((op) => (op['insert'] as String) == '\n')
          .map((op) => (op['attributes'] as Map?)?['list'])
          .toList();
      expect(blocks, contains('unchecked'));
      expect(blocks, contains('checked'));
    });

    test('parses inline bold into an attributed op', () {
      final note = MarkdownConverter.markdownToNote('hello **world**');
      final bold = note.deltaOps.firstWhere(
        (op) => (op['attributes'] as Map?)?['bold'] == true,
        orElse: () => {},
      );
      expect(bold['insert'], 'world');
      expect(note.plainText, 'hello world');
    });
  });

  group('round-trip', () {
    test('delta -> markdown -> note preserves structure and text', () {
      final ops = [
        {'insert': 'Buy milk'},
        {'insert': '\n', 'attributes': {'list': 'unchecked'}},
        {'insert': 'Call '},
        {'insert': 'Sam', 'attributes': {'bold': true}},
        {'insert': '\n'},
      ];
      final md = MarkdownConverter.deltaToMarkdown(ops, title: 'Tasks');
      final note = MarkdownConverter.markdownToNote(md);

      expect(note.title, 'Tasks');
      expect(note.plainText, contains('Buy milk'));
      expect(note.plainText, contains('Call Sam'));
      final hasChecklist = note.deltaOps.any(
        (op) => (op['attributes'] as Map?)?['list'] == 'unchecked',
      );
      final hasBold = note.deltaOps.any(
        (op) => (op['attributes'] as Map?)?['bold'] == true,
      );
      expect(hasChecklist, isTrue);
      expect(hasBold, isTrue);
    });
  });
}
