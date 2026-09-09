import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/organization_management_repository.dart';
import 'package:xueqing/features/organization_management/presentation/organization_student_record_export_dialog.dart';

void main() {
  testWidgets('selects a student, then allows one subject to be excluded', (
    tester,
  ) async {
    OrganizationStudentRecordExportSelection? selection;
    final student = OrganizationStudentRecord(
      studentId: 'student-1',
      studentName: '林同学',
      studentCode: 'S001',
      status: 'active',
      version: 1,
      grade: '初三',
      className: null,
      campus: null,
      startsOn: null,
      endsOn: null,
      subjectNames: const ['语文', '数学'],
      subjectServices: const [
        OrganizationStudentSubjectService(
          profileId: 'profile-chinese',
          organizationSubjectId: 'subject-chinese',
          subjectName: '语文',
          status: 'active',
          version: 1,
        ),
        OrganizationStudentSubjectService(
          profileId: 'profile-math',
          organizationSubjectId: 'subject-math',
          subjectName: '数学',
          status: 'active',
          version: 1,
        ),
        OrganizationStudentSubjectService(
          profileId: 'profile-history',
          organizationSubjectId: 'subject-history',
          subjectName: '历史学科',
          status: 'inactive',
          version: 2,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                selection =
                    await showDialog<OrganizationStudentRecordExportSelection>(
                      context: context,
                      builder: (context) =>
                          OrganizationStudentRecordExportDialog(
                            students: [student],
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

    expect(find.text('语文'), findsOneWidget);
    expect(find.text('数学'), findsOneWidget);
    expect(find.text('历史学科'), findsNothing);

    await tester.tap(
      find.byKey(const Key('student-record-export-student-student-1')),
    );
    await tester.pump();
    expect(find.text('已选 1 名学生 · 2 个学科'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('student-record-export-profile-profile-math')),
    );
    await tester.pump();
    expect(find.text('已选 1 名学生 · 1 个学科'), findsOneWidget);

    await tester.tap(find.byKey(const Key('student-record-export-confirm')));
    await tester.pumpAndSettle();

    expect(selection, isNotNull);
    expect(selection!.studentCount, 1);
    expect(selection!.profiles, hasLength(1));
    expect(selection!.profiles.single.profileId, 'profile-chinese');
    expect(selection!.profiles.single.subjectName, '语文');
  });
}
