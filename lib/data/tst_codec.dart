import 'dart:convert';
import 'dart:ui';

import 'package:yaml/yaml.dart';

import '../models/parsed_document.dart';
import '../models/text_doc.dart';

class TstParseResult {
  const TstParseResult({
    required this.title,
    required this.config,
    required this.body,
    required this.document,
    required this.warnings,
  });

  final String title;
  final DocConfig config;
  final String body;
  final ParsedDocument document;
  final List<String> warnings;
}

class TstCodec {
  const TstCodec._();

  static const String _hideOpen = '{hide:';
  static const String _hideClose = '{/hide}';

  static TstParseResult parse(String source, {String fallbackTitle = '未命名'}) {
    final warnings = <String>[];
    final text = _normalize(source);
    final frontMatter = _extractFrontMatter(text);
    final body = frontMatter?.body ?? text;

    YamlMap? yaml;
    if (frontMatter != null && frontMatter.yaml.trim().isNotEmpty) {
      try {
        final loaded = loadYaml(frontMatter.yaml);
        if (loaded is YamlMap) {
          yaml = loaded;
        } else if (loaded is Map) {
          yaml = YamlMap.wrap(loaded);
        } else {
          warnings.add('文件头不是键值对，已忽略配置');
        }
      } catch (error) {
        warnings.add('文件头 YAML 解析失败，已忽略配置：$error');
      }
    }

    final rawTitle = _asString(yaml?['title'])?.trim();
    final title = (rawTitle == null || rawTitle.isEmpty) ? fallbackTitle : rawTitle;

    var columns = 2;
    final rawColumns = yaml?['columns'];
    if (rawColumns != null) {
      final parsed = rawColumns is int ? rawColumns : int.tryParse('$rawColumns');
      if (parsed == 1 || parsed == 2) {
        columns = parsed!;
      } else {
        warnings.add('columns 只能是 1 或 2，已按 2 列处理');
      }
    }

    final groups = <HideGroup>[];
    final seen = <String>{};
    final rawGroups = yaml?['hideGroups'];
    if (rawGroups == null) {
      // 允许缺省，正文中的隐藏标记会自动补建组。
    } else if (rawGroups is List) {
      for (final item in rawGroups) {
        String? name;
        var defaultHidden = false;
        if (item is String) {
          name = item;
        } else if (item is Map) {
          name = _asString(item['name']);
          defaultHidden = item['defaultHidden'] == true;
        }
        final trimmed = name?.trim();
        if (trimmed == null || trimmed.isEmpty) {
          warnings.add('忽略了一个没有名称的隐藏组');
          continue;
        }
        if (!isValidGroupName(trimmed)) {
          warnings.add('隐藏组名「$trimmed」包含非法字符，已忽略');
          continue;
        }
        if (!seen.add(trimmed)) {
          warnings.add('隐藏组「$trimmed」重复，已忽略后一个');
          continue;
        }
        groups.add(HideGroup(name: trimmed, defaultHidden: defaultHidden));
      }
    } else {
      warnings.add('hideGroups 不是列表，已忽略');
    }

    final parsedBody = _parseBody(body);
    for (final discovered in parsedBody.discoveredGroups) {
      if (seen.add(discovered)) {
        groups.add(HideGroup(name: discovered));
      }
    }

    String? defaultGroup;
    final rawDefault = _asString(yaml?['defaultGroup'])?.trim();
    if (rawDefault != null && rawDefault.isNotEmpty) {
      if (seen.contains(rawDefault)) {
        defaultGroup = rawDefault;
      } else {
        warnings.add('defaultGroup「$rawDefault」不在隐藏组列表中');
      }
    }
    defaultGroup ??= groups.isEmpty ? null : groups.first.name;

    final config = DocConfig(
      columns: columns,
      groups: List<HideGroup>.unmodifiable(groups),
      defaultGroup: defaultGroup,
    );

    return TstParseResult(
      title: title,
      config: config,
      body: body,
      document: ParsedDocument(
        blocks: parsedBody.blocks,
        effectiveGroups: parsedBody.effectiveGroups,
        allGroups: Set<String>.unmodifiable(seen),
      ),
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  static String serialize({
    required String title,
    required DocConfig config,
    required String body,
  }) {
    final buffer = StringBuffer('---\n');
    buffer.writeln('version: 1');
    buffer.writeln('title: ${_yamlString(title)}');
    buffer.writeln('columns: ${config.safeColumns}');
    final defaultGroup = config.defaultGroup;
    if (defaultGroup != null && defaultGroup.isNotEmpty) {
      buffer.writeln('defaultGroup: ${_yamlString(defaultGroup)}');
    }
    if (config.groups.isEmpty) {
      buffer.writeln('hideGroups: []');
    } else {
      buffer.writeln('hideGroups:');
      for (final group in config.groups) {
        buffer.writeln('  - name: ${_yamlString(group.name)}');
        buffer.writeln('    defaultHidden: ${group.defaultHidden}');
      }
    }
    buffer.writeln('---');
    buffer.write(body);
    return buffer.toString();
  }

  static bool isValidGroupName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains('{') ||
        trimmed.contains('}') ||
        trimmed.contains(':') ||
        trimmed.contains('\n') ||
        trimmed.contains('\r')) {
      return false;
    }
    return true;
  }

