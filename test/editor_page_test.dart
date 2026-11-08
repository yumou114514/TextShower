import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_shower/data/doc_repository.dart';
import 'package:text_shower/data/export_service.dart';
import 'package:text_shower/data/file_pick_service.dart';
import 'package:text_shower/models/text_doc.dart';
import 'package:text_shower/pages/editor_page.dart';

class _FakePicker implements FilePicker {
  _FakePicker({this.targetPath});

  final String? targetPath;

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
  }) async =>
      targetPath;
}

TextDoc _tstDoc({
  String body = 'hello world',
  String? sourcePath,
  DocConfig? config,
}) {
  return TextDoc(
    id: 'doc1',
    title: '测试文稿',
    kind: DocKind.tst,
    body: body,
    config: config ?? DocConfig.tstDefault(),
    sourcePath: sourcePath,
  );
}

Future<void> _pumpEditor(
  WidgetTester tester,
  DocRepository repository,
  TextDoc doc, {
  ExportService? exportService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => EditorPage(
                    repository: repository,
                    doc: doc,
                    exportService: exportService,
                  ),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 200; i++) {
      try {
        if (condition()) return;
      } catch (_) {
        // 文件仍被写入占用时继续等待。
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pump();
}

void main() {
  testWidgets('编辑模式不显示滑块并提供缩放提示', (tester) async {
    final repository = MemoryDocRepository(<TextDoc>[_tstDoc()]);
    await _pumpEditor(tester, repository, _tstDoc());

    expect(find.byType(Slider), findsNothing);
    expect(find.text('32'), findsOneWidget);
    expect(find.text('双指缩放或按住 Ctrl 滚动鼠标滚轮调整字号'), findsOneWidget);
    expect(find.text('隐藏'), findsNothing);
    expect(find.text('取消隐藏'), findsNothing);
  });

  testWidgets('Ctrl+滚轮调整字号', (tester) async {
    final repository = MemoryDocRepository(<TextDoc>[_tstDoc()]);
    await _pumpEditor(tester, repository, _tstDoc());

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(
      tester.getCenter(find.byKey(const ValueKey<String>('editor-body'))),
    );
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(find.text('37'), findsOneWidget);
  });

  testWidgets('双指缩放调整字号', (tester) async {
    final repository = MemoryDocRepository(<TextDoc>[_tstDoc()]);
    await _pumpEditor(tester, repository, _tstDoc());

    final center = tester.getCenter(
      find.byKey(const ValueKey<String>('editor-body')),
    );
    final first = await tester.startGesture(center + const Offset(-30, 0));
    final second = await tester.startGesture(center + const Offset(30, 0));
    await tester.pump();
    await first.moveTo(center + const Offset(-60, 0));
    await second.moveTo(center + const Offset(60, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    expect(find.text('64'), findsOneWidget);
  });

  testWidgets('保存时写回源文件', (tester) async {
    final directory = Directory.systemTemp.createTempSync('text_shower_save');
    addTearDown(() {
      try {
        directory.deleteSync(recursive: true);
      } catch (_) {
        // Windows 可能仍短暂占用刚写完的文件。
      }
    });
    final source = File(
      '${directory.path}${Platform.pathSeparator}quiz.tst',
    )..writeAsStringSync('old');
    final doc = _tstDoc(sourcePath: source.path);
    final repository = MemoryDocRepository(<TextDoc>[doc]);
    await _pumpEditor(tester, repository, doc);

    await tester.enterText(
      find.byKey(const ValueKey<String>('editor-body')),
      'new content',
    );
    await _openMenu(tester, '保存');
    await _waitFor(
      tester,
      () => source.readAsStringSync().contains('new content'),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );

    final saved = await repository.findById(doc.id);
    expect(saved!.body, 'new content');
    final written = source.readAsStringSync();
    expect(written, startsWith('---\n'));
    expect(written, contains('new content'));
  });

  testWidgets('未保存离开时可以保存、不保存或取消', (tester) async {
    final doc = _tstDoc();
    final repository = MemoryDocRepository(<TextDoc>[doc]);
    await _pumpEditor(tester, repository, doc);

    await tester.enterText(
      find.byKey(const ValueKey<String>('editor-body')),
      'changed',
    );
    await tester.tap(find.byTooltip('查看'));
    await tester.pumpAndSettle();
    expect(find.text('未保存的修改'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('editor-body')), findsOneWidget);

    await tester.tap(find.byTooltip('查看'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('不保存'));
    await tester.pumpAndSettle();

    expect(find.text('打开'), findsOneWidget);
    expect((await repository.findById(doc.id))!.body, 'hello world');

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('editor-body')),
      'saved',
    );
    await tester.tap(find.byTooltip('查看'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('打开'), findsOneWidget);
    expect((await repository.findById(doc.id))!.body, 'saved');
  });

  testWidgets('删除文档后返回上一页', (tester) async {
    final doc = _tstDoc();
    final repository = MemoryDocRepository(<TextDoc>[doc]);
    await _pumpEditor(tester, repository, doc);

    await _openMenu(tester, '删除文档');
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(await repository.loadAll(), isEmpty);
    expect(find.text('打开'), findsOneWidget);
  });

  testWidgets('导出文件写入目标路径', (tester) async {
    final directory = Directory.systemTemp.createTempSync('text_shower_export');
    addTearDown(() {
      try {
        directory.deleteSync(recursive: true);
      } catch (_) {
        // Windows 可能仍短暂占用刚写完的文件。
      }
    });
    final target = '${directory.path}${Platform.pathSeparator}quiz.tst';
    final doc = _tstDoc(body: 'export me');
    final repository = MemoryDocRepository(<TextDoc>[doc]);
    final service = ExportService(
      picker: _FakePicker(targetPath: target),
      isAndroid: false,
    );
    await _pumpEditor(tester, repository, doc, exportService: service);

    await _openMenu(tester, '导出文件');
    await _waitFor(
      tester,
      () => File(target).existsSync() && File(target).lengthSync() > 0,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );

    final file = File(target);
    expect(file.existsSync(), isTrue);
    final contents = file.readAsStringSync();
    expect(contents, startsWith('---\n'));
    expect(contents, contains('export me'));
  });

  testWidgets('纯文本文稿不显示格式工具栏', (tester) async {
    final doc = TextDoc(
      id: 'plain1',
      title: '纯文本',
      kind: DocKind.plain,
      body: 'plain text',
    );
    final repository = MemoryDocRepository(<TextDoc>[doc]);
    await _pumpEditor(tester, repository, doc);

    expect(find.text('隐藏'), findsNothing);
    expect(find.text('取消隐藏'), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
  });
}
