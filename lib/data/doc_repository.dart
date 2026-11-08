import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/text_doc.dart';

abstract class DocRepository {
  String? get loadWarning;

  Future<List<TextDoc>> loadAll();

  Future<TextDoc?> findById(String id);

  Future<TextDoc?> findBySourcePath(String path);

  Future<void> save(TextDoc doc);

  Future<void> delete(String id);
}

class JsonDocRepository implements DocRepository {
  JsonDocRepository({required Directory directory})
      : _directory = directory,
        _file = File(_join(directory.path, 'docs.json'));

  static Future<JsonDocRepository> open() async {
    final directory = await getApplicationSupportDirectory();
    return JsonDocRepository(directory: directory);
  }

  final Directory _directory;
  final File _file;

  List<TextDoc>? _docs;
  String? _loadWarning;

  @override
  String? get loadWarning => _loadWarning;

  @override
  Future<List<TextDoc>> loadAll() async {
    final cached = _docs;
    if (cached != null) return List<TextDoc>.of(cached);
    if (!await _file.exists()) {
      _docs = <TextDoc>[];
      return <TextDoc>[];
    }

    try {
      final raw = await _file.readAsBytes();
      final decoded = jsonDecode(utf8.decode(raw));
      final list = <TextDoc>[];
      final entries = decoded is Map ? decoded['docs'] : decoded;
      if (entries is! List) {
        throw const FormatException('docs.json 结构不正确');
      }
      for (final item in entries) {
        if (item is Map) list.add(TextDoc.fromJson(item));
      }
      _docs = list;
      _loadWarning = null;
      return List<TextDoc>.of(list);
    } catch (_) {
      _docs = <TextDoc>[];
      _loadWarning = '文档库文件损坏，已备份并重新开始。';
      await _quarantine();
      return <TextDoc>[];
    }
  }

  @override
  Future<TextDoc?> findById(String id) async {
    final docs = await loadAll();
    for (final doc in docs) {
      if (doc.id == id) return doc;
    }
    return null;
  }

  @override
  Future<TextDoc?> findBySourcePath(String path) async {
    final docs = await loadAll();
    for (final doc in docs) {
      if (_samePath(doc.sourcePath, path)) return doc;
    }
    return null;
  }

  @override
  Future<void> save(TextDoc doc) async {
    final docs = List<TextDoc>.of(await loadAll());
    final index = docs.indexWhere((item) => item.id == doc.id);
    if (index >= 0) {
      docs[index] = doc;
    } else {
      docs.add(doc);
    }
    _docs = docs;
    await _flush();
  }

  @override
  Future<void> delete(String id) async {
    final docs = List<TextDoc>.of(await loadAll());
    docs.removeWhere((doc) => doc.id == id);
    _docs = docs;
    await _flush();
  }

  Future<void> _flush() async {
    await _directory.create(recursive: true);
    final tmp = File('${_file.path}.tmp');
    final payload = const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'version': 1,
      'docs': (_docs ?? const <TextDoc>[]).map((doc) => doc.toJson()).toList(),
    });
    await tmp.writeAsString(payload, encoding: utf8, flush: true);
    try {
      await tmp.rename(_file.path);
    } on FileSystemException {
      if (await _file.exists()) await _file.delete();
      await tmp.rename(_file.path);
    }
  }

  Future<void> _quarantine() async {
    try {
      if (!await _file.exists()) return;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await _file.rename('${_file.path}.broken-$stamp');
    } catch (_) {
      // 备份失败时保留原文件，避免进一步破坏数据。
    }
  }

  static String _join(String directory, String name) {
    if (directory.endsWith(Platform.pathSeparator) ||
        directory.endsWith('/') ||
        directory.endsWith('\\')) {
      return '$directory$name';
    }
    return '$directory${Platform.pathSeparator}$name';
  }

  static bool _samePath(String? a, String? b) {
    if (a == null || b == null) return false;
    var left = a.replaceAll('\\', '/');
    var right = b.replaceAll('\\', '/');
    if (Platform.isWindows) {
      left = left.toLowerCase();
      right = right.toLowerCase();
    }
    return left == right;
  }
}

class MemoryDocRepository implements DocRepository {
  MemoryDocRepository([List<TextDoc> initial = const <TextDoc>[]])
      : _docs = List<TextDoc>.of(initial);

  final List<TextDoc> _docs;

  @override
  String? get loadWarning => null;

  @override
  Future<List<TextDoc>> loadAll() async => List<TextDoc>.of(_docs);

  @override
  Future<TextDoc?> findById(String id) async {
    for (final doc in _docs) {
      if (doc.id == id) return doc;
    }
    return null;
  }

  @override
  Future<TextDoc?> findBySourcePath(String path) async {
    for (final doc in _docs) {
      if (doc.sourcePath == path) return doc;
    }
    return null;
  }

  @override
  Future<void> save(TextDoc doc) async {
    final index = _docs.indexWhere((item) => item.id == doc.id);
    if (index >= 0) {
      _docs[index] = doc;
    } else {
      _docs.add(doc);
    }
  }

  @override
  Future<void> delete(String id) async {
    _docs.removeWhere((doc) => doc.id == id);
  }
}
