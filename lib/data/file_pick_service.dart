import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as fs;

class PickedFile {
  const PickedFile({
    required this.path,
    required this.name,
    required this.bytes,
  });

  final String path;
  final String name;
  final Uint8List bytes;
}

abstract class FilePicker {
  Future<PickedFile?> open({
    required String label,
    required List<String> extensions,
    String? mimeType,
  });

  Future<String?> savePath({
    required String label,
    required List<String> extensions,
    required String suggestedName,
    String? mimeType,
  });
}

class SystemFilePicker implements FilePicker {
  const SystemFilePicker();

  fs.XTypeGroup _group(
    String label,
    List<String> extensions,
    String? mimeType,
  ) =>
      fs.XTypeGroup(
        label: label,
        extensions: extensions,
        mimeTypes: mimeType == null ? null : <String>[mimeType],
      );

  @override
  Future<PickedFile?> open({
    required String label,
    required List<String> extensions,
    String? mimeType,
  }) async {
    final file = await fs.openFile(
      acceptedTypeGroups: <fs.XTypeGroup>[
        _group(label, extensions, mimeType),
      ],
    );
    if (file == null) return null;
    return PickedFile(
      path: file.path,
      name: file.name,
      bytes: await file.readAsBytes(),
    );
  }

  @override
  Future<String?> savePath({
    required String label,
    required List<String> extensions,
    required String suggestedName,
    String? mimeType,
  }) async {
    final location = await fs.getSaveLocation(
      acceptedTypeGroups: <fs.XTypeGroup>[
        _group(label, extensions, mimeType),
      ],
      suggestedName: suggestedName,
    );
    return location?.path;
  }
}
