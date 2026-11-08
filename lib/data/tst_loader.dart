import 'dart:io';

import '../models/text_doc.dart';
import 'doc_repository.dart';
import 'text_importer.dart';
import 'tst_codec.dart';

class TstLoadResult {
  const TstLoadResult({
    required this.doc,
    required this.warnings,
    required this.encoding,
  });

  final TextDoc doc;
  final List<String> warnings;
  final String encoding;
}

class TstLoader {
  const TstLoader._();

  static Future<TstLoadResult> openPath(
    DocRepository repository,
    String path,
  ) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    return loadBytes(
      repository: repository,
      bytes: bytes,
      fileName: path,
      sourcePath: file.absolute.path,
    );
  }

  static Future<TstLoadResult> loadBytes({
    required DocRepository repository,
    required List<int> bytes,
    required String fileName,
    String? sourcePath,
  }) async {
    final decoded = TextImporter.decode(bytes);
    final parsed = TstCodec.parse(
      decoded.text,
      fallbackTitle: TextImporter.titleFromFileName(fileName),
    );

    TextDoc? existing;
    if (sourcePath != null && sourcePath.isNotEmpty) {
      existing = await repository.findBySourcePath(sourcePath);
    }

    final now = DateTime.now();
    final doc = existing == null
        ? TextDoc(
            id: newDocId(),
            title: parsed.title,
            kind: DocKind.tst,
            body: parsed.body,
            config: parsed.config,
            sourcePath: sourcePath,
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            title: parsed.title,
            body: parsed.body,
            config: parsed.config,
            sourcePath: sourcePath,
            updatedAt: now,
          );
    await repository.save(doc);

    final warnings = List<String>.of(parsed.warnings);
    if (decoded.hadErrors) {
      warnings.add('${decoded.encoding} 解码时出现无法识别的字节，部分字符可能显示为替换符。');
    }
    return TstLoadResult(doc: doc, warnings: warnings, encoding: decoded.encoding);
  }
}
