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
}
