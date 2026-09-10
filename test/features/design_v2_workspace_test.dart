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
    expect(find.text('阅读概括不完整'), findsOneWidget);
    expect(find.text('函数应用题思路不清'), findsOneWidget);
    expect(find.text('时态切换不稳定'), findsNothing);
  });

  testWidgets('desktop can open the selected Case without leaving the shell', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('函数应用题思路不清'));
    await tester.pumpAndSettle();

    expect(find.text('林同学 · 数学'), findsOneWidget);
    expect(find.text('函数应用题思路不清'), findsOneWidget);
    expect(find.text('成长过程'), findsOneWidget);
    expect(find.text('再练 2 道同类题'), findsOneWidget);
    expect(find.textContaining('数量关系先画成简图'), findsOneWidget);
  });

  testWidgets('desktop switches student-specific cases and timeline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('王同学').first);
    await tester.pumpAndSettle();

    expect(find.text('时态切换不稳定'), findsOneWidget);
    expect(find.text('阅读概括不完整'), findsNothing);
    expect(find.text('陈老师负责英语'), findsOneWidget);

    await tester.tap(find.text('时态切换不稳定'));
    await tester.pumpAndSettle();

    expect(find.text('王同学 · 英语'), findsOneWidget);
    expect(find.textContaining('语篇中仍会被最近一个时间状语干扰'), findsOneWidget);
    expect(find.textContaining('对象 + 特征 + 结果'), findsNothing);
  });

  testWidgets('student with no active Case cannot start progress capture', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('李同学').first);
    await tester.pumpAndSettle();

    expect(find.text('暂无进行中的问题'), findsOneWidget);
    expect(find.text('王老师负责语文'), findsOneWidget);
    final progressButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '记进展'),
    );
    expect(progressButton.onPressed, isNull);
  });

  testWidgets('Today opens the exact student and Case identity', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('今日'));
    await tester.pumpAndSettle();

    expect(find.text('王同学 · 英语'), findsOneWidget);
    await tester.tap(find.text('王同学 · 英语'));
    await tester.pumpAndSettle();

    expect(find.text('时态切换不稳定'), findsOneWidget);
    expect(find.text('王同学 · 英语'), findsOneWidget);
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

    await tester.tap(find.text('阅读概括不完整'));
    await tester.pumpAndSettle();
    expect(find.text('林同学 · 语文'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact system back returns secondary destination to Today', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    var navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student search filters real people without changing identity', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('v2-student-search')), '王同学');
    await tester.pump();

    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('王同学')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('林同学')),
      findsNothing,
    );
    expect(find.text('找到 1 位'), findsOneWidget);
  });

  testWidgets('case search filters and opens the exact matching Case', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('学情'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('v2-case-search')), '配平');
    await tester.pump();

    expect(find.text('化学方程式配平不稳'), findsOneWidget);
    expect(find.text('阅读概括不完整'), findsNothing);
    expect(find.text('找到 1 个问题'), findsOneWidget);

    await tester.tap(find.text('化学方程式配平不稳'));
    await tester.pumpAndSettle();

    expect(find.text('周同学 · 化学'), findsOneWidget);
    expect(find.text('集中练 5 组配平'), findsOneWidget);
  });

  testWidgets('Today deep link really enters Case detail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('今日'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('王同学 · 英语'));
    await tester.pumpAndSettle();

    expect(find.text('成长过程'), findsOneWidget);
    expect(find.text('用一篇完形再检查'), findsOneWidget);
    expect(find.textContaining('语篇中仍会被最近一个时间状语干扰'), findsOneWidget);
  });
}
