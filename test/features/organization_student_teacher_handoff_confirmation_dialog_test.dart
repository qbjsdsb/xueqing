import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/organization_management_repository.dart';
import 'package:xueqing/features/organization_management/presentation/'
    'organization_student_teacher_handoff_confirmation_dialog.dart';

OrganizationTeachingHandoffPlan _plan() {
  return OrganizationTeachingHandoffPlan(
    organizationId: 'org-1',
    businessDate: DateTime(2026, 9, 12),
    studentSubjectProfileId: 'profile-1',
    studentId: 'student-1',
    studentName: '示例学生',
    organizationSubjectId: 'subject-1',
    subjectName: '语文',
    subjectCode: 'chinese',
    assignmentId: 'assignment-1',
    assignmentRole: 'lead',
    assignmentVersion: 3,
    sourceMembershipId: 'teacher-old',
    sourceTeacherName: '王老师',
    replacementMembershipId: 'teacher-new',
    replacementTeacherName: '李老师',
    replacementScopeId: 'scope-new',
    affectedCases: const [
      OrganizationTeachingHandoffCase(
        id: 'case-1',
        title: '作文立意容易偏题',
        status: 'intervening',
        version: 4,
        ownerMembershipId: 'teacher-old',
        movesOwner: true,
      ),
      OrganizationTeachingHandoffCase(
        id: 'case-2',
        title: '文言实词掌握不稳定',
        status: 'pending_verification',
        version: 2,
        ownerMembershipId: 'teacher-old',
        movesOwner: true,
      ),
    ],
    affectedActions: const [
      OrganizationTeachingHandoffAction(
        id: 'action-1',
        caseId: 'case-1',
        title: '周五复检作文立意',
        version: 2,
      ),
    ],
  );
}

void main() {
  testWidgets('shows the exact responsibility scope before confirmation', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (context) =>
                      OrganizationStudentTeacherHandoffConfirmationDialog(
                        plan: _plan(),
                      ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('确认教学责任交接'), findsOneWidget);
    expect(find.text('示例学生 · 语文'), findsOneWidget);
    expect(find.text('王老师 → 李老师'), findsOneWidget);
    expect(find.text('进行中问题'), findsOneWidget);
    expect(find.text('2 个'), findsOneWidget);
    expect(find.text('作文立意容易偏题'), findsOneWidget);
    expect(find.text('文言实词掌握不稳定'), findsOneWidget);
    expect(find.text('待完成行动'), findsOneWidget);
    expect(find.text('1 个'), findsOneWidget);
    expect(find.text('周五复检作文立意'), findsOneWidget);
    expect(
      find.text('历史证据、教学处理、检查结果和历史记录不会修改。交接只改变从现在开始由谁继续负责。'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('handoff-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('requires an explicit confirm action', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (context) =>
                      OrganizationStudentTeacherHandoffConfirmationDialog(
                        plan: _plan(),
                      ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(result, isNull);

    await tester.tap(find.byKey(const ValueKey('handoff-confirm-submit')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
