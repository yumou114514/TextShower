import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'file_pick_service.dart';

class ExportResult {
  const ExportResult({this.path, this.shared = false, this.cancelled = false});

  final String? path;
  final bool shared;
  final bool cancelled;
}

class ExportService {
  ExportService({
    FilePicker? picker,
    bool? isAndroid,
  })  : _picker = picker ?? const SystemFilePicker(),
        _isAndroid = isAndroid ?? Platform.isAndroid;

  final FilePicker _picker;
  final bool _isAndroid;

  Future<ExportResult> exportText({
    required String suggestedName,
    required String contents,
    required String label,
    List<String> extensions = const <String>['tst'],
    String? mimeType,
  }) async {
    if (_isAndroid) {
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}$suggestedName',
      );
      await file.writeAsString(contents, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(file.path)], title: suggestedName),
      );
      return const ExportResult(shared: true);
    }

    final path = await _picker.savePath(
      label: label,
      extensions: extensions,
      suggestedName: suggestedName,
      mimeType: mimeType,
    );
    if (path == null) return const ExportResult(cancelled: true);
    final target = ensureExtension(path, extensions.isEmpty ? '' : extensions.first);
    await File(target).writeAsString(contents, flush: true);
    return ExportResult(path: target);
  }

  static String ensureExtension(String path, String extension) {
    if (extension.isEmpty) return path;
    if (path.toLowerCase().endsWith('.${extension.toLowerCase()}')) return path;
    final base = path.split(RegExp(r'[\\/]')).last;
    if (!base.contains('.')) return '$path.$extension';
    return path;
  }
}
