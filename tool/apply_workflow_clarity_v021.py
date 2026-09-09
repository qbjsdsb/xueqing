from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


def replace_count(text: str, old: str, new: str, expected: int, label: str) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"{label}: expected {expected} matches, found {count}")
    return text.replace(old, new)


teacher_path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
teacher = teacher_path.read_text()

teacher = replace_once(
    teacher,
    "ValueKey<String>(\n                'quick-capture-student-option-${student.id}',\n              )",
    "ValueKey<String>(\n                'quick-capture-student-option-${student.profileId}',\n              )",
    'quick capture profile key',
)

teacher = replace_once(
    teacher,
    "count: '${students.length} 人',",
    "count: '${students.map((student) => student.id).toSet().length} 人',",
    'distinct student count',
)

teacher = replace_once(
    teacher,
    "final recentStudents = _studentsByRecentActivity(workspace.students);",
    "final recentStudents = _dedupeStudentsById(\n      _studentsByRecentActivity(workspace.students),\n    );",
    'recent student dedupe',
)

helper_anchor = "List<NavigationDestination> _workspaceDestinations({"
helper = """List<WorkspaceStudent> _dedupeStudentsById(
  Iterable<WorkspaceStudent> students,
) {
  final seen = <String>{};
  return <WorkspaceStudent>[
    for (final student in students)
      if (seen.add(student.id)) student,
  ];
}

"""
if helper in teacher:
    raise SystemExit('dedupe helper already exists unexpectedly')
teacher = replace_once(
    teacher,
    helper_anchor,
    helper + helper_anchor,
    'dedupe helper anchor',
)

problem_type_block = """                if (workspace.canManageCaseTypes &&
                    workspace.organizationId != null)
                  OutlinedButton.icon(
                    onPressed: _showCaseTypeManager,
                    icon: Icon(Icons.category_outlined),
                    label: const Text('问题类型'),
                  ),
"""
teacher = replace_once(
    teacher,
    problem_type_block,
    '',
    'remove management control from student page',
)

teacher = replace_once(
    teacher,
    "title: const Text('关闭 Case？'),",
    "title: const Text('结束跟进？'),",
    'close case title',
)
teacher = replace_once(
    teacher,
    "content: const Text('关闭后不再列入当前待跟进事项，但历史记录会保留。'),",
    "content: const Text('结束后不会再列入当前待跟进事项，但学生的历史记录会完整保留。'),",
    'close case message',
)
teacher = replace_once(
    teacher,
    "child: const Text('关闭'),\n          ),\n        ],\n      ),\n    );\n    if (!mounted || shouldClose != true)",
    "child: const Text('结束跟进'),\n          ),\n        ],\n      ),\n    );\n    if (!mounted || shouldClose != true)",
    'close case confirm label',
)

teacher = replace_count(
    teacher,
    "title: const Text('机构管理'),",
    "title: const Text('学情闭环'),",
    1,
    'management-only mobile app bar',
)
teacher = replace_count(
    teacher,
    "title: Text(hasTeachingAccess ? '教师工作台' : '机构管理'),",
    "title: const Text('学情闭环'),",
    1,
    'compact app bar branding',
)

teacher_path.write_text(teacher)

layout_path = Path('lib/features/organization_management/presentation/organization_management_layout.dart')
layout = layout_path.read_text()
count = layout.count("'学科设置'")
if count != 2:
    raise SystemExit(f"management area label: expected 2 matches, found {count}")
layout = layout.replace("'学科设置'", "'设置'")
layout_path.write_text(layout)

rows_path = Path('lib/features/organization_management/presentation/organization_management_rows.dart')
rows = rows_path.read_text()
rows = replace_once(
    rows,
    "'首次接管有效期至 ${_formatDateTime(member.onboardingExpiresAt)}'",
    "'首次登录设置有效期至 ${_formatDateTime(member.onboardingExpiresAt)}'",
    'member onboarding wording',
)
rows_path.write_text(rows)

contract_path = Path('test/features/workflow_clarity_contract_test.dart')
contract_path.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher workflow keeps multi-subject student identity honest', () {
    final source = File(
      'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("'quick-capture-student-option-${student.profileId}'"),
    );
    expect(
      source,
      isNot(contains("'quick-capture-student-option-${student.id}'")),
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
    final studentPageEnd = source.indexOf('Widget _buildStudentDetail(', studentPageStart);
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
""")
