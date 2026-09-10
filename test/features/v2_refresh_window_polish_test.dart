import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  testWidgets('desktop refresh action invokes the real refresh callback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var refreshCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: V2WorkspacePreview(onRefresh: () async => refreshCount++),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('刷新学情'));
    await tester.pumpAndSettle();
    expect(refreshCount, 1);
    expect(find.text('已刷新最新学情。'), findsOneWidget);
  });

  testWidgets('compact More menu exposes refresh without adding a fourth tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var refreshCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: V2WorkspacePreview(onRefresh: () async => refreshCount++),
      ),
    );
    await tester.pumpAndSettle();

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.destinations.length, 3);
    await tester.tap(find.byKey(const Key('v2-compact-more')));
    await tester.pumpAndSettle();
    expect(find.text('刷新学情'), findsOneWidget);
    await tester.tap(find.text('刷新学情'));
    await tester.pumpAndSettle();
    expect(refreshCount, 1);
  });

  test('Windows caption uses neutral DWM caption, text, and border colors', () {
    final source = File('windows/runner/win32_window.cpp').readAsStringSync();
    expect(source, contains('DWMWA_CAPTION_COLOR'));
    expect(source, contains('DWMWA_TEXT_COLOR'));
    expect(source, contains('DWMWA_BORDER_COLOR'));
    expect(source, contains('WM_THEMECHANGED'));
    expect(source, contains('WM_SETTINGCHANGE'));
  });
}
