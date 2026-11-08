import 'dart:ui';

class Run {
  const Run(this.text, {this.color, this.hideGroups = const <String>{}});

  final String text;
  final Color? color;
  final Set<String> hideGroups;

  int get length => text.runes.length;
}

class Block {
  const Block(this.runs);

  final List<Run> runs;

  int get length => runs.fold(0, (sum, run) => sum + run.length);

  bool get isBlank => runs.every((run) => run.text.trim().isEmpty);

  String get text => runs.map((run) => run.text).join();

  Block takeChars(int maxChars) {
    if (maxChars <= 0) return const Block(<Run>[]);
    final out = <Run>[];
    var left = maxChars;
    for (final run in runs) {
      if (left <= 0) break;
      final runes = run.text.runes.toList(growable: false);
      if (runes.length <= left) {
        out.add(run);
        left -= runes.length;
      } else {
        out.add(Run(
          String.fromCharCodes(runes.take(left)),
          color: run.color,
          hideGroups: run.hideGroups,
        ));
        left = 0;
      }
    }
    return Block(out);
  }
}

class ParsedDocument {
  const ParsedDocument({
    required this.blocks,
    required this.effectiveGroups,
    required this.allGroups,
  });

  final List<Block> blocks;
  final Set<String> effectiveGroups;
  final Set<String> allGroups;

  static const ParsedDocument empty = ParsedDocument(
    blocks: <Block>[],
    effectiveGroups: <String>{},
    allGroups: <String>{},
  );

  int get charCount => blocks.fold(0, (sum, block) => sum + block.length);

  ParsedDocument filter(Set<String> hiddenGroups) {
    if (hiddenGroups.isEmpty) return this;
    final out = <Block>[];
    for (final block in blocks) {
      final kept = <Run>[];
      for (final run in block.runs) {
        if (run.hideGroups.any(hiddenGroups.contains)) continue;
        _addMerged(kept, run);
      }
      if (kept.isEmpty) continue;
      out.add(Block(List<Run>.unmodifiable(kept)));
    }
    return ParsedDocument(
      blocks: out,
      effectiveGroups: effectiveGroups,
      allGroups: allGroups,
    );
  }

  static void _addMerged(List<Run> runs, Run run) {
    if (run.text.isEmpty) return;
    if (runs.isNotEmpty) {
      final last = runs.last;
      if (last.color == run.color &&
          last.hideGroups.length == run.hideGroups.length &&
          last.hideGroups.containsAll(run.hideGroups)) {
        runs[runs.length - 1] = Run(
          last.text + run.text,
          color: run.color,
          hideGroups: last.hideGroups,
        );
        return;
      }
    }
    runs.add(run);
  }

  String preview({int maxChars = 48}) {
    final parts = <String>[];
    var count = 0;
    for (final block in blocks) {
      if (block.isBlank) continue;
      for (final run in block.runs) {
        parts.add(run.text);
        count += run.length;
        if (count >= maxChars) break;
      }
      if (count > 0) break;
    }
    final text = parts.join().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}…';
  }
}
