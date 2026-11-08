/// 把已测量高度的块按「左列到底 → 右列顶部」的顺序装进固定高度的列与页。
class ColumnPacker {
  const ColumnPacker({required this.columns, required this.pageHeight});

  static const double _epsilon = 0.01;

  final int columns;
  final double pageHeight;

  bool fitsOnPage(List<double> heights) {
    if (columns <= 0 || pageHeight <= 0) return heights.isEmpty;
    for (final height in heights) {
      if (height > pageHeight + _epsilon) return false;
    }
    var used = 0.0;
    var column = 0;
    for (final height in heights) {
      if (used > 0 && used + height > pageHeight + _epsilon) {
        column++;
        used = height;
      } else {
        used += height;
      }
      if (column >= columns) return false;
    }
    return true;
  }

  PackResult pack(List<double> heights) {
    final pages = <PackedPage>[];
    var pageColumns = <PackedColumn>[];
    var indices = <int>[];
    var used = 0.0;
    var hasOversizedBlock = false;

    void closeColumn() {
      if (indices.isEmpty) return;
      pageColumns.add(PackedColumn(List<int>.unmodifiable(indices), used));
      indices = <int>[];
      used = 0;
    }

    void closePage() {
      closeColumn();
      if (pageColumns.isEmpty) return;
      pages.add(PackedPage(List<PackedColumn>.unmodifiable(pageColumns)));
      pageColumns = <PackedColumn>[];
    }

    for (var i = 0; i < heights.length; i++) {
      final height = heights[i];
      if (height > pageHeight + _epsilon) hasOversizedBlock = true;
      if (indices.isNotEmpty && used + height > pageHeight + _epsilon) {
        closeColumn();
        if (pageColumns.length >= columns) closePage();
      }
      indices.add(i);
      used += height;
    }
    closePage();

    return PackResult(
      pages: List<PackedPage>.unmodifiable(pages),
      hasOversizedBlock: hasOversizedBlock,
    );
  }
}

class PackResult {
  const PackResult({required this.pages, required this.hasOversizedBlock});

  final List<PackedPage> pages;
  final bool hasOversizedBlock;
}

class PackedPage {
  const PackedPage(this.columns);

  final List<PackedColumn> columns;
}

class PackedColumn {
  const PackedColumn(this.blockIndices, this.height);

  final List<int> blockIndices;
  final double height;
}
