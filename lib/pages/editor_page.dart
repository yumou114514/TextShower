import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/doc_repository.dart';
import '../data/export_service.dart';
import '../data/file_pick_service.dart';
import '../data/tst_codec.dart';
import '../models/text_doc.dart';
import '../widgets/name_input_dialog.dart';

class EditorResult {
  const EditorResult({this.doc, this.deleted = false});

  final TextDoc? doc;
  final bool deleted;
}

enum _EditorAction { save, rename, duplicate, export, delete }

class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    required this.repository,
    required this.doc,
    this.filePicker,
    this.exportService,
    this.initialFontSize,
    this.onFontSizeChanged,
  });

  final DocRepository repository;
  final TextDoc doc;
  final FilePicker? filePicker;
  final ExportService? exportService;
  final double? initialFontSize;
  final ValueChanged<double>? onFontSizeChanged;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late TextDoc _persisted;
  late TextEditingController _bodyController;
  late TextEditingController _titleController;
  late final FocusNode _focusNode;

  late double _fontSize;
  bool _dirty = false;
  bool _dialogOpen = false;

  final Map<int, Offset> _pointers = <int, Offset>{};
  double? _pinchStartDistance;
  double _pinchStartFontSize = 32;

  bool get _isTst => _persisted.isTst;

  @override
  void initState() {
    super.initState();
    _persisted = widget.doc;
    _bodyController = TextEditingController(text: widget.doc.body);
    _titleController = TextEditingController(text: widget.doc.title);
    _focusNode = FocusNode();
    _fontSize = widget.initialFontSize ?? 32;
    _bodyController.addListener(_onBodyChanged);
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _bodyController.removeListener(_onBodyChanged);
    _titleController.removeListener(_onTitleChanged);
    _bodyController.dispose();
    _titleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setFontSize(double value) {
    final next = value.clamp(8.0, 200.0);
    if ((next - _fontSize).abs() < 0.01) return;
    setState(() => _fontSize = next);
    widget.onFontSizeChanged?.call(next);
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      final positions = _pointers.values.toList();
      _pinchStartDistance = (positions[0] - positions[1]).distance;
      _pinchStartFontSize = _fontSize;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final start = _pinchStartDistance;
    if (start == null || start <= 0 || _pointers.length < 2) return;
    final positions = _pointers.values.toList();
    final distance = (positions[0] - positions[1]).distance;
    _setFontSize(_pinchStartFontSize * distance / start);
  }

  void _onPointerEnd(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) _pinchStartDistance = null;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        !HardwareKeyboard.instance.isControlPressed) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      _setFontSize(_fontSize - scroll.scrollDelta.dy / 20);
    });
  }

  void _onBodyChanged() {
    setState(() => _dirty = true);
  }

  void _onTitleChanged() {
    setState(() => _dirty = true);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _snack('标题不能为空');
      return false;
    }
    final doc = _persisted.copyWith(
      title: title,
      body: _bodyController.text,
      updatedAt: DateTime.now(),
    );
    try {
      await widget.repository.save(doc);
    } catch (error) {
      _snack('保存失败：$error');
      return false;
    }
    _persisted = doc;
    if (mounted) setState(() => _dirty = false);

    final sourcePath = doc.sourcePath;
    if (doc.isTst && sourcePath != null && sourcePath.isNotEmpty) {
      try {
        await File(sourcePath).writeAsString(
          TstCodec.serialize(title: title, config: doc.config, body: doc.body),
          flush: true,
        );
      } catch (error) {
        _snack('已保存到文稿库，但写回源文件失败：$error');
        return true;
      }
    }
    _snack('已保存');
    return true;
  }

  Future<void> _handleExit() async {
    if (_dialogOpen) return;
    if (!_dirty) {
      Navigator.of(context).pop(EditorResult(doc: _persisted));
      return;
    }
    _dialogOpen = true;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存的修改'),
        content: const Text('是否保存当前修改？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('不保存'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted || choice == null) return;
    if (choice == 'save') {
      final saved = await _save();
      if (!saved || !mounted) return;
    }
    Navigator.of(context).pop(EditorResult(doc: _persisted));
  }

  Future<void> _onMenu(_EditorAction action) async {
    switch (action) {
      case _EditorAction.save:
        await _save();
      case _EditorAction.rename:
        await _rename();
      case _EditorAction.duplicate:
        await _duplicate();
      case _EditorAction.export:
        await _export();
      case _EditorAction.delete:
        await _delete();
    }
  }

  Future<void> _rename() async {
    final name = await _askName(
      title: '重命名',
      initial: _titleController.text,
      validate: (value) => value.isEmpty ? '名称不能为空' : null,
    );
    if (name == null || !mounted) return;
    _titleController.text = name;
  }

  Future<void> _duplicate() async {
    final title = _titleController.text.trim();
    final now = DateTime.now();
    final copy = TextDoc(
      id: newDocId(),
      title: title.isEmpty ? '未命名副本' : '$title 副本',
      kind: _persisted.kind,
      body: _bodyController.text,
      config: _persisted.config,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await widget.repository.save(copy);
    } catch (error) {
      _snack('另存为副本失败：$error');
      return;
    }
    if (!mounted) return;
    setState(() {
      _persisted = copy;
      _titleController.text = copy.title;
      _dirty = false;
    });
    _snack('已另存为副本');
  }

  Future<void> _export() async {
    final title = _titleController.text.trim();
    final safeTitle = _safeFileName(title.isEmpty ? '未命名' : title);
    final service = widget.exportService ??
        ExportService(picker: widget.filePicker);
    final contents = _isTst
        ? TstCodec.serialize(
            title: title.isEmpty ? '未命名' : title,
            config: _persisted.config,
            body: _bodyController.text,
          )
        : _bodyController.text;
    try {
      final result = await service.exportText(
        suggestedName: '$safeTitle.${_isTst ? 'tst' : 'txt'}',
        contents: contents,
        label: _isTst ? 'tst文稿' : '纯文本',
        extensions: <String>[_isTst ? 'tst' : 'txt'],
        mimeType: _isTst ? 'application/octet-stream' : 'text/plain',
      );
      if (result.cancelled) return;
      if (result.shared) {
        _snack('已打开分享');
      } else if (result.path != null) {
        _snack('已导出到 ${result.path}');
      }
    } catch (error) {
      _snack('导出失败：$error');
    }
  }

  static String _safeFileName(String title) {
    final cleaned = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? '未命名' : cleaned;
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文档'),
        content: Text('确定删除「${_persisted.title}」吗？此操作不可撤销。'),
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
    try {
      await widget.repository.delete(_persisted.id);
    } catch (error) {
      _snack('删除失败：$error');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(const EditorResult(deleted: true));
  }

  @override
  Widget build(BuildContext context) {
    final title = _titleController.text.trim();
    final body = _bodyController.text;
    final lineCount = body.isEmpty ? 1 : '\n'.allMatches(body).length + 1;
    final charCount = body.replaceAll('\n', '').length;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F2EA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF8F2),
          foregroundColor: Colors.black87,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: PopupMenuButton<_EditorAction>(
            tooltip: '菜单',
            icon: const Icon(Icons.menu),
            onSelected: _onMenu,
            itemBuilder: (context) => <PopupMenuEntry<_EditorAction>>[
              const PopupMenuItem(
                value: _EditorAction.save,
                child: Text('保存'),
              ),
              const PopupMenuItem(
                value: _EditorAction.rename,
                child: Text('重命名'),
              ),
              const PopupMenuItem(
                value: _EditorAction.duplicate,
                child: Text('另存为副本'),
              ),
              const PopupMenuItem(
                value: _EditorAction.export,
                child: Text('导出文件'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _EditorAction.delete,
                child: Text('删除文档'),
              ),
            ],
          ),
          title: Text(
            title.isEmpty ? '未命名' : title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              tooltip: '查看',
              icon: const Icon(Icons.visibility_outlined),
              onPressed: _handleExit,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          onPointerSignal: _onPointerSignal,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    key: const ValueKey<String>('editor-body'),
                    controller: _bodyController,
                    focusNode: _focusNode,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(
                      fontSize: _fontSize,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '在这里输入文字。',
                      hintStyle: TextStyle(color: Colors.black38),
                    ),
                  ),
                ),
              ),
              _buildBottomBar(charCount, lineCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(int charCount, int lineCount) {
    return Material(
      color: const Color(0xFFEAE5DA),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '$charCount 字 · $lineCount 行',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.zoom_in,
                    size: 18,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_fontSize.round()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Align(
                alignment: Alignment.centerLeft,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _askName({
    required String title,
    required String initial,
    required String? Function(String value) validate,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => NameInputDialog(
        title: title,
        initial: initial,
        validate: validate,
      ),
    );
  }
}
