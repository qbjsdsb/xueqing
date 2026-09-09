import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher workflow keeps multi-subject student identity honest', () {
    final source = File(
      'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("'quick-capture-student-option-\${student.profileId}'"),
    );
    expect(
      source,
      isNot(contains("'quick-capture-student-option-\${student.id}'")),
    );
    expect(
      source,
      contains("students.map((student) => student.id).toSet().length"),
    );
    expect(source, contains('_dedupeStudentsById('));
  });

  test('teacher surfaces do not expose management-only or domain wording', () {
    final source = File(
      'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("title: const Text('关闭 Case？')")));
    expect(source, contains("title: const Text('结束跟进？')"));
    expect(source, contains("child: const Text('结束跟进')"));

    final studentPageStart = source.indexOf('Widget _buildStudents(');
    final studentPageEnd = source.indexOf(
      'Widget _buildStudentDetail(',
      studentPageStart,
    );
    expect(studentPageStart, greaterThanOrEqualTo(0));
    expect(studentPageEnd, greaterThan(studentPageStart));
    final studentPage = source.substring(studentPageStart, studentPageEnd);
    expect(studentPage, isNot(contains("label: const Text('问题类型')")));
  });

  test('management navigation uses plain-language settings', () {
    final layout = File(
      'lib/features/organization_management/presentation/organization_management_layout.dart',
    ).readAsStringSync();
    final rows = File(
      'lib/features/organization_management/presentation/organization_management_rows.dart',
    ).readAsStringSync();

    expect(layout, isNot(contains("'学科设置'")));
    expect(layout, contains("label: '设置'"));
    expect(rows, contains('首次登录设置有效期至'));
    expect(rows, isNot(contains('首次接管有效期至')));
  });
}
