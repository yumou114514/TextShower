import 'package:flutter/material.dart';

import '../models/parsed_document.dart';
import '../services/text_measurer.dart';

class RichBlockText extends StatelessWidget {
  const RichBlockText({
    super.key,
    required this.block,
    required this.fontSize,
    required this.color,
  });

  final Block block;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextMeasurer.spanFor(block, fontSize, color: color),
      style: TextMeasurer.styleFor(fontSize, color: color),
      textScaler: TextScaler.noScaling,
      strutStyle: TextMeasurer.strutFor(fontSize),
      textAlign: TextAlign.center,
    );
  }
}
