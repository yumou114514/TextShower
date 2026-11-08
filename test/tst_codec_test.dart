import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:text_shower/data/tst_codec.dart';
import 'package:text_shower/models/text_doc.dart';

void main() {
  group('front matter', () {
    test('解析标题、列数、隐藏组与默认组', () {
      const source = '''
---
version: 1
title: Unit 3 单词小测
columns: 2
defaultGroup: 英文
hideGroups:
  - name: 英文
    defaultHidden: false
  - name: 音标
    defaultHidden: true
---
#FFD166 apple #FFFFFF 苹果
{hide:音标}/bəˈnɑːnə/{/hide}
''';
      final result = TstCodec.parse(source, fallbackTitle: 'fallback');

      expect(result.title, 'Unit 3 单词小测');
      expect(result.config.columns, 2);
      expect(result.config.groups, const [
        HideGroup(name: '英文'),
        HideGroup(name: '音标', defaultHidden: true),
      ]);
      expect(result.config.defaultGroup, '英文');
      expect(result.body.startsWith('#FFD166 apple'), isTrue);
      expect(result.body.contains('---'), isFalse);
      expect(result.warnings, isEmpty);
      expect(result.document.effectiveGroups, {'音标'});
      expect(result.document.allGroups, {'英文', '音标'});
    });

    test('没有文件头时整段作为正文', () {
      final result = TstCodec.parse('第一行\n第二行', fallbackTitle: '未命名文稿');
      expect(result.title, '未命名文稿');
      expect(result.config.columns, 2);
      expect(result.config.groups, isEmpty);
      expect(result.config.defaultGroup, isNull);
      expect(result.body, '第一行\n第二行');
      expect(result.document.blocks, hasLength(2));
    });

    test('文件头缺省 title 时用回退标题', () {
      final result = TstCodec.parse('---\ncolumns: 1\n---\n正文',
          fallbackTitle: '文件名');
      expect(result.title, '文件名');
      expect(result.config.columns, 1);
      expect(result.body, '正文');
    });

    test('非法组名与重复组被忽略并给出警告', () {
      const source = '''
---
hideGroups:
  - name: "a:b"
  - name: 英文
  - name: 英文
---
正文
''';
      final result = TstCodec.parse(source);
      expect(result.config.groups, const [HideGroup(name: '英文')]);
      expect(result.warnings, hasLength(2));
    });

    test('正文中未声明的组自动补建', () {
      const source = '''
---
hideGroups:
  - name: 音标
---
{hide:英文}apple{/hide}
''';
      final result = TstCodec.parse(source);
      expect(result.config.groups, const [
        HideGroup(name: '音标'),
        HideGroup(name: '英文'),
      ]);
      expect(result.config.defaultGroup, '音标');
      expect(result.document.effectiveGroups, {'英文'});
    });

    test('损坏的 YAML 被忽略且正文保留', () {
      final result = TstCodec.parse('---\ntitle: [\n---\n正文');
      expect(result.title, '未命名');
      expect(result.body, '正文');
      expect(result.warnings, isNotEmpty);
    });
  });

  group('颜色', () {
    test('前缀持续染色', () {
      final result = TstCodec.parse('#000000 一行 #FFFFFF 文字');
      final runs = result.document.blocks.single.runs;
      expect(runs, hasLength(2));
      expect(runs[0].text, '一行 ');
      expect(runs[0].color, const Color(0xFF000000));
      expect(runs[1].text, '文字');
      expect(runs[1].color, const Color(0xFFFFFFFF));
    });

    test('三位色码展开', () {
      final result = TstCodec.parse('#F00 红\n#abc 蓝');
      final blocks = result.document.blocks;
      expect(blocks[0].runs.single.color, const Color(0xFFFF0000));
      expect(blocks[1].runs.single.color, const Color(0xFFAABBCC));
    });

    test('色码后的一个空白不渲染', () {
      final result = TstCodec.parse('#FF0000  两个空格');
      expect(result.document.blocks.single.text, ' 两个空格');
    });

    test('行尾色码不吞掉换行', () {
      final result = TstCodec.parse('#FF0000\n下一行');
      expect(result.document.blocks, hasLength(2));
      expect(result.document.blocks[1].runs.single.color, isNull);
    });

    test('颜色每行重置', () {
      final result = TstCodec.parse('#FF0000 第一行\n第二行');
      expect(result.document.blocks[0].runs.single.color,
          const Color(0xFFFF0000));
      expect(result.document.blocks[1].runs.single.color, isNull);
    });

    test('非法色码按字面显示', () {
      for (final source in ['#12 文字', '#GGG 文字', '#FFF,文字', '#1234567 文字']) {
        final result = TstCodec.parse(source);
        expect(result.document.blocks.single.runs.single.text, source);
        expect(result.document.blocks.single.runs.single.color, isNull);
      }
    });

    test('\\# 转义为字面色码', () {
      final result = TstCodec.parse(r'\#FF0000 文字');
      final run = result.document.blocks.single.runs.single;
      expect(run.text, '#FF0000 文字');
      expect(run.color, isNull);
    });
  });

  group('隐藏标记', () {
    test('嵌套组产生正确的组集合', () {
      final result =
          TstCodec.parse('{hide:a}x{hide:b}y{/hide}z{/hide}w');
      final runs = result.document.blocks.single.runs;
      expect(runs.map((r) => r.text).join(), 'xyzw');
      expect(runs[0].hideGroups, {'a'});
      expect(runs[1].hideGroups, {'a', 'b'});
      expect(runs[2].hideGroups, {'a'});
      expect(runs[3].hideGroups, isEmpty);
      expect(result.document.effectiveGroups, {'a', 'b'});
    });

    test('隐藏标记可跨行', () {
      final result = TstCodec.parse('{hide:a}x\ny{/hide}z');
      final blocks = result.document.blocks;
      expect(blocks[0].runs.single.hideGroups, {'a'});
      expect(blocks[1].runs.map((r) => r.text).join(), 'yz');
      expect(blocks[1].runs.first.hideGroups, {'a'});
      expect(blocks[1].runs.last.hideGroups, isEmpty);
    });

    test('未匹配的标记按字面显示', () {
      for (final source in ['{hide:a}abc', 'abc{/hide}', '{/hide}abc{hide:a}']) {
        final result = TstCodec.parse(source);
        expect(result.document.blocks.single.text, source);
        expect(result.document.effectiveGroups, isEmpty);
      }
    });

    test('\\{ 与 \\} 转义为字面括号', () {
      final result = TstCodec.parse(r'\{hide:a\}');
      expect(result.document.blocks.single.text, '{hide:a}');
      expect(result.document.effectiveGroups, isEmpty);
    });

    test('只有空白的隐藏内容不算有效组', () {
      final result = TstCodec.parse('{hide:a}   {/hide}正文');
      expect(result.document.effectiveGroups, isEmpty);
      expect(result.config.groups, const [HideGroup(name: 'a')]);
    });

    test('组名中的冒号不构成标记', () {
      final result = TstCodec.parse('{hide:a:b}文字{/hide}');
      expect(result.document.blocks.single.text, '{hide:a:b}文字{/hide}');
    });
  });

  group('隐藏过滤', () {
    test('过滤后丢弃空块并合并相邻片段', () {
      final parsed = TstCodec.parse('a{hide:x}b{/hide}c\n{hide:x}d{/hide}');
      final filtered = parsed.document.filter({'x'});
      expect(filtered.blocks, hasLength(1));
      expect(filtered.blocks.single.runs, hasLength(1));
      expect(filtered.blocks.single.text, 'ac');
    });

    test('保留原本的空行', () {
      final parsed = TstCodec.parse('{hide:x}gone{/hide}\n\nkeep');
      final filtered = parsed.document.filter({'x'});
      expect(filtered.blocks, hasLength(2));
      expect(filtered.blocks[0].isBlank, isTrue);
      expect(filtered.blocks[1].text, 'keep');
    });

    test('空隐藏集合返回原文档', () {
      final parsed = TstCodec.parse('{hide:x}a{/hide}');
      expect(identical(parsed.document.filter({}), parsed.document), isTrue);
    });
  });

  group('序列化', () {
    test('序列化后可再解析', () {
      final config = DocConfig(
        columns: 1,
        groups: const [
          HideGroup(name: '英文', defaultHidden: true),
          HideGroup(name: '音标'),
        ],
        defaultGroup: '音标',
      );
      const body = '#FF0000 apple #FFFFFF 苹果\n{hide:英文}cherry{/hide} 樱桃\n';
      final source =
          TstCodec.serialize(title: 'Unit "3": 小测', config: config, body: body);
      final parsed = TstCodec.parse(source);

      expect(parsed.title, 'Unit "3": 小测');
      expect(parsed.config, config);
      expect(parsed.body, body);
      expect(parsed.document.effectiveGroups, {'英文'});
      expect(parsed.warnings, isEmpty);
    });

    test('空组列表写成行内列表', () {
      final source = TstCodec.serialize(
        title: 'T',
        config: const DocConfig(columns: 2),
        body: '正文',
      );
      expect(source.contains('hideGroups: []'), isTrue);
      expect(TstCodec.parse(source).config.groups, isEmpty);
    });
  });

  group('预览', () {
    test('跳过空行并压缩空白', () {
      final parsed = TstCodec.parse('\n\n  hello   world \n第二行');
      expect(parsed.document.preview(maxChars: 12), 'hello world');
    });
  });
}
