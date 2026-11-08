import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'app.dart';
import 'data/doc_repository.dart';
import 'data/tst_loader.dart';
import 'data/windows_association.dart';
import 'models/text_doc.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    unawaited(WindowsAssociation.register());
  }

  DocRepository repository;
  try {
    repository = await JsonDocRepository.open();
  } catch (_) {
    repository = MemoryDocRepository();
  }

  TextDoc? initialDoc;
  final path = WindowsAssociation.findTstArgument(args);
  if (path != null) {
    try {
      initialDoc = (await TstLoader.openPath(repository, path)).doc;
    } catch (_) {
      // 文件无法读取时仍然进入列表页。
    }
  }

  runApp(TextShowerApp(repository: repository, initialDoc: initialDoc));
}
