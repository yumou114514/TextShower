import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:text_shower/data/doc_repository.dart';
import 'package:text_shower/models/text_doc.dart';

TextDoc makeDoc({
  String id = 'doc-1',
  String title = '单元小测',
  String body = 'apple 苹果',
  DocKind kind = DocKind.tst,
  String? sourcePath,
  DocConfig? config,
}) =>
    TextDoc(
      id: id,
      title: title,
      kind: kind,
      body: body,
      config: config ??
          DocConfig(
            columns: 2,
            groups: const [
              HideGroup(name: '英文'),
              HideGroup(name: '音标', defaultHidden: true),
            ],
            defaultGroup: '英文',
          ),
      sourcePath: sourcePath,
    );

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('text_shower_repo_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  group('JsonDocRepository', () {
    test('保存后新实例可重新加载', () async {
      final repo = JsonDocRepository(directory: directory);
      await repo.save(makeDoc(sourcePath: r'C:\docs\unit3.tst'));

      final reloaded = JsonDocRepository(directory: directory);
      final docs = await reloaded.loadAll();
      expect(docs, hasLength(1));
      final doc = docs.single;
      expect(doc.id, 'doc-1');
      expect(doc.title, '单元小测');
      expect(doc.kind, DocKind.tst);
      expect(doc.sourcePath, r'C:\docs\unit3.tst');
      expect(doc.config.columns, 2);
      expect(doc.config.groups, const [
        HideGroup(name: '英文'),
        HideGroup(name: '音标', defaultHidden: true),
      ]);
      expect(doc.config.defaultGroup, '英文');
      expect(File('${directory.path}${Platform.pathSeparator}docs.json').existsSync(),
          isTrue);
      expect(
          File('${directory.path}${Platform.pathSeparator}docs.json.tmp')
              .existsSync(),
          isFalse);
    });

    test('同 id 保存覆盖而不新增', () async {
      final repo = JsonDocRepository(directory: directory);
      await repo.save(makeDoc());
      await repo.save(makeDoc(title: '改名后'));
      final docs = await repo.loadAll();
      expect(docs, hasLength(1));
      expect(docs.single.title, '改名后');
    });

    test('删除文档', () async {
      final repo = JsonDocRepository(directory: directory);
      await repo.save(makeDoc(id: 'a'));
      await repo.save(makeDoc(id: 'b'));
      await repo.delete('a');
      final docs = await repo.loadAll();
      expect(docs.map((d) => d.id), ['b']);
      expect(await repo.findById('a'), isNull);
    });

    test('按 sourcePath 查找', () async {
      final repo = JsonDocRepository(directory: directory);
      await repo.save(makeDoc(sourcePath: r'C:\Docs\Unit3.tst'));
      final found = await repo.findBySourcePath(r'C:\Docs\Unit3.tst');
      expect(found?.id, 'doc-1');
      expect(await repo.findBySourcePath(r'C:\Docs\Other.tst'), isNull);
    });

    test('损坏的 JSON 被隔离并给出警告', () async {
      final file = File('${directory.path}${Platform.pathSeparator}docs.json');
      await file.writeAsString('这不是 JSON');
      final repo = JsonDocRepository(directory: directory);
      final docs = await repo.loadAll();
      expect(docs, isEmpty);
      expect(repo.loadWarning, isNotNull);
      expect(file.existsSync(), isFalse);
      final broken = directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('.broken-'))
          .toList();
      expect(broken, hasLength(1));
    });

    test('结构不正确也按损坏处理', () async {
      final file = File('${directory.path}${Platform.pathSeparator}docs.json');
      await file.writeAsString('{"docs": 5}');
      final repo = JsonDocRepository(directory: directory);
      expect(await repo.loadAll(), isEmpty);
      expect(repo.loadWarning, isNotNull);
    });

    test('损坏后可以继续写入新文档', () async {
      final file = File('${directory.path}${Platform.pathSeparator}docs.json');
      await file.writeAsString('{bad');
      final repo = JsonDocRepository(directory: directory);
      await repo.loadAll();
      await repo.save(makeDoc(id: 'new'));
      final reloaded = JsonDocRepository(directory: directory);
      expect((await reloaded.loadAll()).single.id, 'new');
    });
  });

  group('MemoryDocRepository', () {
    test('基本增删查', () async {
      final repo = MemoryDocRepository([makeDoc(id: 'a')]);
      expect((await repo.loadAll()).single.id, 'a');
      await repo.save(makeDoc(id: 'b'));
      expect((await repo.loadAll()).map((d) => d.id), ['a', 'b']);
      await repo.delete('a');
      expect((await repo.loadAll()).map((d) => d.id), ['b']);
      expect(repo.loadWarning, isNull);
    });
  });
}
