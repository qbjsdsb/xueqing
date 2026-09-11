import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_composers.dart';
import 'package:xueqing/features/design_v2/v2_fixture.dart';
import 'package:xueqing/features/design_v2/v2_workspace_data.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  testWidgets('V2 workspace opens on Today by default', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: V2WorkspacePreview()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v2-today-quick-capture')), findsOneWidget);
    expect(find.byKey(const Key('v2-student-search')), findsNothing);
  });

  testWidgets('single active case skips the progress case picker', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const student = V2Student(
      id: 'student-one',
      name: '单同学',
      grade: '初二',
      subjects: <String>['语文'],
      openCaseCount: 1,
      updatedLabel: '暂无记录',
      teacherSummary: '',
    );
    const item = V2FocusItem(
      id: 'case-one',
      studentId: 'student-one',
      title: '概括题漏点',
      summary: '仍会漏掉结果信息。',
      nextStep: '继续观察',
      dueLabel: '待安排',
      subject: '语文',
      caseStatus: V2CaseStatus.intervening,
    );
    const data = V2WorkspaceData(
      students: <V2Student>[student],
      focusItems: <V2FocusItem>[item],
      timeline: <V2TimelineEntry>[],
    );

    await tester.pumpWidget(
      const MaterialApp(home: V2WorkspacePreview(data: data)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('学生'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('单同学'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('记进展'));
    await tester.pumpAndSettle();

    expect(find.text('选择要记录进展的问题'), findsNothing);
    expect(find.text('记录进展'), findsOneWidget);
  });

  test('student timeline merges cases by true occurrence time', () {
    const student = V2Student(
      id: 'student-timeline',
      name: '时序同学',
      grade: '初三',
      subjects: <String>['语文', '数学'],
      openCaseCount: 2,
      updatedLabel: '暂无记录',
      teacherSummary: '',
    );
    const chinese = V2FocusItem(
      id: 'case-chinese',
      studentId: 'student-timeline',
      title: '语文问题',
      summary: '',
      nextStep: '继续观察',
      dueLabel: '待安排',
      subject: '语文',
    );
    const math = V2FocusItem(
      id: 'case-math',
      studentId: 'student-timeline',
      title: '数学问题',
      summary: '',
      nextStep: '继续观察',
      dueLabel: '待安排',
      subject: '数学',
    );
    final data = V2WorkspaceData(
      students: const <V2Student>[student],
      focusItems: const <V2FocusItem>[chinese, math],
      timeline: <V2TimelineEntry>[
        V2TimelineEntry(
          caseId: chinese.id,
          date: '9 月 11 日',
          kind: '新表现',
          body: '最新',
          teacher: '',
          time: '10:00',
          occurredAt: DateTime(2026, 9, 11, 10),
        ),
        V2TimelineEntry(
          caseId: chinese.id,
          date: '9 月 2 日',
          kind: '建立跟进',
          body: '最早',
          teacher: '',
          time: '10:00',
          occurredAt: DateTime(2026, 9, 2, 10),
        ),
        V2TimelineEntry(
          caseId: math.id,
          date: '9 月 10 日',
          kind: '检查结果',
          body: '第二新',
          teacher: '',
          time: '10:00',
          occurredAt: DateTime(2026, 9, 10, 10),
        ),
        V2TimelineEntry(
          caseId: math.id,
          date: '9 月 8 日',
          kind: '教学处理',
          body: '第三新',
          teacher: '',
          time: '10:00',
          occurredAt: DateTime(2026, 9, 8, 10),
        ),
      ],
    );

    expect(
      data.timelineForStudent(student).map((entry) => entry.body),
      <String>['最新', '第二新', '第三新', '最早'],
    );
  });

  test('continue without a reminder is explicit in teacher wording', () {
    expect(V2NextStep.continueTracking.label, '继续观察，不设提醒');
  });
}
