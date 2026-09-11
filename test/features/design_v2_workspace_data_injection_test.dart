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

  testWidgets('workspace renders injected data instead of global fixture', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(_injectedData));
    await tester.pumpAndSettle();

    expect(find.text('真实学生'), findsWidgets);
    expect(find.text('真实问题'), findsOneWidget);
    expect(find.text('林同学'), findsNothing);
    expect(find.text('全部 1'), findsOneWidget);
  });

  testWidgets('Today uses pending verification semantics from injected data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(_injectedData));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('今日'));
    await tester.pumpAndSettle();

    expect(find.text('现在要做'), findsOneWidget);
    expect(find.text('待验证'), findsNothing);
    expect(find.textContaining('继续关注'), findsOneWidget);
    expect(find.text('真实学生 · 语文'), findsOneWidget);

    await tester.tap(find.text('真实学生 · 语文'));
    await tester.pumpAndSettle();
    expect(find.text('成长过程'), findsOneWidget);
    expect(find.text('真实问题'), findsOneWidget);
  });

  testWidgets('Today hides actionless work and keeps future work secondary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final data = V2WorkspaceData(
      businessDate: DateTime(2026, 9, 12),
      students: _injectedData.students,
      focusItems: const [
        V2FocusItem(
          id: 'today-case',
          studentId: 'real-student',
          title: '今天处理',
          summary: '今天应该出现。',
          nextStep: '今天复查',
          dueLabel: '今天',
          subject: '语文',
          actionTiming: V2ActionTiming.today,
        ),
        V2FocusItem(
          id: 'future-case',
          studentId: 'real-student',
          title: '未来处理',
          summary: '未来事项不应该挤进今日。',
          nextStep: '下周复查',
          dueLabel: '9 月 20 日',
          subject: '语文',
          actionTiming: V2ActionTiming.future,
        ),
        V2FocusItem(
          id: 'fact-only-case',
          studentId: 'real-student',
          title: '仅记录事实',
          summary: '没有 Action 的开放问题仍需安排下一步。',
          nextStep: '待安排下一步',
          dueLabel: '待安排',
          subject: '语文',
        ),
      ],
      timeline: const [],
    );

    await tester.pumpWidget(app(data));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('今日'));
    await tester.pumpAndSettle();

    expect(find.text('9 月 12 日 · 周六'), findsOneWidget);
    expect(find.text('今天处理'), findsOneWidget);
    expect(find.text('待安排下一步'), findsNothing);
    expect(find.text('仅记录事实'), findsNothing);
    expect(find.text('之后'), findsOneWidget);
    expect(find.text('未来处理'), findsNothing);

    await tester.tap(find.text('之后'));
    await tester.pumpAndSettle();
    expect(find.text('未来处理'), findsOneWidget);
  });

  testWidgets('Today never silently drops the fifth current action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final items = <V2FocusItem>[
      for (var index = 1; index <= 6; index++)
        V2FocusItem(
          id: 'many-$index',
          studentId: 'real-student',
          title: '待处理事项 $index',
          summary: '用于验证 Today 不会静默截断。',
          nextStep: '完成第 $index 项',
          dueLabel: '今天',
          subject: '语文',
          actionTiming: V2ActionTiming.today,
        ),
    ];
    final data = V2WorkspaceData(
      businessDate: DateTime(2026, 9, 12),
      students: _injectedData.students,
      focusItems: items,
      timeline: const [],
    );

    await tester.pumpWidget(app(data));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('今日'));
    await tester.pumpAndSettle();

    expect(find.text('现在要做'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    for (var index = 1; index <= 6; index++) {
      expect(find.text('待处理事项 $index'), findsOneWidget);
    }
  });

  testWidgets('empty workspace is a first-class state on desktop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(_emptyData));
    await tester.pumpAndSettle();

    expect(find.text('暂时还没有可查看的学生'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty workspace is safe on compact layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(_emptyData));
    await tester.pumpAndSettle();

    expect(find.text('暂时还没有可查看的学生'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student without active Case keeps progress action disabled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(_studentWithoutCases));
    await tester.pumpAndSettle();

    expect(find.text('暂无进行中的问题'), findsOneWidget);
    final progressButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '记进展'),
    );
    expect(progressButton.onPressed, isNull);
  });

  testWidgets('closed history is visible but stays read-only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(_dataWithClosedHistory));
    await tester.pumpAndSettle();

    expect(find.text('历史问题'), findsOneWidget);
    expect(find.text('曾经的问题'), findsOneWidget);
    await tester.tap(find.text('曾经的问题'));
    await tester.pumpAndSettle();

    expect(find.text('跟进已结束'), findsOneWidget);
    expect(find.text('历史时间线内容。'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '记进展'), findsNothing);

    await tester.tap(find.byTooltip('学情'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(find.text('历史 1'), findsOneWidget);
    expect(find.text('曾经的问题'), findsOneWidget);
  });

  testWidgets('unknown historical author renders time without fake separator', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(_injectedData));
    await tester.pumpAndSettle();
    await tester.tap(find.text('真实问题'));
    await tester.pumpAndSettle();

    expect(find.text('18:31'), findsOneWidget);
    expect(find.text(' · 18:31'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _injectedData = V2WorkspaceData(
  students: [
    V2Student(
      id: 'real-student',
      name: '真实学生',
      grade: '初三',
      subjects: ['语文'],
      openCaseCount: 1,
      updatedLabel: '已有更新',
      teacherSummary: '当前工作区 · 语文',
    ),
  ],
  focusItems: [
    V2FocusItem(
      id: 'real-case',
      studentId: 'real-student',
      title: '真实问题',
      summary: '这是由注入数据提供的问题摘要。',
      nextStep: '下次课验证',
      dueLabel: '9 月 12 日',
      subject: '语文',
      actionTiming: V2ActionTiming.today,
      pendingVerification: true,
    ),
  ],
  timeline: [
    V2TimelineEntry(
      caseId: 'real-case',
      date: '今天',
      kind: '检查结果',
      body: '真实时间线内容。',
      teacher: '',
      time: '18:31',
    ),
  ],
);

const _dataWithClosedHistory = V2WorkspaceData(
  students: [
    V2Student(
      id: 'history-student',
      name: '历史学生',
      grade: '初三',
      subjects: ['语文'],
      openCaseCount: 1,
      updatedLabel: '已有更新',
      teacherSummary: '当前工作区 · 语文',
    ),
  ],
  focusItems: [
    V2FocusItem(
      id: 'active-case',
      studentId: 'history-student',
      title: '当前问题',
      summary: '还在跟进。',
      nextStep: '下次检查',
      dueLabel: '9 月 12 日',
      subject: '语文',
      actionTiming: V2ActionTiming.today,
    ),
  ],
  closedItems: [
    V2FocusItem(
      id: 'closed-case',
      studentId: 'history-student',
      title: '曾经的问题',
      summary: '已经结束跟进。',
      nextStep: '跟进已结束',
      dueLabel: '已结束',
      subject: '语文',
      closed: true,
    ),
  ],
  timeline: [
    V2TimelineEntry(
      caseId: 'closed-case',
      date: '8 月 28 日',
      kind: '结束跟进',
      body: '历史时间线内容。',
      teacher: '',
      time: '17:20',
    ),
  ],
);

const _emptyData = V2WorkspaceData(students: [], focusItems: [], timeline: []);

const _studentWithoutCases = V2WorkspaceData(
  students: [
    V2Student(
      id: 'quiet-student',
      name: '暂无问题学生',
      grade: '初一',
      subjects: ['数学'],
      openCaseCount: 0,
      updatedLabel: '暂无记录',
      teacherSummary: '当前工作区 · 数学',
    ),
  ],
  focusItems: [],
  timeline: [],
);
