import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/organization_management_repository.dart';
import 'package:xueqing/features/organization_management/presentation/organization_student_record_export_dialog.dart';

void main() {
  testWidgets('selects a student, then allows one subject to be excluded', (
    tester,
  ) async {
    OrganizationStudentRecordExportSelection? selection;
    final student = _studentFixture();

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

  testWidgets(
    'search keeps earlier selections and selects only visible results',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizationStudentRecordExportDialog(
              students: [_studentFixture(), _secondStudentFixture()],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('student-record-export-student-student-1')),
      );
      await tester.pump();
      expect(find.text('已选 1 名学生 · 2 个学科'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('student-record-export-search')),
        'S002',
      );
      await tester.pump();

      expect(find.text('林同学'), findsNothing);
      expect(find.text('张同学'), findsOneWidget);
      expect(find.text('全选当前结果'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('student-record-export-select-all')),
      );
      await tester.pump();

      expect(find.text('已选 2 名学生 · 4 个学科'), findsOneWidget);
    },
  );

  testWidgets('chooser stays usable on a narrow Android-sized window', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizationStudentRecordExportDialog(
            students: [_studentFixture()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('导出学生记录'), findsOneWidget);
    expect(
      find.byKey(const Key('student-record-export-select-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('student-record-export-clear')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

OrganizationStudentRecord _studentFixture() {
  return OrganizationStudentRecord(
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
}

OrganizationStudentRecord _secondStudentFixture() {
  return OrganizationStudentRecord(
    studentId: 'student-2',
    studentName: '张同学',
    studentCode: 'S002',
    status: 'active',
    version: 1,
    grade: '初二',
    className: null,
    campus: null,
    startsOn: null,
    endsOn: null,
    subjectNames: const ['语文', '英语'],
    subjectServices: const [
      OrganizationStudentSubjectService(
        profileId: 'profile-2-chinese',
        organizationSubjectId: 'subject-chinese',
        subjectName: '语文',
        status: 'active',
        version: 1,
      ),
      OrganizationStudentSubjectService(
        profileId: 'profile-2-english',
        organizationSubjectId: 'subject-english',
        subjectName: '英语',
        status: 'active',
        version: 1,
      ),
    ],
  );
}
