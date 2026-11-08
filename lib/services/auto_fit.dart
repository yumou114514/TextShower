import '../models/parsed_document.dart';
import 'column_packer.dart';
import 'text_measurer.dart';

typedef BlockHeightMeasurer = double Function(
    Block block, double fontSize, double maxWidth);

double computeColumnWidth({
  required double totalWidth,
  required int columns,
  double gap = 24,
  double divider = 1,
}) {
  if (columns <= 1) return totalWidth;
  final width = totalWidth - (columns - 1) * (gap + divider);
  return width > 0 ? width / columns : 0;
}

/// 取开头一段可见文本作为自动字号的样本，避免长文整篇二分。
List<Block> sampleVisibleBlocks(List<Block> blocks, {int maxChars = 500}) {
  final sample = <Block>[];
  var remaining = maxChars;
  var started = false;
  for (final block in blocks) {
    if (remaining <= 0) break;
    if (block.isBlank) {
      if (!started) continue;
      sample.add(block);
      remaining -= block.length == 0 ? 1 : block.length;
      continue;
    }
    started = true;
    if (block.length <= remaining) {
      sample.add(block);
      remaining -= block.length;
    } else {
      sample.add(block.takeChars(remaining));
      remaining = 0;
    }
  }
  while (sample.isNotEmpty && sample.last.isBlank) {
    sample.removeLast();
  }
  return sample;
}

class FitOutcome {
  const FitOutcome({
    required this.fontSize,
    required this.columns,
    this.fallbackToSingle = false,
  });

  final double fontSize;
  final int columns;
  final bool fallbackToSingle;

  FitOutcome copyWith({
    double? fontSize,
    int? columns,
    bool? fallbackToSingle,
  }) =>
      FitOutcome(
        fontSize: fontSize ?? this.fontSize,
        columns: columns ?? this.columns,
        fallbackToSingle: fallbackToSingle ?? this.fallbackToSingle,
      );
}

class AutoFitter {
  AutoFitter({
    BlockHeightMeasurer? measurer,
    this.minFontSize = TextMeasurer.minFontSize,
    this.maxFontSize = TextMeasurer.maxFontSize,
    this.sampleChars = 500,
  }) : _measure = measurer ?? TextMeasurer().measureBlock;

  final BlockHeightMeasurer _measure;
  final double minFontSize;
  final double maxFontSize;
  final int sampleChars;

  final Map<String, FitOutcome> _cache = <String, FitOutcome>{};

  FitOutcome fit({
    required List<Block> blocks,
    required double width,
    required double height,
    required int columns,
    double gap = 24,
    double divider = 1,
  }) {
    final requestedColumns = columns == 1 ? 1 : 2;
    if (blocks.isEmpty || width <= 0 || height <= 0) {
      return FitOutcome(fontSize: minFontSize, columns: requestedColumns);
    }

    final key = _cacheKey(
        blocks, width, height, requestedColumns, gap, divider);
    final cached = _cache[key];
    if (cached != null) return cached;

    var outcome = _fitColumns(
      blocks: blocks,
      width: width,
      height: height,
      columns: requestedColumns,
      gap: gap,
      divider: divider,
    );

    if (requestedColumns == 2) {
      final columnWidth = computeColumnWidth(
        totalWidth: width,
        columns: 2,
        gap: gap,
        divider: divider,
      );
      final oversized = columnWidth <= 0 ||
          blocks.any((block) =>
              _measure(block, outcome.fontSize, columnWidth) > height + 0.01);
      if (oversized) {
        outcome = _fitColumns(
          blocks: blocks,
          width: width,
          height: height,
          columns: 1,
          gap: gap,
          divider: divider,
        ).copyWith(fallbackToSingle: true);
      }
    }

    if (_cache.length >= 8) _cache.clear();
    _cache[key] = outcome;
    return outcome;
  }

  FitOutcome _fitColumns({
    required List<Block> blocks,
    required double width,
    required double height,
    required int columns,
    required double gap,
    required double divider,
  }) {
    final sample = sampleVisibleBlocks(blocks, maxChars: sampleChars);
    if (sample.isEmpty) {
      return FitOutcome(fontSize: minFontSize, columns: columns);
    }
    final columnWidth = computeColumnWidth(
      totalWidth: width,
      columns: columns,
      gap: gap,
      divider: divider,
    );
    final packer = ColumnPacker(columns: columns, pageHeight: height);

    bool fits(double size) {
      if (columnWidth <= 0) return false;
      final heights = <double>[
        for (final block in sample) _measure(block, size, columnWidth),
      ];
      return packer.fitsOnPage(heights);
    }

    if (!fits(minFontSize)) {
      return FitOutcome(fontSize: minFontSize, columns: columns);
    }
    if (fits(maxFontSize)) {
      return FitOutcome(fontSize: maxFontSize, columns: columns);
    }

    var low = minFontSize;
    var high = maxFontSize;
    while (high - low > 0.5) {
      final mid = (low + high) / 2;
      if (fits(mid)) {
        low = mid;
      } else {
        high = mid;
      }
    }
    final size = (low * 2).floorToDouble() / 2;
    return FitOutcome(
      fontSize: size < minFontSize ? minFontSize : size,
      columns: columns,
    );
  }

  String _cacheKey(
    List<Block> blocks,
    double width,
    double height,
    int columns,
    double gap,
    double divider,
  ) {
    final content = StringBuffer();
    for (final block in blocks) {
      content.write(block.text);
      content.write('\u0001');
    }
    return '${content.toString().hashCode}|'
        '${width.toStringAsFixed(1)}|${height.toStringAsFixed(1)}|'
        '$columns|${gap.toStringAsFixed(1)}|${divider.toStringAsFixed(1)}';
  }
}
