import 'dart:math' as math;

import 'package:flutter/services.dart' show TextSelection;

class MarkerEditResult {
  const MarkerEditResult(this.text, this.selection);

  final String text;
  final TextSelection selection;
}

class MarkerEditor {
  const MarkerEditor._();

  static MarkerEditResult wrapHide({
    required String text,
    required TextSelection selection,
    required String group,
  }) {
    final range = _normalized(selection, text.length);
    if (range == null) return MarkerEditResult(text, selection);
    final start = range.$1;
    final end = range.$2;
    final open = '{hide:$group}';
    const close = '{/hide}';
    final output =
        '${text.substring(0, start)}$open${text.substring(start, end)}$close${text.substring(end)}';
    return MarkerEditResult(
      output,
      TextSelection(
        baseOffset: start + open.length,
        extentOffset: end + open.length,
      ),
    );
  }

  static MarkerEditResult removeHideMarkers({
    required String text,
    required TextSelection selection,
  }) {
    final range = _normalized(selection, text.length);
    if (range == null) return MarkerEditResult(text, selection);
    final start = range.$1;
    final end = range.$2;

    final ranges = <_Range>[];
    for (final pair in _pairs(text)) {
      if (pair.openStart < end && pair.closeEnd > start) {
        ranges.add(_Range(pair.openStart, pair.openEnd));
        ranges.add(_Range(pair.closeStart, pair.closeEnd));
      }
    }
    if (ranges.isEmpty) return MarkerEditResult(text, selection);

    ranges.sort((a, b) => a.start.compareTo(b.start));
    final newText = _removeRanges(text, ranges);
    final newStart = _shift(start, ranges);
    final newEnd = _shift(end, ranges);
    return MarkerEditResult(
      newText,
      TextSelection(baseOffset: newStart, extentOffset: newEnd),
    );
  }

  static List<_Pair> _pairs(String text) {
    final pairs = <_Pair>[];
    final stack = <_Open>[];
    var i = 0;
    while (i < text.length) {
      if (text[i] == '\\') {
        i += (i + 1 < text.length) ? 2 : 1;
        continue;
      }
      if (text.startsWith('{/hide}', i)) {
        if (stack.isNotEmpty) {
          final open = stack.removeLast();
          pairs.add(_Pair(
            open.start,
            open.nameEnd,
            i,
            i + 7,
          ));
        }
        i += 7;
        continue;
      }
      if (text.startsWith('{hide:', i)) {
        final lineEnd = text.indexOf('\n', i);
        final close = text.indexOf('}', i + 6);
        if (close != -1 && (lineEnd == -1 || close < lineEnd)) {
          final name = text.substring(i + 6, close).trim();
          if (_validGroupName(name)) {
            stack.add(_Open(i, close + 1));
            i = close + 1;
            continue;
          }
        }
      }
      i++;
    }
    return pairs;
  }

  static bool _validGroupName(String name) {
    return name.isNotEmpty &&
        !name.contains('{') &&
        !name.contains('}') &&
        !name.contains(':') &&
        !name.contains('\n');
  }

  static (int, int)? _normalized(TextSelection selection, int length) {
    if (!selection.isValid) return null;
    var start = selection.start;
    var end = selection.end;
    if (start > end) {
      final swap = start;
      start = end;
      end = swap;
    }
    start = start.clamp(0, length);
    end = end.clamp(0, length);
    if (start == end) return null;
    return (start, end);
  }

  static String _removeRanges(String text, List<_Range> ranges) {
    final sorted = List<_Range>.of(ranges)
      ..sort((a, b) => a.start.compareTo(b.start));
    final buffer = StringBuffer();
    var cursor = 0;
    for (final range in sorted) {
      if (range.start > cursor) {
        buffer.write(text.substring(cursor, range.start));
      }
      if (range.end > cursor) cursor = range.end;
    }
    if (cursor < text.length) buffer.write(text.substring(cursor));
    return buffer.toString();
  }

  static int _shift(int offset, List<_Range> ranges) {
    var removed = 0;
    for (final range in ranges) {
      if (range.start >= offset) break;
      final end = math.min(range.end, offset);
      if (end > range.start) removed += end - range.start;
    }
    return offset - removed;
  }
}

class _Open {
  const _Open(this.start, this.nameEnd);

  final int start;
  final int nameEnd;
}

class _Pair {
  const _Pair(
    this.openStart,
    this.openEnd,
    this.closeStart,
    this.closeEnd,
  );

  final int openStart;
  final int openEnd;
  final int closeStart;
  final int closeEnd;
}

class _Range {
  const _Range(this.start, this.end);

  final int start;
  final int end;
}
