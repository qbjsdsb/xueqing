import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_fixture.dart';
import 'package:xueqing/features/design_v2/v2_workspace_data.dart';

void main() {
  const student = V2Student(
    id: 'student-1',
    name: '测试学生',
    grade: '初三',
    subjects: ['语文'],
    openCaseCount: 6,
    updatedLabel: '今天更新',
    teacherSummary: '王老师负责语文',
  );

  V2FocusItem item(
    String id, {
    String nextStep = '待安排下一步',
    DateTime? dueOn,
    V2ActionTiming? timing,
    V2CaseStatus? status,
  }) => V2FocusItem(
    id: id,
    studentId: student.id,
    title: id,
    summary: '',
    nextStep: nextStep,
    dueLabel: '待安排',
    subject: '语文',
    dueOn: dueOn,
    actionTiming: timing,
    caseStatus: status,
  );

  test(
    'student open cases follow deterministic teacher-attention priority',
    () {
      final data = V2WorkspaceData(
        students: const [student],
        focusItems: [
          item('other'),
          item('recent'),
          item('next', nextStep: '周五检查同类题'),
          item(
            'pending',
            dueOn: DateTime(2026, 9, 20),
            status: V2CaseStatus.pendingVerification,
          ),
          item('today', dueOn: DateTime(2026, 9, 15)),
          item('overdue', dueOn: DateTime(2026, 9, 14)),
        ],
        timeline: [
          V2TimelineEntry(
            caseId: 'recent',
            date: '昨天',
            kind: '新表现',
            body: '最近刚记录过。',
            teacher: '王老师',
            time: '18:00',
            occurredAt: DateTime(2026, 9, 14, 18),
          ),
        ],
        businessDate: DateTime(2026, 9, 15),
      );

      expect(
        data.focusItemsForStudent(student).map((entry) => entry.id).toList(),
        ['overdue', 'today', 'pending', 'next', 'recent', 'other'],
      );
    },
  );

  test(
    'explicit action timing wins and equal priorities preserve source order',
    () {
      final data = V2WorkspaceData(
        students: const [student],
        focusItems: [
          item('first', nextStep: '继续观察'),
          item('second', nextStep: '继续观察'),
          item(
            'explicit-overdue',
            nextStep: '继续观察',
            dueOn: DateTime(2026, 9, 30),
            timing: V2ActionTiming.overdue,
          ),
        ],
        timeline: const [],
        businessDate: DateTime(2026, 9, 15),
      );

      expect(
        data.focusItemsForStudent(student).map((entry) => entry.id).toList(),
        ['explicit-overdue', 'first', 'second'],
      );
    },
  );
}
