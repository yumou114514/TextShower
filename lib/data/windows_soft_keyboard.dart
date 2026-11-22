import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';

/// Flutter 桌面端聚焦输入框时不会自动拉起 Windows 触屏键盘，
/// 需要在用户用触控操作后主动启动 TabTip。
class WindowsSoftKeyboard {
  WindowsSoftKeyboard._();

  static bool _lastInputWasTouch = false;
  static bool _shownByUs = false;
  static Timer? _hideTimer;

  static void notePointerDevice(PointerDeviceKind kind) {
    _lastInputWasTouch =
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
  }

  static Future<void> showForTouchInput() async {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (!Platform.isWindows || !_lastInputWasTouch || _shownByUs) return;
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    final executable = _tabTipExecutable();
    if (executable == null) return;
    _shownByUs = true;
    try {
      await Process.start(
        executable,
        const <String>[],
        mode: ProcessStartMode.detached,
      );
    } catch (_) {
      _shownByUs = false;
    }
  }

  static void scheduleHide() {
    if (!Platform.isWindows || !_shownByUs) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 300), () {
      _hideTimer = null;
      unawaited(hideNow());
    });
  }

  static Future<void> hideNow() async {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (!Platform.isWindows || !_shownByUs) return;
    _shownByUs = false;
    try {
      await Process.run('taskkill', const <String>['/IM', 'TabTip.exe', '/F']);
    } catch (_) {
      // 触屏键盘未在运行时无需处理。
    }
  }

  static String? _tabTipExecutable() {
    final common = Platform.environment['CommonProgramFiles'];
    final candidates = <String>[
      if (common != null) '$common\\microsoft shared\\ink\\TabTip.exe',
      r'C:\Program Files\Common Files\microsoft shared\ink\TabTip.exe',
      r'C:\Program Files (x86)\Common Files\microsoft shared\ink\TabTip.exe',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }
}