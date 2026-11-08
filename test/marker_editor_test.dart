import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_shower/services/marker_editor.dart';

void main() {
  group('wrapHide', () {
    test('包裹选区并保持选中原文', () {
      final result = MarkerEditor.wrapHide(
        text: 'hello',
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
        group: '英文',
      );
      final open = '{hide:英文}';
      expect(result.text, '{hide:英文}hello{/hide}');
      expect(result.selection.start, open.length);
      expect(result.selection.end, open.length + 5);
    });

    test('空选区保持原样', () {
      final result = MarkerEditor.wrapHide(
        text: 'hello',
        selection: const TextSelection.collapsed(offset: 0),
        group: '英文',
      );
      expect(result.text, 'hello');
    });
  });

  group('removeHideMarkers', () {
    test('移除与选区相交的标记对', () {
      final result = MarkerEditor.removeHideMarkers(
        text: 'a{hide:x}bc{/hide}d',
        selection: const TextSelection(baseOffset: 9, extentOffset: 11),
      );
      expect(result.text, 'abcd');
      expect(result.selection.start, 1);
      expect(result.selection.end, 3);
    });

    test('移除嵌套标记对', () {
      final result = MarkerEditor.removeHideMarkers(
        text: '{hide:a}x{hide:b}y{/hide}z{/hide}',
        selection: const TextSelection(baseOffset: 0, extentOffset: 100),
      );
      expect(result.text, 'xyz');
    });

    test('没有相交标记时保持原样', () {
      final result = MarkerEditor.removeHideMarkers(
        text: 'abc',
        selection: const TextSelection(baseOffset: 0, extentOffset: 3),
      );
      expect(result.text, 'abc');
      expect(result.selection, const TextSelection(baseOffset: 0, extentOffset: 3));
    });

    test('空选区不处理', () {
      final result = MarkerEditor.removeHideMarkers(
        text: '{hide:a}x{/hide}',
        selection: const TextSelection.collapsed(offset: 2),
      );
      expect(result.text, '{hide:a}x{/hide}');
    });
  });
}
