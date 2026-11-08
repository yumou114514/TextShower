import 'package:flutter_test/flutter_test.dart';
import 'package:text_shower/models/parsed_document.dart';
import 'package:text_shower/services/auto_fit.dart';
import 'package:text_shower/services/column_packer.dart';

Block blockOf(String text) => Block([Run(text)]);

String repeat(String unit, int times) => List<String>.filled(times, unit).join();

/// 粗略模拟换行：字符宽度约为字号的 0.55 倍。
double fakeMeasure(Block block, double fontSize, double maxWidth) {
  if (maxWidth <= 0) return double.infinity;
  final charsPerLine = (maxWidth / (fontSize * 0.55)).floor().clamp(1, 1 << 20);
  final lines = (block.length / charsPerLine).ceil().clamp(1, 1 << 20);
  return lines * fontSize * 1.4;
}

AutoFitter fitter() => AutoFitter(measurer: fakeMeasure);

void main() {
  group('采样', () {
    test('截断到指定字符数', () {
      final blocks = [
        for (var i = 0; i < 20; i++) blockOf(repeat('a', 100)),
      ];
      final sample = sampleVisibleBlocks(blocks, maxChars: 500);
      final total = sample.fold<int>(0, (sum, block) => sum + block.length);
      expect(total, 500);
      expect(sample, hasLength(5));
    });

    test('跳过开头的空行并保留中间空行', () {
      final sample = sampleVisibleBlocks(
        [blockOf(' '), blockOf('abc'), blockOf(' '), blockOf('def')],
        maxChars: 100,
      );
      expect(sample, hasLength(3));
      expect(sample[0].text, 'abc');
      expect(sample[1].isBlank, isTrue);
      expect(sample[2].text, 'def');
    });
  });

  group('列宽', () {
    test('双列扣除间距与分隔线', () {
      expect(
        computeColumnWidth(
            totalWidth: 1200, columns: 2, gap: 24, divider: 1),
        587.5,
      );
      expect(computeColumnWidth(totalWidth: 1200, columns: 1), 1200);
    });
  });

  group('自动字号', () {
    test('短文本放大到上限', () {
      final outcome = fitter().fit(
        blocks: [blockOf('hi')],
        width: 800,
        height: 600,
        columns: 1,
      );
      expect(outcome.fontSize, 200);
      expect(outcome.columns, 1);
    });

    test('长文本取可读字号', () {
      final blocks = [
        for (var i = 0; i < 50; i++) blockOf(repeat('a', 30)),
      ];
      final outcome = fitter().fit(
        blocks: blocks,
        width: 1200,
        height: 800,
        columns: 1,
      );
      expect(outcome.fontSize, greaterThan(14));
      expect(outcome.fontSize, lessThan(200));
      expect(outcome.columns, 1);
    });

    test('14 号仍放不下时返回 14', () {
      final outcome = fitter().fit(
        blocks: [blockOf(repeat('a', 500))],
        width: 100,
        height: 100,
        columns: 1,
      );
      expect(outcome.fontSize, 14);
    });

    test('空内容返回下限', () {
      final outcome = fitter().fit(
        blocks: const [],
        width: 800,
        height: 600,
        columns: 1,
      );
      expect(outcome.fontSize, 14);
      expect(outcome.columns, 1);
    });

    test('双列字号不小于单列', () {
      final blocks = [
        for (var i = 0; i < 10; i++) blockOf(repeat('a', 20)),
      ];
      final single = fitter().fit(
        blocks: blocks,
        width: 1200,
        height: 800,
        columns: 1,
      );
      final double = fitter().fit(
        blocks: blocks,
        width: 1200,
        height: 800,
        columns: 2,
      );
      expect(double.fontSize, greaterThanOrEqualTo(single.fontSize));
      expect(double.columns, 2);
    });

    test('隐藏内容变少后字号变大', () {
      final all = [
        for (var i = 0; i < 12; i++) blockOf(repeat('a', 40)),
      ];
      final fewer = all.take(6).toList();
      final fitAll = fitter().fit(
        blocks: all,
        width: 1000,
        height: 700,
        columns: 1,
      );
      final fitFewer = fitter().fit(
        blocks: fewer,
        width: 1000,
        height: 700,
        columns: 1,
      );
      expect(fitFewer.fontSize, greaterThanOrEqualTo(fitAll.fontSize));
    });

    test('字号是实际放得下的最大半磅值', () {
      final blocks = [
        for (var i = 0; i < 8; i++) blockOf(repeat('a', 25)),
      ];
      final outcome = fitter().fit(
        blocks: blocks,
        width: 900,
        height: 600,
        columns: 1,
      );
      final sample = sampleVisibleBlocks(blocks);
      final columnWidth = computeColumnWidth(totalWidth: 900, columns: 1);

      bool fitsAt(double size) => const ColumnPacker(columns: 1, pageHeight: 600)
          .fitsOnPage([
        for (final block in sample) fakeMeasure(block, size, columnWidth),
      ]);

      expect(fitsAt(outcome.fontSize), isTrue);
      expect(fitsAt(outcome.fontSize + 1), isFalse);
    });

    test('双列中有超高块时回退单列', () {
      final blocks = [
        for (var i = 0; i < 24; i++) blockOf(repeat('a', 20)),
        blockOf(repeat('b', 5000)),
      ];
      final outcome = fitter().fit(
        blocks: blocks,
        width: 1200,
        height: 1500,
        columns: 2,
      );
      expect(outcome.fallbackToSingle, isTrue);
      expect(outcome.columns, 1);
      expect(outcome.fontSize, greaterThanOrEqualTo(14));
    });
  });
}
