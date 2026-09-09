import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  Widget app() =>
      MaterialApp(theme: V2Theme.light(), home: const V2WorkspacePreview());

  testWidgets('desktop starts with student master-detail workspace', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('学生'), findsWidgets);
    expect(find.text('林同学'), findsWidgets);
    expect(find.text('现在最重要'), findsOneWidget);
    expect(find.text('最近成长'), findsOneWidget);
    expect(find.text('阅读概括不完整'), findsWidgets);
  });

  testWidgets('desktop can open a Case without leaving the shell', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('阅读概括不完整').first);
    await tester.pumpAndSettle();

    expect(find.text('成长过程'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);
    expect(find.text('记进展'), findsOneWidget);
  });

  testWidgets('compact uses bottom navigation and opens student detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('林同学'), findsOneWidget);

    await tester.tap(find.text('林同学'));
    await tester.pumpAndSettle();

    expect(find.text('现在最重要'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
