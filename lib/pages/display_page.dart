import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/doc_repository.dart';
import '../data/file_pick_service.dart';
import '../data/tst_codec.dart';
import '../models/parsed_document.dart';
import '../models/reader_pref.dart';
import '../models/text_doc.dart';
import '../services/auto_fit.dart';
import '../services/text_measurer.dart';
import '../widgets/font_size_bar.dart';
import '../widgets/rich_blocks.dart';
import 'editor_page.dart';

class DisplayPage extends StatefulWidget {
  const DisplayPage({
    super.key,
    required this.repository,
    required this.doc,
    this.filePicker,
  });

  final DocRepository repository;
  final TextDoc doc;
  final FilePicker? filePicker;

  @override
  State<DisplayPage> createState() => _DisplayPageState();
}

class _DisplayPageState extends State<DisplayPage> {
  static const double _hPad = 24;
  static const double _vPad = 16;

  late TextDoc _doc;
  late ParsedDocument _parsed;
  late TextMeasurer _measurer;
  late AutoFitter _fitter;

  ReaderPref _pref = const ReaderPref();
  final ScrollController _scrollController = ScrollController();
  double _displayFontSize = 32;
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _doc = widget.doc;
    _measurer = TextMeasurer();
    _fitter = AutoFitter(measurer: _measurer.measureBlock);
    _parsed = _parseDoc(_doc);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  ParsedDocument _parseDoc(TextDoc doc) {
    if (doc.isTst) {
      return TstCodec.parse(doc.body, fallbackTitle: doc.title).document;
    }
    if (doc.body.isEmpty) return ParsedDocument.empty;
    final blocks = <Block>[];
    for (final line in doc.body.split('\n')) {
      blocks.add(Block(<Run>[Run(line.isEmpty ? ' ' : line)]));
    }
    return ParsedDocument(
      blocks: List<Block>.unmodifiable(blocks),
      effectiveGroups: const <String>{},
      allGroups: const <String>{},
    );
  }

  Future<void> _openEditor() async {
    final result = await Navigator.of(context).push<EditorResult>(
      MaterialPageRoute(
        builder: (context) => EditorPage(
          repository: widget.repository,
          doc: _doc,
          filePicker: widget.filePicker,
          initialFontSize: _pref.auto ? _displayFontSize : _pref.manualSize,
          onFontSizeChanged: (value) {
            if (!mounted) return;
            setState(() {
              _displayFontSize = value;
              _pref = _pref.copyWith(auto: false, manualSize: value);
            });
          },
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result.deleted) {
      Navigator.of(context).pop();
      return;
    }
    final doc = result.doc;
    if (doc == null) return;
    setState(() {
      _doc = doc;
      _parsed = _parseDoc(doc);
    });
  }

  void _scheduleToolbarRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(
          _doc.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          tooltip: '返回主页',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openEditor,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => _buildContent(constraints),
            ),
          ),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildContent(BoxConstraints constraints) {
    final width =
        (constraints.maxWidth - _hPad * 2).clamp(0.0, double.infinity);
    final height =
        (constraints.maxHeight - _vPad * 2).clamp(0.0, double.infinity);

    final blocks = _parsed.blocks;
    if (!blocks.any((block) => !block.isBlank)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '空白文稿，点击右上角编辑',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.black54),
          ),
        ),
      );
    }

    FitOutcome? outcome;
    if (width > 0 && height > 0) {
      outcome = _fitter.fit(
        blocks: blocks,
        width: width,
        height: height,
        columns: 1,
      );
    }

    final fontSize = _pref.auto
        ? (outcome?.fontSize ?? _displayFontSize)
        : _pref.manualSize;
    if (_pref.auto && _displayFontSize != fontSize) {
      _displayFontSize = fontSize;
      _scheduleToolbarRefresh();
    }

    return ListView.builder(
      key: const ValueKey<String>('single-column'),
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: _vPad),
      itemCount: blocks.length,
      itemBuilder: (context, index) => RichBlockText(
        block: blocks[index],
        fontSize: fontSize,
        color: Colors.black,
      ),
    );
  }

  Widget _buildToolbar() {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: FontSizeBar(
            value: _pref.auto ? _displayFontSize : _pref.manualSize,
            auto: _pref.auto,
            onChanged: (value) => setState(() {
              _pref = _pref.copyWith(auto: false, manualSize: value);
            }),
            onAuto: () => setState(() {
              _pref = _pref.copyWith(auto: true);
            }),
          ),
        ),
      ),
    );
  }
}
