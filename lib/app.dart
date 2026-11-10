import 'package:flutter/material.dart';

import 'data/doc_repository.dart';
import 'data/file_pick_service.dart';
import 'models/text_doc.dart';
import 'pages/library_page.dart';

class TextShowerApp extends StatelessWidget {
  const TextShowerApp({
    super.key,
    required this.repository,
    this.initialDoc,
    this.filePicker,
  });

  final DocRepository repository;
  final TextDoc? initialDoc;
  final FilePicker? filePicker;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TextShower',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4C5BD4),
        ),
      ),
      home: LibraryPage(
        repository: repository,
        initialDoc: initialDoc,
        filePicker: filePicker,
      ),
    );
  }
}
