import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the checklist feature's persistence: a checkbox list item must
/// survive the exact delta-JSON encode/decode the editor uses on save/reload,
/// and its checked/unchecked state must be preserved.
void main() {
  List<Map<String, dynamic>> roundTrip(QuillController controller) {
    final json = jsonEncode(controller.document.toDelta().toJson());
    final restored = Document.fromJson(jsonDecode(json) as List<dynamic>);
    return restored
        .toDelta()
        .toJson()
        .map((op) => op as Map<String, dynamic>)
        .toList();
  }

  bool hasListValue(List<Map<String, dynamic>> ops, String value) {
    return ops.any((op) {
      final attributes = op['attributes'];
      return attributes is Map && attributes['list'] == value;
    });
  }

  test('unchecked checklist item round-trips through delta json', () {
    final controller = QuillController.basic();
    controller.document.insert(0, 'Buy milk');
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 8),
      ChangeSource.local,
    );
    controller.formatSelection(Attribute.unchecked);

    expect(hasListValue(roundTrip(controller), 'unchecked'), isTrue);
  });

  test('checked state is preserved through delta json', () {
    final controller = QuillController.basic();
    controller.document.insert(0, 'Done task');
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 9),
      ChangeSource.local,
    );
    controller.formatSelection(Attribute.checked);

    expect(hasListValue(roundTrip(controller), 'checked'), isTrue);
  });

  test('plain-text projection keeps the item text for search/AI', () {
    final controller = QuillController.basic();
    controller.document.insert(0, 'Call the dentist');
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 16),
      ChangeSource.local,
    );
    controller.formatSelection(Attribute.unchecked);

    expect(controller.document.toPlainText(), contains('Call the dentist'));
  });
}
