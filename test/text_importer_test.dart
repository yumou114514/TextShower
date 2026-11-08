import 'dart:convert';

import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_shower/data/text_importer.dart';
import 'package:text_shower/models/text_doc.dart';

void main() {
  group('decode', () {
    test('UTF-8 并规范化换行', () {
      final result = TextImporter.decode(utf8.encode('你好\r\n世界\r再见'));
      expect(result.text, '你好\n世界\n再见');
      expect(result.encoding, 'UTF-8');
      expect(result.hadErrors, isFalse);
    });

    test('去除 UTF-8 BOM', () {
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode('正文')];
      final result = TextImporter.decode(bytes);
      expect(result.text, '正文');
      expect(result.encoding, 'UTF-8');
    });

    test('UTF-16 LE BOM', () {
      final bytes = <int>[0xFF, 0xFE, 0x60, 0x4F, 0x7D, 0x59];
      final result = TextImporter.decode(bytes);
      expect(result.text, '你好');
      expect(result.encoding, 'UTF-16 LE');
    });

    test('UTF-16 BE BOM', () {
      final bytes = <int>[0xFE, 0xFF, 0x4F, 0x60, 0x59, 0x7D];
      final result = TextImporter.decode(bytes);
      expect(result.text, '你好');
      expect(result.encoding, 'UTF-16 BE');
    });

    test('非法 UTF-8 回退 GBK', () {
      final result = TextImporter.decode(gbk.encode('中文测试'));
      expect(result.text, '中文测试');
      expect(result.encoding, 'GBK');
      expect(result.hadErrors, isFalse);
    });

    test('GBK 也无法解码时替换并标记', () {
      final result = TextImporter.decode(<int>[0xFF]);
      expect(result.encoding, 'GBK');
      expect(result.hadErrors, isTrue);
    });

    test('空字节返回空文本', () {
      final result = TextImporter.decode(const <int>[]);
      expect(result.text, isEmpty);
      expect(result.encoding, 'UTF-8');
    });
  });

  group('createPlainDoc', () {
    test('纯文本文档为单列且不解析标记', () {
      final doc = TextImporter.createPlainDoc(
        title: 'Unit 3',
        text: '#FF0000 apple\n{hide:英文}x{/hide}',
      );
      expect(doc.kind, DocKind.plain);
      expect(doc.config.columns, 1);
      expect(doc.config.groups, isEmpty);
      expect(doc.body, contains('#FF0000'));
      expect(doc.sourcePath, isNull);
      expect(doc.isTst, isFalse);
    });
  });

  group('titleFromFileName', () {
    test('去掉扩展名与路径', () {
      expect(TextImporter.titleFromFileName(r'C:\Docs\Unit 3.tst'), 'Unit 3');
      expect(TextImporter.titleFromFileName('/home/a/readme.txt'), 'readme');
      expect(TextImporter.titleFromFileName('noext'), 'noext');
      expect(TextImporter.titleFromFileName('.hidden'), '.hidden');
      expect(TextImporter.titleFromFileName(''), '未命名');
    });
  });
}
