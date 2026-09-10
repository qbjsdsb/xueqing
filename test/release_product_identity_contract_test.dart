import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user-facing product name is 学情 across release surfaces', () {
    final app = File('lib/app/app.dart').readAsStringSync();
    final android = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final windowsMain = File('windows/runner/main.cpp').readAsStringSync();
    final windowsResources = File('windows/runner/Runner.rc')
        .readAsStringSync();
    final installer = File('installer/windows/xueqing.iss').readAsStringSync();

    expect(app, contains("title: '学情'"));
    expect(android, contains('android:label="学情"'));
    expect(windowsMain, contains(r'L"\u5B66\u60C5"'));
    expect(windowsResources, contains('VALUE "ProductName", "学情"'));
    expect(windowsResources, contains('VALUE "FileDescription", "学情"'));
    expect(installer, contains('#define AppName "学情"'));
  });
}
