import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_shower/data/doc_repository.dart';
import 'package:text_shower/models/text_doc.dart';
import 'package:text_shower/pages/display_page.dart';
import 'package:text_shower/widgets/rich_blocks.dart';

TextDoc _tstDoc({
  String body = '#FFD166 apple #FFFFFF 苹果\n{hide:英文}banana{/hide} 香蕉',
  int columns = 1,
}) {
  return TextDoc(
    id: 'doc1',
    title: '文档',
    kind: DocKind.tst,
    body: body,
    config: DocConfig(
      columns: columns,
      groups: const <HideGroup>[
        HideGroup(name: 'hide'),
      ],
      defaultGroup: 'hide',
    ),
  );
}

Future<void> _pumpDisplay(WidgetTester tester, TextDoc doc) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DisplayPage(
        repository: MemoryDocRepository(<TextDoc>[doc]),
        doc: doc,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _hasPlainText(WidgetTester tester, String text) {
  return tester.widgetList<RichText>(find.byType(RichText)).any(
        (widget) => widget.text.toPlainText().contains(text),
      );
}

void main() {
  testWidgets('始终按单列渲染，忽略文件中的双列配置', (tester) async {
    await _pumpDisplay(tester, _tstDoc(columns: 2));

    expect(find.byKey(const ValueKey<String>('single-column')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('two-columns')), findsNothing);
    expect(find.text('单列'), findsNothing);
    expect(find.text('双列'), findsNothing);
  });

  testWidgets('正文按居中方式显示', (tester) async {
    await _pumpDisplay(tester, _tstDoc());

    final texts = tester.widgetList<Text>(
      find.descendant(
        of: find.byType(RichBlockText),
        matching: find.byType(Text),
      ),
    );
    expect(texts, isNotEmpty);
    for (final text in texts) {
      expect(text.textAlign, TextAlign.center);
    }
  });

  testWidgets('白底黑字', (tester) async {
    await _pumpDisplay(tester, _tstDoc());

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.white);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, Colors.white);
    expect(appBar.foregroundColor, Colors.black);

    final richTexts = tester.widgetList<RichText>(
      find.descendant(
        of: find.byType(RichBlockText),
        matching: find.byType(RichText),
      ),
    );
    expect(richTexts, isNotEmpty);
    for (final rich in richTexts) {
      expect(rich.text.style?.color, Colors.black);
    }

    expect(find.byTooltip('切换为白底黑字'), findsNothing);
    expect(find.byTooltip('切换为黑底白字'), findsNothing);
    expect(find.text('隐藏英文'), findsNothing);
  });

  testWidgets('隐藏标记中的内容仍然显示', (tester) async {
    await _pumpDisplay(tester, _tstDoc());

    expect(_hasPlainText(tester, 'banana'), isTrue);
    expect(find.text('{hide:英文}'), findsNothing);
  });

  testWidgets('短文字在内容区域上下左右居中', (tester) async {
    await _pumpDisplay(tester, _tstDoc(body: 'hi'));

    final area = tester.getCenter(
      find.byKey(const ValueKey<String>('content-area')),
    );
    final content = tester.getCenter(
      find.byKey(const ValueKey<String>('centered-content')),
    );
    expect(content.dx, moreOrLessEquals(area.dx, epsilon: 0.5));
    expect(content.dy, moreOrLessEquals(area.dy, epsilon: 0.5));
  });

  testWidgets('加减按钮调整字号，自动按钮复位', (tester) async {
    await _pumpDisplay(tester, _tstDoc());

    FilterChip chip = tester.widget(
      find.widgetWithText(FilterChip, '自动'),
    );
    expect(chip.selected, isTrue);

    String sizeText() => tester
        .widget<Text>(find.byKey(const ValueKey<String>('font-size-value')))
        .data!;
    final autoSize = int.parse(sizeText());

    await tester.tap(find.byTooltip('减小字号'));
    await tester.pumpAndSettle();

    chip = tester.widget(find.widgetWithText(FilterChip, '自动'));
    expect(chip.selected, isFalse);
    final smaller = int.parse(sizeText());
    expect(smaller, lessThan(autoSize));

    await tester.tap(find.byTooltip('增大字号'));
    await tester.pumpAndSettle();
    expect(int.parse(sizeText()), greaterThan(smaller));

    await tester.tap(find.text('自动'));
    await tester.pumpAndSettle();

    chip = tester.widget(find.widgetWithText(FilterChip, '自动'));
    expect(chip.selected, isTrue);
  });

  testWidgets('点击字号数值打开滑块快速调整', (tester) async {
    await _pumpDisplay(tester, _tstDoc());

    await tester.tap(
      find.byKey(const ValueKey<String>('font-size-quick-adjust')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('quick-font-size-slider')),
      findsOneWidget,
    );

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey<String>('quick-font-size-slider')),
    );
    slider.onChanged!(60);
    await tester.pumpAndSettle();

    final sizeText = tester
        .widget<Text>(find.byKey(const ValueKey<String>('font-size-value')))
        .data;
    expect(sizeText, '60');
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, '自动'),
    );
    expect(chip.selected, isFalse);
  });

  testWidgets('双指捏合调整字号并切换为手动', (tester) async {
    await _pumpDisplay(
      tester,
      _tstDoc(
        body: List<String>.generate(
          6,
          (index) => 'line ${index + 1} some english words here',
        ).join('\n'),
      ),
    );

    String sizeText() => tester
        .widget<Text>(find.byKey(const ValueKey<String>('font-size-value')))
        .data!;
    final before = int.parse(sizeText());

    final first = await tester.startGesture(
      const Offset(300, 300),
      pointer: 1,
    );
    final second = await tester.startGesture(
      const Offset(340, 300),
      pointer: 2,
    );
    await tester.pump();
    await first.moveTo(const Offset(260, 300));
    await second.moveTo(const Offset(380, 300));
    await tester.pump();

    expect(int.parse(sizeText()), greaterThan(before));
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, '自动'),
    );
    expect(chip.selected, isFalse);

    await first.up();
    await second.up();
    await tester.pumpAndSettle();
  });

  testWidgets('超出一页时手指拖动可滚动', (tester) async {
    await _pumpDisplay(
      tester,
      _tstDoc(
        body: List<String>.generate(
          20,
          (index) => 'line ${index + 1} some english words here',
        ).join('\n'),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('font-size-quick-adjust')),
    );
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey<String>('quick-font-size-slider')),
    );
    slider.onChanged!(200);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 100));
    await tester.pumpAndSettle();

    final listFinder = find.byKey(const ValueKey<String>('single-column'));
    expect(listFinder, findsOneWidget);

    await tester.drag(listFinder, const Offset(0, -300));
    await tester.pumpAndSettle();

    final controller = tester.widget<ListView>(listFinder).controller;
    expect(controller!.offset, greaterThan(0));
  });

  testWidgets('鼠标拖动也能滚动内容', (tester) async {
    await _pumpDisplay(
      tester,
      _tstDoc(
        body: List<String>.generate(
          20,
          (index) => 'line ${index + 1} some english words here',
        ).join('\n'),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('font-size-quick-adjust')),
    );
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey<String>('quick-font-size-slider')),
    );
    slider.onChanged!(200);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 100));
    await tester.pumpAndSettle();

    final listFinder = find.byKey(const ValueKey<String>('single-column'));
    final controller = tester.widget<ListView>(listFinder).controller!;
    final start = tester.getCenter(listFinder);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(start);
    await gesture.moveBy(const Offset(0, -120));
    await gesture.moveBy(const Offset(0, -180));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
  });

  testWidgets('空白文稿显示占位提示', (tester) async {
    await _pumpDisplay(tester, _tstDoc(body: ''));

    expect(find.text('空白文稿，点击右上角编辑'), findsOneWidget);
  });
}
