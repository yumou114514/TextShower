import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:text_shower/data/windows_association.dart';

void main() {
  group('buildCommands', () {
    test('注册 .tst 关联并写入打开命令', () {
      final commands =
          WindowsAssociation.buildCommands(r'C:\Apps\TextShower\text_shower.exe');

      expect(commands.length, 5);
      expect(
        commands.first,
        <String>[
          'add',
          r'HKCU\Software\Classes\.tst',
          '/ve',
          '/d',
          WindowsAssociation.progId,
          '/f',
        ],
      );
      final open = commands.last;
      expect(
        open,
        <String>[
          'add',
          r'HKCU\Software\Classes\TextShower.tst\shell\open\command',
          '/ve',
          '/d',
          r'"C:\Apps\TextShower\text_shower.exe" "%1"',
          '/f',
        ],
      );
    });
  });

  group('findTstArgument', () {
    test('返回第一个存在的 .tst 文件', () {
      final directory =
          Directory.systemTemp.createTempSync('text_shower_assoc');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}quiz.tst',
      )..writeAsStringSync('content');

      final result = WindowsAssociation.findTstArgument(
        <String>['C:\\app.exe', '--flag', 'missing.tst', file.path],
      );

      expect(result, file.absolute.path);
    });

    test('没有参数或文件不存在时返回 null', () {
      expect(WindowsAssociation.findTstArgument(const <String>[]), isNull);
      expect(
        WindowsAssociation.findTstArgument(
          <String>['--open', 'missing.tst', 'readme.txt'],
        ),
        isNull,
      );
    });
  });
}
