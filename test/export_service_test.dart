import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:text_shower/data/export_service.dart';
import 'package:text_shower/data/file_pick_service.dart';

class FakePicker implements FilePicker {
  String? saveResult;
  String? suggestedName;
  String? lastLabel;
  List<String>? lastExtensions;

  @override
  Future<PickedFile?> open({
    required String label,
    required List<String> extensions,
    String? mimeType,
  }) async =>
      null;

  @override
  Future<String?> savePath({
    required String label,
    required List<String> extensions,
    required String suggestedName,
    String? mimeType,
  }) async {
    this.suggestedName = suggestedName;
    lastLabel = label;
    lastExtensions = extensions;
    return saveResult;
  }
}

void main() {
  late Directory directory;
  late FakePicker picker;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('text_shower_export_');
    picker = FakePicker();
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('ensureExtension 只补缺失的扩展名', () {
    expect(ExportService.ensureExtension(r'C:\a\b', 'tst'), r'C:\a\b.tst');
    expect(ExportService.ensureExtension(r'C:\a\b.TST', 'tst'), r'C:\a\b.TST');
    expect(ExportService.ensureExtension(r'C:\a\b.txt', 'tst'), r'C:\a\b.txt');
    expect(ExportService.ensureExtension('a.tst', 'tst'), 'a.tst');
  });

  test('导出写入选定路径并补扩展名', () async {
    final path = '${directory.path}${Platform.pathSeparator}unit3';
    picker.saveResult = path;
    final service = ExportService(picker: picker, isAndroid: false);
    final result = await service.exportText(
      suggestedName: 'unit3.tst',
      contents: '---\ntitle: T\n---\n正文',
      label: '小测文稿',
    );

    expect(result.cancelled, isFalse);
    expect(result.path, '$path.tst');
    expect(File('$path.tst').readAsStringSync(), contains('正文'));
    expect(picker.suggestedName, 'unit3.tst');
    expect(picker.lastExtensions, ['tst']);
  });

  test('用户取消保存', () async {
    picker.saveResult = null;
    final service = ExportService(picker: picker, isAndroid: false);
    final result = await service.exportText(
      suggestedName: 'a.tst',
      contents: 'x',
      label: '小测文稿',
    );
    expect(result.cancelled, isTrue);
    expect(result.path, isNull);
  });
}
