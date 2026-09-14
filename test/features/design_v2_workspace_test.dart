import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  Widget app() =>
      MaterialApp(theme: V2Theme.light(), home: const V2WorkspacePreview());

  Widget androidApp({
    EdgeInsets systemGestureInsets = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) => MaterialApp(
    theme: V2Theme.light().copyWith(platform: TargetPlatform.android),
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          systemGestureInsets: systemGestureInsets,
          viewInsets: viewInsets,
        ),
        child: child!,
      );
    },
    home: const V2WorkspacePreview(),
  );

  testWidgets(
    'desktop starts with Today and can enter student master-detail workspace',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('v2-today-quick-capture')), findsOneWidget);
      await tester.tap(find.byTooltip('我的学生'));
      await tester.pumpAndSettle();

      expect(find.text('学生'), findsWidgets);
      expect(find.text('林同学'), findsWidgets);
      expect(find.text('现在最重要'), findsOneWidget);
      expect(find.text('最近成长'), findsOneWidget);
      expect(find.text('阅读概括不完整'), findsOneWidget);
      expect(find.text('函数应用题思路不清'), findsOneWidget);
      expect(find.text('时态切换不稳定'), findsNothing);
    },
  );

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
    expect(
      find.byKey(const ValueKey<String>('v2-case-next-step-case-lin-function')),
      findsOneWidget,
    );
    expect(find.textContaining('数量关系先画成简图'), findsOneWidget);
  });

  testWidgets('desktop switches student-specific cases and timeline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('我的学生'));
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
    await tester.tap(find.byTooltip('我的学生'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('李同学').first);
    await tester.pumpAndSettle();

    expect(find.text('暂无进行中的问题'), findsOneWidget);
    expect(find.text('王老师负责语文'), findsOneWidget);
    expect(find.text('记进展'), findsNothing);
    expect(find.widgetWithText(FilledButton, '记录问题'), findsOneWidget);
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
    await tester.tap(find.text('学生'));
    await tester.pumpAndSettle();
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
    expect(navigation.selectedIndex, 0);

    await tester.tap(find.text('学生'));
    await tester.pumpAndSettle();
    navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Android compact root swipes one step between Today Students and Learning',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(androidApp());
      await tester.pumpAndSettle();

      NavigationBar navigation() =>
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      Finder swipeSurface() =>
          find.byKey(const Key('v2-compact-swipe-surface'));

      expect(swipeSurface(), findsOneWidget);
      expect(navigation().selectedIndex, 0);

      // No circular wrap before Today.
      await tester.drag(swipeSurface(), const Offset(220, 0));
      await tester.pumpAndSettle();
      expect(navigation().selectedIndex, 0);

      await tester.drag(swipeSurface(), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(navigation().selectedIndex, 1);

      await tester.drag(swipeSurface(), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(navigation().selectedIndex, 2);

      // No circular wrap after Learning.
      await tester.drag(swipeSurface(), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(navigation().selectedIndex, 2);

      await tester.drag(swipeSurface(), const Offset(220, 0));
      await tester.pumpAndSettle();
      expect(navigation().selectedIndex, 1);

      await tester.drag(swipeSurface(), const Offset(220, 0));
      await tester.pumpAndSettle();
      expect(navigation().selectedIndex, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android compact direct manipulation updates page offset before release',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(androidApp());
      await tester.pumpAndSettle();

      final surface = find.byKey(const Key('v2-compact-swipe-surface'));
      final pageView = tester.widget<PageView>(surface);
      expect(pageView.controller, isNotNull);
      expect(pageView.controller!.page, closeTo(0, 0.01));

      final gesture = await tester.startGesture(tester.getCenter(surface));
      // The first move crosses Flutter's drag slop and wins the horizontal
      // gesture arena. The second move must then update the PageView before
      // the pointer is released, which is the direct-manipulation contract.
      await gesture.moveBy(const Offset(-24, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-96, 0));
      await tester.pump();

      final draggedPage = pageView.controller!.page!;
      expect(draggedPage, greaterThan(0.05));
      expect(draggedPage, lessThan(1));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android compact center paging remains usable with system gesture insets',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        androidApp(
          systemGestureInsets: const EdgeInsets.symmetric(horizontal: 24),
        ),
      );
      await tester.pumpAndSettle();

      final surface = find.byKey(const Key('v2-compact-swipe-surface'));
      await tester.drag(surface, const Offset(-220, 0));
      await tester.pumpAndSettle();

      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigation.selectedIndex, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android compact page swipe yields while the keyboard is visible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        androidApp(viewInsets: const EdgeInsets.only(bottom: 280)),
      );
      await tester.pumpAndSettle();

      final surface = find.byKey(const Key('v2-compact-swipe-surface'));
      expect(surface, findsOneWidget);
      await tester.drag(surface, const Offset(-220, 0));
      await tester.pumpAndSettle();

      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigation.selectedIndex, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android page swipe is disabled for student detail and medium layout',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(androidApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('学生'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('林同学'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('v2-compact-swipe-surface')), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.binding.setSurfaceSize(const Size(800, 800));
      await tester.pumpWidget(androidApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-medium-shell')), findsOneWidget);
      expect(find.byKey(const Key('v2-compact-swipe-surface')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android compact root paging pauses while a text field is actively edited',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(androidApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('学生'));
      await tester.pumpAndSettle();

      final search = find.byKey(const Key('v2-student-search'));
      await tester.tap(search);
      await tester.enterText(search, '王同学');
      await tester.pump();

      final surface = find.byKey(const Key('v2-compact-swipe-surface'));
      await tester.drag(surface, const Offset(-220, 0));
      await tester.pumpAndSettle();

      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigation.selectedIndex, 1);
      expect(tester.widget<TextField>(search).controller!.text, '王同学');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android compact root pages preserve student search across destination changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(androidApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('学生'));
      await tester.pumpAndSettle();

      final search = find.byKey(const Key('v2-student-search'));
      await tester.enterText(search, '王同学');
      await tester.pump();
      expect(find.text('找到 1 位'), findsOneWidget);

      await tester.tap(find.text('学情').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('学生').last);
      await tester.pumpAndSettle();

      final restoredSearch = find.byKey(const Key('v2-student-search'));
      expect(tester.widget<TextField>(restoredSearch).controller!.text, '王同学');
      expect(find.text('找到 1 位'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('student search filters real people without changing identity', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('我的学生'));
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
    expect(find.text('周同学 · 化学'), findsOneWidget);
    expect(find.text('基础反应能完成，遇到系数稍复杂时容易反复试错。'), findsNothing);
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
