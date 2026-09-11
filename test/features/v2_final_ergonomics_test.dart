import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_fixture.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_data.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

const _students = <V2Student>[
  V2Student(
    id: 's1',
    name: '林同学',
    grade: '初三',
    subjects: ['语文'],
    openCaseCount: 3,
    updatedLabel: '今天',
    teacherSummary: '',
  ),
  V2Student(
    id: 's2',
    name: '王同学',
    grade: '初二',
    subjects: ['英语'],
    openCaseCount: 1,
    updatedLabel: '今天',
    teacherSummary: '',
  ),
];

V2FocusItem _item(
  String id,
  String title,
  V2ActionTiming? timing, {
  DateTime? dueOn,
  String dueLabel = '待安排',
}) => V2FocusItem(
  id: id,
  studentId: 's1',
  title: title,
  summary: '测试摘要',
  nextStep: '下一步',
  dueLabel: dueLabel,
  subject: '语文',
  actionTiming: timing,
  dueOn: dueOn,
);

Widget _app(V2WorkspaceData data, {VoidCallback? onSignOut}) => MaterialApp(
  theme: V2Theme.light(),
  home: V2WorkspacePreview(data: data, onSignOut: onSignOut),
);

void main() {
  testWidgets('Today orders overdue before today before undated', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final data = V2WorkspaceData(
      students: _students,
      focusItems: <V2FocusItem>[
        _item('undated', '待安排问题', V2ActionTiming.undated),
        _item(
          'today',
          '今天问题',
          V2ActionTiming.today,
          dueOn: DateTime(2026, 9, 10),
          dueLabel: '9 月 10 日',
        ),
        _item(
          'overdue',
          '逾期问题',
          V2ActionTiming.overdue,
          dueOn: DateTime(2026, 9, 8),
          dueLabel: '9 月 8 日',
        ),
      ],
      timeline: const [],
      businessDate: DateTime(2026, 9, 10),
    );

    await tester.pumpWidget(_app(data));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('今日'));
    await tester.pumpAndSettle();

    final overdueY = tester.getTopLeft(find.text('逾期问题')).dy;
    final todayY = tester.getTopLeft(find.text('今天问题')).dy;
    final undatedY = tester.getTopLeft(find.text('待安排问题')).dy;
    expect(overdueY, lessThan(todayY));
    expect(todayY, lessThan(undatedY));
    expect(find.text('已逾期 · 9 月 8 日'), findsOneWidget);
  });

  testWidgets('Today keeps actionless cases out of the task list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const unplanned = V2FocusItem(
      id: 'unplanned',
      studentId: 's1',
      title: '还没有安排下一步的问题',
      summary: '已经发现问题，但尚未形成后续行动。',
      nextStep: '待安排下一步',
      dueLabel: '待安排',
      subject: '语文',
    );
    const data = V2WorkspaceData(
      students: _students,
      focusItems: <V2FocusItem>[unplanned],
      timeline: [],
    );

    await tester.pumpWidget(_app(data));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('今日'));
    await tester.pumpAndSettle();

    expect(find.text('还没有安排下一步的问题'), findsNothing);
    expect(find.text('待安排下一步'), findsNothing);
    expect(find.text('今天暂时没有需要处理的提醒'), findsOneWidget);
  });

  testWidgets(
    'Today keeps actionless verification cases out of the task list',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const verification = V2FocusItem(
        id: 'verification-no-action',
        studentId: 's1',
        title: '等待稳定性复查的问题',
        summary: '本轮处理已经完成，等待复查是否稳定。',
        nextStep: '待安排下一步',
        dueLabel: '待安排',
        subject: '语文',
        pendingVerification: true,
      );
      const data = V2WorkspaceData(
        students: _students,
        focusItems: <V2FocusItem>[verification],
        timeline: [],
      );

      await tester.pumpWidget(_app(data));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('今日'));
      await tester.pumpAndSettle();

      expect(find.text('等待稳定性复查的问题'), findsNothing);
      expect(find.text('待验证'), findsNothing);
      expect(find.text('今天暂时没有需要处理的提醒'), findsOneWidget);
    },
  );

  testWidgets('quick capture student picker searches name grade and subject', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const data = V2WorkspaceData(
      students: _students,
      focusItems: [],
      timeline: [],
    );

    await tester.pumpWidget(_app(data));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-today-quick-capture')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('v2-quick-capture-student-search')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('v2-quick-capture-student-search')),
      '初二',
    );
    await tester.pump();

    expect(find.text('找到 1 位'), findsOneWidget);
    expect(find.text('王同学'), findsOneWidget);
    expect(find.text('林同学'), findsNothing);
  });

  testWidgets(
    'compact shell keeps three primary destinations and moves More to header',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const data = V2WorkspaceData(
        students: _students,
        focusItems: [],
        timeline: [],
      );

      await tester.pumpWidget(_app(data, onSignOut: () {}));
      await tester.pumpAndSettle();

      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigation.destinations.length, 3);
      expect(find.text('更多'), findsNothing);
      expect(find.byKey(const Key('v2-compact-more')), findsOneWidget);

      await tester.tap(find.byKey(const Key('v2-compact-more')));
      await tester.pumpAndSettle();
      expect(find.text('操作指南'), findsOneWidget);
      expect(find.text('退出登录'), findsOneWidget);
    },
  );

  testWidgets(
    'operation guide stays reachable without optional account actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const data = V2WorkspaceData(
        students: _students,
        focusItems: [],
        timeline: [],
      );

      await tester.pumpWidget(_app(data));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('v2-compact-more')), findsOneWidget);
      await tester.tap(find.byKey(const Key('v2-compact-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-menu-operation-guide')), findsOneWidget);

      await tester.tap(find.byKey(const Key('v2-menu-operation-guide')));
      await tester.pumpAndSettle();
      expect(find.text('操作指南'), findsOneWidget);
      expect(find.text('先看今日'), findsOneWidget);
      expect(find.text('记录问题'), findsWidgets);
      expect(find.text('继续跟进'), findsOneWidget);
      expect(find.text('历史与复发'), findsOneWidget);
      expect(find.text('管理与导出'), findsOneWidget);
      expect(find.text('刷新与更新'), findsOneWidget);
      expect(find.text('记录事实 → 跟进 → 验证 → 下一步'), findsOneWidget);
    },
  );
}
