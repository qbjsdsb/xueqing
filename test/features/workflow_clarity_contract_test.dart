import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher workflow keeps multi-subject student identity honest', () {
    final source = File(
      'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("'quick-capture-student-option-\${group.first.id}'"),
    );
    expect(
      source,
      contains("'quick-capture-subject-option-\${profile.profileId}'"),
    );
    expect(
      source,
      isNot(
        contains("'quick-capture-student-option-\${group.first.profileId}'"),
      ),
    );
    expect(
      source,
      isNot(contains("students.map((student) => student.id).toSet().length")),
    );
    expect(source, contains('_dedupeStudentsById('));
    expect(source, contains('_groupStudentsById('));
    expect(source, contains('_WorkspaceMultiSubjectStudentRow'));
    expect(source, contains("count: '\${studentGroups.length} 人'"));
  });

  test('teacher surfaces do not expose management-only or domain wording', () {
    final source = File(
      'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("title: const Text('关闭 Case？')")));
    expect(source, contains("title: const Text('结束跟进？')"));
    expect(source, contains("child: const Text('结束跟进')"));
    expect(source, isNot(contains('operation ID')));
    expect(source, isNot(contains('未提交到服务器')));
    expect(source, contains("labelText: '记录来源 *'"));
    expect(source, contains("labelText: '简要标题 *'"));
    expect(source, contains("labelText: '具体表现 *'"));
    expect(source, contains("? '保存并继续'"));

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
