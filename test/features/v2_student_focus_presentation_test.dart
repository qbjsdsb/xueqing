import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_fixture.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_data.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  Widget app(V2WorkspaceData data) => MaterialApp(
    theme: V2Theme.light(),
    home: V2WorkspacePreview(data: data),
  );

  V2WorkspaceData dataWith(List<V2FocusItem> items) => V2WorkspaceData(
    students: [
      V2Student(
        id: 'student-1',
        name: '测试学生',
        grade: '初三',
        subjects: const ['语文'],
        openCaseCount: items.length,
        updatedLabel: '已有更新',
        teacherSummary: '当前工作区 · 语文',
      ),
    ],
    focusItems: items,
    timeline: const [],
  );

  testWidgets(
    'student focus hides visually duplicated summary and concise next step',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final data = dataWith(const [
        V2FocusItem(
          id: 'duplicate-case',
          studentId: 'student-1',
          title: '文言文翻译还得加强，测试不过关',
          summary: '  文言文翻译还得加强，测试不过关。 ',
          nextStep: '待安排下一步',
          dueLabel: '待安排',
          subject: '语文',
        ),
      ]);

      await tester.pumpWidget(app(data));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('我的学生'));
      await tester.pumpAndSettle();

      expect(find.text('文言文翻译还得加强，测试不过关'), findsOneWidget);
      expect(find.text('  文言文翻译还得加强，测试不过关。 '), findsNothing);
      expect(find.text('下一步  待安排'), findsOneWidget);
      expect(find.text('下一步  待安排下一步'), findsNothing);
    },
  );

  testWidgets('student focus keeps a genuinely different summary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final data = dataWith(const [
      V2FocusItem(
        id: 'distinct-case',
        studentId: 'student-1',
        title: '不太会',
        summary: '还行，但独立完成时不稳定',
        nextStep: '再次测试',
        dueLabel: '待安排',
        subject: '语文',
      ),
    ]);

    await tester.pumpWidget(app(data));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('我的学生'));
    await tester.pumpAndSettle();

    expect(find.text('不太会'), findsOneWidget);
    expect(find.text('还行，但独立完成时不稳定'), findsOneWidget);
  });

  testWidgets('student detail shows three priorities before expanding all', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final data = dataWith([
      for (var index = 1; index <= 4; index++)
        V2FocusItem(
          id: 'case-$index',
          studentId: 'student-1',
          title: '当前问题 $index',
          summary: '补充说明 $index',
          nextStep: '跟进 $index',
          dueLabel: '待安排',
          subject: '语文',
        ),
    ]);

    await tester.pumpWidget(app(data));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('我的学生'));
    await tester.pumpAndSettle();

    expect(find.text('现在最重要'), findsOneWidget);
    expect(find.text('当前问题 1'), findsOneWidget);
    expect(find.text('当前问题 2'), findsOneWidget);
    expect(find.text('当前问题 3'), findsOneWidget);
    expect(find.text('当前问题 4'), findsNothing);
    expect(find.text('查看全部 4 个'), findsOneWidget);

    await tester.tap(find.text('查看全部 4 个'));
    await tester.pumpAndSettle();

    expect(find.text('全部问题'), findsOneWidget);
    expect(find.text('当前问题 4'), findsOneWidget);
    expect(find.text('只看重点'), findsOneWidget);

    await tester.tap(find.text('只看重点'));
    await tester.pumpAndSettle();
    expect(find.text('当前问题 4'), findsNothing);
    expect(find.text('现在最重要'), findsOneWidget);
  });

  testWidgets(
    'compact student detail keeps one identity row and only actionable primary controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(app(dataWith(const [])));
      await tester.pumpAndSettle();
      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      navigation.onDestinationSelected!(1);
      await tester.pumpAndSettle();
      await tester.tap(find.text('测试学生').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('v2-student-detail-context-row')),
        findsOneWidget,
      );
      expect(find.text('学生 · 测试学生'), findsNothing);
      expect(find.widgetWithText(FilledButton, '记录问题'), findsOneWidget);
      expect(find.text('记进展'), findsNothing);
      expect(find.byTooltip('返回学生列表'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'student detail promotes progress only when there is an active case and case context stays compact',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final data = dataWith(const [
        V2FocusItem(
          id: 'active-case',
          studentId: 'student-1',
          title: '阅读概括遗漏要点',
          summary: '概括题容易漏掉条件',
          nextStep: '再做一组概括题',
          dueLabel: '今天',
          subject: '语文',
        ),
      ]);

      await tester.pumpWidget(app(data));
      await tester.pumpAndSettle();
      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      navigation.onDestinationSelected!(1);
      await tester.pumpAndSettle();
      await tester.tap(find.text('测试学生').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, '记进展'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '记录问题'), findsOneWidget);

      await tester.tap(find.text('阅读概括遗漏要点'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-case-context-row')), findsOneWidget);
      expect(find.byTooltip('返回'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