  static String _yamlString(String value) => jsonEncode(value);

  static String _normalize(String source) {
    var text = source;
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return text;
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static _FrontMatter? _extractFrontMatter(String text) {
    final firstBreak = text.indexOf('\n');
    final firstLine = firstBreak == -1 ? text : text.substring(0, firstBreak);
    if (firstLine.trimRight() != '---') return null;

    final searchStart = firstBreak == -1 ? text.length : firstBreak + 1;
    final close = RegExp(r'^---[ \t]*$', multiLine: true)
        .firstMatch(text.substring(searchStart));
    if (close == null) return null;

    final yaml = text.substring(searchStart, searchStart + close.start);
    var bodyStart = searchStart + close.end;
    if (bodyStart < text.length && text[bodyStart] == '\n') bodyStart++;
    return _FrontMatter(yaml: yaml, body: text.substring(bodyStart));
  }

  static _BodyParse _parseBody(String body) {
    final pairs = _matchHideMarkers(body);
    final blocks = <Block>[];
    final runs = <Run>[];
    final buffer = StringBuffer();
    final stack = <String>[];
    final effective = <String>{};
    final discovered = <String>[];
    Color? color;

    Set<String> currentGroups() => Set<String>.unmodifiable(stack.toSet());

    void flushText() {
      if (buffer.isEmpty) return;
      final text = buffer.toString();
      buffer.clear();
      _addRun(runs, text, color, currentGroups());
      if (text.trim().isNotEmpty) effective.addAll(stack);
    }

    void endLine() {
      flushText();
      if (runs.isEmpty) {
        runs.add(Run(' ', hideGroups: currentGroups()));
      }
      blocks.add(Block(List<Run>.unmodifiable(runs)));
      runs.clear();
      color = null;
    }

    var i = 0;
    while (i < body.length) {
      final ch = body.codeUnitAt(i);
      if (ch == 0x5C) {
        if (i + 1 < body.length) {
          final next = body.codeUnitAt(i + 1);
          if (next == 0x0A) {
            buffer.writeCharCode(ch);
            i++;
          } else {
            buffer.writeCharCode(next);
            i += 2;
          }
        } else {
          buffer.writeCharCode(ch);
          i++;
        }
        continue;
      }
      if (ch == 0x0A) {
        endLine();
        i++;
        continue;
      }
      if (ch == 0x23) {
        final hit = _tryParseColor(body, i);
        if (hit != null) {
          flushText();
          color = hit.color;
          i = hit.next;
          continue;
        }
      }
      if (ch == 0x7B) {
        final openEnd = pairs.openEnd[i];
        if (openEnd != null) {
          flushText();
          final name = pairs.openName[i]!;
          stack.add(name);
          if (!discovered.contains(name)) discovered.add(name);
          i = openEnd;
          continue;
        }
        if (pairs.closeToOpen.containsKey(i)) {
          flushText();
          if (stack.isNotEmpty) stack.removeLast();
          i += _hideClose.length;
          continue;
        }
      }
      buffer.writeCharCode(ch);
      i++;
    }
    if (buffer.isNotEmpty || runs.isNotEmpty) {
      endLine();
    }

    return _BodyParse(
      blocks: List<Block>.unmodifiable(blocks),
      effectiveGroups: Set<String>.unmodifiable(effective),
      discoveredGroups: List<String>.unmodifiable(discovered),
    );
  }

  static _HidePairs _matchHideMarkers(String body) {
    final pairs = _HidePairs();
    final stack = <int>[];
    var i = 0;
    while (i < body.length) {
      final ch = body.codeUnitAt(i);
      if (ch == 0x5C) {
        i += (i + 1 < body.length) ? 2 : 1;
        continue;
      }
      if (ch == 0x7B) {
        if (body.startsWith(_hideClose, i)) {
          if (stack.isNotEmpty) {
            final open = stack.removeLast();
            pairs.openEnd[open] = body.indexOf('}', open) + 1;
            pairs.openName[open] = body.substring(open + _hideOpen.length, body.indexOf('}', open)).trim();
            pairs.openToClose[open] = i;
            pairs.closeToOpen[i] = open;
          }
          i += _hideClose.length;
          continue;
        }
        if (body.startsWith(_hideOpen, i)) {
          final lineBreak = body.indexOf('\n', i);
          final lineEnd = lineBreak == -1 ? body.length : lineBreak;
          final close = body.indexOf('}', i + _hideOpen.length);
          if (close != -1 && close < lineEnd) {
            final name = body.substring(i + _hideOpen.length, close).trim();
            if (isValidGroupName(name)) {
              stack.add(i);
              i = close + 1;
              continue;
            }
          }
        }
      }
      i++;
    }
    return pairs;
  }

  static _ColorHit? _tryParseColor(String body, int index) {
    var end = index + 1;
    final digitsLimit = index + 7;
    while (end < body.length && end < digitsLimit && _isHex(body.codeUnitAt(end))) {
      end++;
    }
    final digits = end - index - 1;
    if (digits != 3 && digits != 6) return null;

    if (end < body.length) {
      final next = body.codeUnitAt(end);
      if (!_isWhitespace(next)) return null;
      if (next != 0x0A) end++;
    }

    var hex = body.substring(index + 1, index + 1 + digits);
    if (digits == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    return _ColorHit(Color(0xFF000000 | int.parse(hex, radix: 16)), end);
  }

  static bool _isHex(int codeUnit) {
    return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
        (codeUnit >= 0x41 && codeUnit <= 0x46) ||
        (codeUnit >= 0x61 && codeUnit <= 0x66);
  }

  static bool _isWhitespace(int codeUnit) {
    return codeUnit == 0x20 || codeUnit == 0x09 || codeUnit == 0x0A;
  }

  static void _addRun(
    List<Run> runs,
    String text,
    Color? color,
    Set<String> groups,
  ) {
    if (text.isEmpty) return;
    if (runs.isNotEmpty) {
      final last = runs.last;
      if (last.color == color && _sameGroups(last.hideGroups, groups)) {
        runs[runs.length - 1] =
            Run(last.text + text, color: color, hideGroups: last.hideGroups);
        return;
      }
    }
    runs.add(Run(text, color: color, hideGroups: groups));
  }

  static bool _sameGroups(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final item in a) {
      if (!b.contains(item)) return false;
    }
    return true;
  }
}

class _FrontMatter {
  const _FrontMatter({required this.yaml, required this.body});

  final String yaml;
  final String body;
}

class _BodyParse {
  const _BodyParse({
    required this.blocks,
    required this.effectiveGroups,
    required this.discoveredGroups,
  });

  final List<Block> blocks;
  final Set<String> effectiveGroups;
  final List<String> discoveredGroups;
}

class _HidePairs {
  final Map<int, int> openToClose = <int, int>{};
  final Map<int, int> closeToOpen = <int, int>{};
  final Map<int, int> openEnd = <int, int>{};
  final Map<int, String> openName = <int, String>{};
}

class _ColorHit {
  const _ColorHit(this.color, this.next);

  final Color color;
  final int next;
}
