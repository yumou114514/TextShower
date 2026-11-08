import 'dart:convert';

import 'package:charset/charset.dart';

import '../models/text_doc.dart';

class DecodedText {
  const DecodedText(
    this.text,
    this.encoding, {
    this.hadErrors = false,
  });

  final String text;
  final String encoding;
  final bool hadErrors;
}

class TextImporter {
  const TextImporter._();

  static DecodedText decode(List<int> bytes) {
    if (bytes.isEmpty) return const DecodedText('', 'UTF-8');

    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return DecodedText(
        _normalize(utf8.decode(bytes.sublist(3), allowMalformed: true)),
        'UTF-8',
      );
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return DecodedText(
        _normalize(_decodeUtf16(bytes.sublist(2), littleEndian: true)),
        'UTF-16 LE',
      );
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return DecodedText(
        _normalize(_decodeUtf16(bytes.sublist(2), littleEndian: false)),
        'UTF-16 BE',
      );
    }

    try {
      return DecodedText(_normalize(utf8.decode(bytes)), 'UTF-8');
    } on FormatException {
      try {
        return DecodedText(_normalize(gbk.decode(bytes)), 'GBK');
      } catch (_) {
        return DecodedText(
          _normalize(gbk.decode(bytes, allowMalformed: true)),
          'GBK',
          hadErrors: true,
        );
      }
    }
  }

  static TextDoc createPlainDoc({
    required String title,
    required String text,
    String? sourcePath,
  }) =>
      TextDoc(
        id: newDocId(),
        title: title,
        kind: DocKind.plain,
        body: text,
        config: const DocConfig.plain(),
        sourcePath: sourcePath,
      );

  static String titleFromFileName(String fileName) {
    final base = fileName.split(RegExp(r'[\\/]')).last;
    final dot = base.lastIndexOf('.');
    final name = dot > 0 ? base.substring(0, dot) : base;
    return name.trim().isEmpty ? '未命名' : name.trim();
  }

  static String _normalize(String text) {
    var result = text;
    if (result.startsWith('\uFEFF')) result = result.substring(1);
    return result.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  static String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(units);
  }
}
