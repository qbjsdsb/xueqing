import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_fixture.dart';
import 'package:xueqing/features/design_v2/v2_workspace_data.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

Widget _app(V2WorkspaceData data, {double textScale = 1.0}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: V2WorkspacePreview(data: data, onSignOut: () {}),
);

void main() {
  testWidgets('compact Today stays readable with large Chinese text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const student = V2Student(
      id: 's-final',
      name: '一位名字比较长的同学',
      grade: '初三',
      subjects: <String>['语文'],
      openCaseCount: 1,
      updatedLabel: '今天',
      teacherSummary: '',
    );
    final item = V2FocusItem(
      id: 'case-overdue',
      studentId: student.id,
      title: '现代文阅读概括题仍然容易遗漏关键结果信息',
      summary: '测试',
      nextStep: '再次检查同类阅读概括题',
      dueLabel: '9 月 1 日',
      subject: '语文',
      actionTiming: V2ActionTiming.overdue,
      dueOn: DateTime(2026, 9, 1),
    );
    final data = V2WorkspaceData(
      students: const <V2Student>[student],
      focusItems: <V2FocusItem>[item],
      timeline: const <V2TimelineEntry>[],
      businessDate: DateTime(2026, 9, 12),
    );

    await tester.pumpWidget(_app(data, textScale: 1.35));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v2-today-quick-capture')), findsOneWidget);
    expect(find.byKey(const Key('v2-compact-more')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('v2-today-inline-status-case-overdue')),
      findsOneWidget,
    );
    expect(find.text('已逾期 · 9 月 1 日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing-case continuation stacks cleanly on narrow phones', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const student = V2Student(
      id: 's-existing',
      name: '林同学',
      grade: '初三',
      subjects: <String>['语文'],
      openCaseCount: 1,
      updatedLabel: '今天',
      teacherSummary: '',
    );
    const item = V2FocusItem(
      id: 'case-existing',
      studentId: 's-existing',
      title: '已有的阅读概括问题标题比较长用于窄屏测试',
      summary: '仍会遗漏结果信息。',
      nextStep: '再检查一篇同类阅读题',
      dueLabel: '待安排',
      subject: '语文',
      caseStatus: V2CaseStatus.intervening,
    );
    const data = V2WorkspaceData(
      students: <V2Student>[student],
      focusItems: <V2FocusItem>[item],
      timeline: <V2TimelineEntry>[],
    );

    await tester.pumpWidget(_app(data, textScale: 1.2));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-today-quick-capture')));
    await tester.pumpAndSettle();

    final body = find.byKey(const Key('v2-quick-capture-body'));
    await tester.enterText(body, '今天再次出现概括遗漏结果的情况。');
    await tester.pump();

    final title = find.text('已有的阅读概括问题标题比较长用于窄屏测试');
    final action = find.byKey(
      const ValueKey<String>('v2-quick-capture-existing-case-existing'),
    );
    expect(title, findsOneWidget);
    expect(action, findsOneWidget);
    expect(
      tester.getTopLeft(action).dy,
      greaterThan(tester.getBottomLeft(title).dy),
    );

    final scrollViews = tester.widgetList<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(
      scrollViews.any(
        (view) =>
            view.keyboardDismissBehavior ==
            ScrollViewKeyboardDismissBehavior.onDrag,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
