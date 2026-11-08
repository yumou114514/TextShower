import 'dart:io';

class WindowsAssociation {
  const WindowsAssociation._();

  static const String progId = 'TextShower.tst';
  static const String description = 'TextShower 小测文稿';

  static List<List<String>> buildCommands(String executablePath) {
    final quotedExe = '"$executablePath"';
    return <List<String>>[
      <String>[
        'add',
        r'HKCU\Software\Classes\.tst',
        '/ve',
        '/d',
        progId,
        '/f',
      ],
      <String>[
        'add',
        r'HKCU\Software\Classes\.tst',
        '/v',
        'Content Type',
        '/d',
        'text/plain',
        '/f',
      ],
      <String>[
        'add',
        r'HKCU\Software\Classes\TextShower.tst',
        '/ve',
        '/d',
        description,
        '/f',
      ],
      <String>[
        'add',
        r'HKCU\Software\Classes\TextShower.tst\DefaultIcon',
        '/ve',
        '/d',
        '$quotedExe,0',
        '/f',
      ],
      <String>[
        'add',
        r'HKCU\Software\Classes\TextShower.tst\shell\open\command',
        '/ve',
        '/d',
        '$quotedExe "%1"',
        '/f',
      ],
    ];
  }

  static Future<void> register() async {
    if (!Platform.isWindows) return;
    for (final args in buildCommands(Platform.resolvedExecutable)) {
      try {
        await Process.run('reg', args);
      } catch (_) {
        // 注册失败不影响应用使用，双击关联只是便利功能。
      }
    }
  }

  static String? findTstArgument(List<String> args) {
    for (final arg in args) {
      if (arg.isEmpty || arg.startsWith('-')) continue;
      if (!arg.toLowerCase().endsWith('.tst')) continue;
      try {
        final file = File(arg);
        if (file.existsSync()) return file.absolute.path;
      } catch (_) {
        // 无法访问的参数忽略。
      }
    }
    return null;
  }
}
