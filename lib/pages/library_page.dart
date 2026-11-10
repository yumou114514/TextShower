import 'package:flutter/material.dart';

import '../data/doc_repository.dart';
import '../data/file_pick_service.dart';
import '../data/tst_codec.dart';
import '../data/tst_loader.dart';
import '../models/text_doc.dart';
import '../widgets/doc_tile.dart';
import '../widgets/name_input_dialog.dart';
import 'display_page.dart';
import 'editor_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.repository,
    this.initialDoc,
    this.filePicker,
  });

  final DocRepository repository;
  final TextDoc? initialDoc;
  final FilePicker? filePicker;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final FilePicker _picker;
  List<TextDoc> _docs = <TextDoc>[];
  Map<String, String> _previews = <String, String>{};
  bool _loading = true;
  bool _initialOpened = false;
  String? _shownWarning;

  @override
  void initState() {
    super.initState();
    _picker = widget.filePicker ?? const SystemFilePicker();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final doc = widget.initialDoc;
      if (doc != null && !_initialOpened && mounted) {
        _initialOpened = true;
        _openViewer(doc);
      }
    });
  }

  Future<void> _load() async {
    final docs = await widget.repository.loadAll();
    docs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final previews = <String, String>{
      for (final doc in docs) doc.id: _previewFor(doc),
    };
    if (!mounted) return;
    setState(() {
      _docs = docs;
      _previews = previews;
      _loading = false;
    });
    final warning = widget.repository.loadWarning;
    if (warning != null && warning != _shownWarning) {
      _shownWarning = warning;
      _snack(warning);
    }
  }

  String _previewFor(TextDoc doc) {
    if (!doc.isTst) {
      for (final line in doc.body.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          return trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed;
        }
      }
      return '';
    }
    try {
      final parsed = TstCodec.parse(doc.body, fallbackTitle: doc.title);
      return parsed.document.preview(maxChars: 60);
    } catch (_) {
      return '';
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openFile() async {
    try {
      final file = await _picker.open(
        label: '文稿',
        extensions: const <String>[],
        mimeType: null,
      );
      if (file == null) return;
      final result = await TstLoader.loadBytes(
        repository: widget.repository,
        bytes: file.bytes,
        fileName: file.name,
        sourcePath: file.path.isEmpty ? null : file.path,
      );
      if (!mounted) return;
      if (result.warnings.isNotEmpty) _snack(result.warnings.first);
      await _openViewer(result.doc);
    } catch (error) {
      _snack('打开失败：$error');
    }
  }

  Future<void> _createDoc() async {
    final now = DateTime.now();
    final doc = TextDoc(
      id: newDocId(),
      title: '文稿',
      kind: DocKind.tst,
      body: '',
      config: DocConfig.tstDefault(),
      createdAt: now,
      updatedAt: now,
    );
    await widget.repository.save(doc);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    final result = await Navigator.of(context).push<EditorResult>(
      MaterialPageRoute(
        builder: (context) =>
            EditorPage(repository: widget.repository, doc: doc),
      ),
    );
    if (!mounted) return;
    await _load();
    final updated = result?.doc;
    if (updated != null && !(result?.deleted ?? false)) {
      await _openViewer(updated);
    }
  }

  Future<void> _openViewer(TextDoc doc) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DisplayPage(
          repository: widget.repository,
          doc: doc,
          filePicker: _picker,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _renameDoc(TextDoc doc) async {
    final name = await _askName(
      title: '重命名',
      initial: doc.title,
      confirmText: '保存',
    );
    if (name == null) return;
    await widget.repository.save(
      doc.copyWith(title: name, updatedAt: DateTime.now()),
    );
    await _load();
  }

  Future<void> _deleteDoc(TextDoc doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文档'),
        content: Text('确定删除「${doc.title}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.delete(doc.id);
    await _load();
  }

  Future<String?> _askName({
    required String title,
    required String initial,
    required String confirmText,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => NameInputDialog(
        title: title,
        initial: initial,
        confirmText: confirmText,
        validate: (value) => value.isEmpty ? '名称不能为空' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文字展示'),
        actions: [
          IconButton(
            tooltip: '打开文件',
            onPressed: _openFile,
            icon: const Icon(Icons.folder_open_outlined),
          ),
          IconButton(
            tooltip: '新建',
            onPressed: _createDoc,
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _docs.isEmpty
              ? _EmptyState(onCreate: _createDoc)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _docs.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 76),
                  itemBuilder: (context, index) {
                    final doc = _docs[index];
                    return DocTile(
                      doc: doc,
                      preview: _previews[doc.id] ?? '',
                      onTap: () => _openViewer(doc),
                      onRename: () => _renameDoc(doc),
                      onDelete: () => _deleteDoc(doc),
                    );
                  },
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text('还没有文稿', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '新建文稿，或打开任意文本文件',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('新建文稿'),
          ),
        ],
      ),
    );
  }
}
