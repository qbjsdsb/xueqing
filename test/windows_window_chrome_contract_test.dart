import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Windows keeps native controls but neutralizes accent-colored chrome',
    () {
      final source = File('windows/runner/win32_window.cpp').readAsStringSync();
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(source, contains('DWMWA_CAPTION_COLOR'));
      expect(source, contains('DWMWA_BORDER_COLOR'));
      expect(source, contains('DWMWA_TEXT_COLOR'));
      expect(source, contains('WM_SETTINGCHANGE'));
      expect(source, contains('WS_OVERLAPPEDWINDOW'));
      expect(pubspec, isNot(contains('window_manager:')));
      expect(pubspec, isNot(contains('bitsdojo_window:')));
    },
  );

  test('Windows opens the main window centered in the usable work area', () {
    final source = File('windows/runner/main.cpp').readAsStringSync();

    expect(source, contains('CenterWindowInWorkArea'));
    expect(source, contains('MonitorFromWindow'));
    expect(source, contains('GetMonitorInfo'));
    expect(source, contains('window.GetHandle()'));
    expect(
      source,
      contains('SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE'),
    );
  });
}
