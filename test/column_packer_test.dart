import 'package:flutter_test/flutter_test.dart';
import 'package:text_shower/services/column_packer.dart';

void main() {
  group('fitsOnPage', () {
    test('两块正好放满两列', () {
      const packer = ColumnPacker(columns: 2, pageHeight: 100);
      expect(packer.fitsOnPage([100, 100]), isTrue);
      expect(packer.fitsOnPage([100, 100, 1]), isFalse);
    });

    test('单块超过页高不算放得下', () {
      const packer = ColumnPacker(columns: 2, pageHeight: 100);
      expect(packer.fitsOnPage([101]), isFalse);
      expect(packer.fitsOnPage([100, 100]), isTrue);
    });

    test('单列只允许一列', () {
      const packer = ColumnPacker(columns: 1, pageHeight: 100);
      expect(packer.fitsOnPage([60, 40]), isTrue);
      expect(packer.fitsOnPage([60, 41]), isFalse);
    });

    test('空列表放得下', () {
      const packer = ColumnPacker(columns: 2, pageHeight: 100);
      expect(packer.fitsOnPage(const []), isTrue);
    });
  });

  group('pack', () {
    test('左列填满后进入右列', () {
      const packer = ColumnPacker(columns: 2, pageHeight: 250);
      final result = packer.pack([100, 100, 100]);
      expect(result.pages, hasLength(1));
      final page = result.pages.single;
      expect(page.columns, hasLength(2));
      expect(page.columns[0].blockIndices, [0, 1]);
      expect(page.columns[1].blockIndices, [2]);
      expect(result.hasOversizedBlock, isFalse);
    });

    test('两列用尽后开新页', () {
      const packer = ColumnPacker(columns: 2, pageHeight: 250);
      final result = packer.pack([100, 100, 200, 100]);
      expect(result.pages, hasLength(2));
      expect(result.pages[0].columns[0].blockIndices, [0, 1]);
      expect(result.pages[0].columns[1].blockIndices, [2]);
      expect(result.pages[1].columns.single.blockIndices, [3]);
    });

    test('超高块被标记但仍保留在列中', () {
      const packer = ColumnPacker(columns: 2, pageHeight: 250);
      final result = packer.pack([300, 50]);
      expect(result.hasOversizedBlock, isTrue);
      expect(result.pages.single.columns, hasLength(2));
      expect(result.pages.single.columns[0].blockIndices, [0]);
      expect(result.pages.single.columns[1].blockIndices, [1]);
    });

    test('空列表不产生页', () {
      const packer = ColumnPacker(columns: 2, pageHeight: 250);
      expect(packer.pack(const []).pages, isEmpty);
    });

    test('单列每页只有一列', () {
      const packer = ColumnPacker(columns: 1, pageHeight: 100);
      final result = packer.pack([100, 50]);
      expect(result.pages, hasLength(2));
      expect(result.pages[0].columns.single.blockIndices, [0]);
      expect(result.pages[1].columns.single.blockIndices, [1]);
    });
  });
}
