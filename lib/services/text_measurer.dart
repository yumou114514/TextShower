import 'dart:collection';
import 'package:flutter/painting.dart';

import '../models/parsed_document.dart';

/// 共享字号 / 行高 / 测量与渲染样式，保证 TextPainter 测出的高度与实际渲染一致。
class TextMeasurer {
  TextMeasurer();

  static const double lineHeight = 1.4;
  static const double minFontSize = 14;
  static const double maxFontSize = 200;

  final HashMap<Block, Map<String, double>> _heightCache =
      HashMap<Block, Map<String, double>>.identity();

  static TextStyle styleFor(double fontSize,
          {Color color = const Color(0xFF000000)}) =>
      TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        letterSpacing: 0,
        wordSpacing: 0,
        color: color,
      );

  static StrutStyle strutFor(double fontSize) => StrutStyle(
        fontSize: fontSize,
        height: lineHeight,
        forceStrutHeight: true,
        leadingDistribution: TextLeadingDistribution.even,
      );

  static TextSpan spanFor(
    Block block,
    double fontSize, {
    Color color = const Color(0xFF000000),
  }) =>
      TextSpan(
        style: styleFor(fontSize, color: color),
        children: <InlineSpan>[
          for (final run in block.runs) TextSpan(text: run.text),
        ],
      );

  double measureBlock(Block block, double fontSize, double maxWidth) {
    if (maxWidth <= 0) return double.infinity;
    final key = '${fontSize.toStringAsFixed(3)}|${maxWidth.toStringAsFixed(3)}';
    final cached = _heightCache[block]?[key];
    if (cached != null) return cached;

    final painter = TextPainter(
      text: spanFor(block, fontSize),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
      textScaler: TextScaler.noScaling,
      strutStyle: strutFor(fontSize),
    )..layout(maxWidth: maxWidth);
    final height = painter.height;
    painter.dispose();

    _heightCache.putIfAbsent(block, () => <String, double>{})[key] = height;
    return height;
  }

  void clearCache() => _heightCache.clear();
}
