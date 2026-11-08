import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_shower/data/doc_repository.dart';
import 'package:text_shower/data/file_pick_service.dart';
import 'package:text_shower/data/tst_codec.dart';
import 'package:text_shower/models/text_doc.dart';
import 'package:text_shower/pages/library_page.dart';

class _FakePicker implements FilePicker {
  _FakePicker({this.next});

  PickedFile? next;

  @override
  Future<PickedFile?> open({
    required String label,
    required List<String> extensions,
    String? mimeType,
  }) async =>
      next;

  @override
  Future<String?> savePath({
    required String label,
    required List<String> extensions,
    required String suggestedName,
    String? mimeType,
  }) async =>
      null;
}

TextDoc _doc(String title, {DocKind kind = DocKind.tst}) {
  return TextDoc(
    id: 'doc_$title',
    title: title,
    kind: kind,
    body: '第一行内容',
    config: kind == DocKind.tst ? DocConfig.tstDefault() : const DocConfig.plain(),
  );
}

void main() {
  Future<void> pumpLibrary(
    WidgetTester tester,
    DocRepository repository,
    FilePicker picker,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryPage(repository: repository, filePicker: picker),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('空文档库显示引导并能新建 tst 文稿', (tester) async {
    final repository = MemoryDocRepository();
    await pumpLibrary(tester, repository, _FakePicker());

    expect(find.text('还没有文稿'), findsOneWidget);
    await tester.tap(find.text('新建文稿'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('editor-body')), findsOneWidget);
    final docs = await repository.loadAll();
    expect(docs.length, 1);
    expect(docs.single.kind, DocKind.tst);
    expect(docs.single.config.defaultGroup, '默认');
  });

  testWidgets('打开任意文本文件都按 tst 解析并进入查看页', (tester) async {
    final repository = MemoryDocRepository();
    final picker = _FakePicker(
      next: PickedFile(
        path: '',
        name: '导入测试.txt',
        bytes: Uint8List.fromList(utf8.encode('hello\nworld')),
      ),
    );
    await pumpLibrary(tester, repository, picker);

    await tester.tap(find.byTooltip('打开文件'));
    await tester.pumpAndSettle();

    expect(find.text('导入测试'), findsOneWidget);
    final docs = await repository.loadAll();
    expect(docs.single.kind, DocKind.tst);
    expect(docs.single.body, 'hello\nworld');
  });

  testWidgets('打开 tst 文件后直接进入查看页', (tester) async {
    final repository = MemoryDocRepository();
    final contents = TstCodec.serialize(
      title: '单词小测',
      config: DocConfig.tstDefault(),
      body: '#FF0000 apple #FFFFFF 苹果',
    );
    final picker = _FakePicker(
      next: PickedFile(
        path: '',
        name: 'quiz.tst',
        bytes: Uint8List.fromList(utf8.encode(contents)),
      ),
    );
    await pumpLibrary(tester, repository, picker);

    await tester.tap(find.byTooltip('打开文件'));
    await tester.pumpAndSettle();

    expect(find.text('单词小测'), findsOneWidget);
    final docs = await repository.loadAll();
    expect(docs.single.kind, DocKind.tst);
    expect(docs.single.title, '单词小测');
  });

  testWidgets('列表项支持重命名与删除', (tester) async {
    final doc = _doc('旧标题');
    final repository = MemoryDocRepository(<TextDoc>[doc]);
    await pumpLibrary(tester, repository, _FakePicker());

    expect(find.text('旧标题'), findsOneWidget);

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新标题');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('新标题'), findsOneWidget);
    expect((await repository.findById(doc.id))!.title, '新标题');

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除文档'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(await repository.loadAll(), isEmpty);
    expect(find.text('还没有文稿'), findsOneWidget);
  });
}
