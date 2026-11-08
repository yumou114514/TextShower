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
    title: '单词小测',
    kind: DocKind.tst,
    body: body,
    config: DocConfig(
      columns: columns,
      groups: const <HideGroup>[
        HideGroup(name: '英文'),
        HideGroup(name: '音标'),
      ],
      defaultGroup: '英文',
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

  testWidgets('固定白底黑字且不提供背景或隐藏控制', (tester) async {
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

  testWidgets('拖动字号滑块覆盖自动字号，自动按钮复位', (tester) async {
    await _pumpDisplay(tester, _tstDoc());

    FilterChip chip = tester.widget(
      find.widgetWithText(FilterChip, '自动'),
    );
    expect(chip.selected, isTrue);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(48);
    await tester.pumpAndSettle();

    expect(find.text('48'), findsOneWidget);
    chip = tester.widget(find.widgetWithText(FilterChip, '自动'));
    expect(chip.selected, isFalse);

    await tester.tap(find.text('自动'));
    await tester.pumpAndSettle();

    chip = tester.widget(find.widgetWithText(FilterChip, '自动'));
    expect(chip.selected, isTrue);
  });

  testWidgets('空白文稿显示占位提示', (tester) async {
    await _pumpDisplay(tester, _tstDoc(body: ''));

    expect(find.text('空白文稿，点击右上角编辑'), findsOneWidget);
  });
}
