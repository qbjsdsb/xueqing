from pathlib import Path

areas = Path('lib/features/organization_management/presentation/organization_management_areas.dart')
text = areas.read_text(encoding='utf-8')

old = """  Widget _buildPeopleArea({\n    required List<OrganizationTeacherSubjectScope> activeScopes,\n    required List<OrganizationTeacherSubjectScope> endedScopes,\n    required Set<String> latestEndedScopeIds,\n  }) {\n    final activeScopeGroups = _groupTeacherSubjectScopes(activeScopes);\n    return _ManagementAreaCard(\n"""
new = """  Widget _buildPeopleArea({\n    required List<OrganizationTeacherSubjectScope> activeScopes,\n    required List<OrganizationTeacherSubjectScope> endedScopes,\n    required Set<String> latestEndedScopeIds,\n  }) {\n    final activeScopeGroups = _groupTeacherSubjectScopes(activeScopes);\n    final setupIsPeople =\n        _setupNextStepArea() == OrganizationManagementArea.people;\n    final setupNeedsInvitation =\n        setupIsPeople && widget.snapshot.setupOptions.teachers.isEmpty;\n    return _ManagementAreaCard(\n"""
if old not in text:
    raise SystemExit('people area head anchor not found')
text = text.replace(old, new, 1)

old = """            action: widget.canInvite\n                ? FilledButton.tonalIcon(\n                    onPressed: widget.busy ? null : widget.onInviteMember,\n                    icon: const Icon(Icons.group_add_outlined, size: 18),\n                    label: const Text('邀请成员'),\n                  )\n                : null,\n"""
new = """            action: !widget.canInvite || setupNeedsInvitation\n                ? null\n                : setupIsPeople\n                ? TextButton.icon(\n                    onPressed: widget.busy ? null : widget.onInviteMember,\n                    icon: const Icon(Icons.group_add_outlined, size: 18),\n                    label: const Text('邀请成员'),\n                  )\n                : FilledButton.tonalIcon(\n                    onPressed: widget.busy ? null : widget.onInviteMember,\n                    icon: const Icon(Icons.group_add_outlined, size: 18),\n                    label: const Text('邀请成员'),\n                  ),\n"""
if old not in text:
    raise SystemExit('people invite action anchor not found')
text = text.replace(old, new, 1)

old = """            action: TextButton.icon(\n              onPressed: widget.busy ? null : widget.onAddTeacherScope,\n              icon: const Icon(Icons.add, size: 18),\n              label: const Text('配置'),\n            ),\n"""
new = """            action: setupIsPeople\n                ? null\n                : TextButton.icon(\n                    onPressed: widget.busy ? null : widget.onAddTeacherScope,\n                    icon: const Icon(Icons.add, size: 18),\n                    label: const Text('配置'),\n                  ),\n"""
if old not in text:
    raise SystemExit('teacher scope action anchor not found')
text = text.replace(old, new, 1)

old = """  Widget _buildStudentsArea({\n    required List<OrganizationStudentTeacherAssignment> activeAssignments,\n    required List<OrganizationStudentTeacherAssignment> endedAssignments,\n  }) {\n    final normalizedQuery = _studentQuery.trim().toLowerCase();\n"""
new = """  Widget _buildStudentsArea({\n    required List<OrganizationStudentTeacherAssignment> activeAssignments,\n    required List<OrganizationStudentTeacherAssignment> endedAssignments,\n  }) {\n    final setupIsStudents =\n        _setupNextStepArea() == OrganizationManagementArea.students;\n    final normalizedQuery = _studentQuery.trim().toLowerCase();\n"""
if old not in text:
    raise SystemExit('students area head anchor not found')
text = text.replace(old, new, 1)

old = """            action: FilledButton.icon(\n              onPressed: widget.busy ? null : widget.onAddStudent,\n              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),\n              label: const Text('添加学生'),\n            ),\n"""
new = """            action: setupIsStudents\n                ? null\n                : FilledButton.icon(\n                    onPressed: widget.busy ? null : widget.onAddStudent,\n                    icon: const Icon(\n                      Icons.person_add_alt_1_outlined,\n                      size: 18,\n                    ),\n                    label: const Text('添加学生'),\n                  ),\n"""
if old not in text:
    raise SystemExit('student add action anchor not found')
text = text.replace(old, new, 1)

old = """  Widget _buildSettingsArea() {\n    final noSubjects = widget.snapshot.setupOptions.subjects.isEmpty;\n    return _ManagementAreaCard(\n"""
new = """  Widget _buildSettingsArea() {\n    final noSubjects = widget.snapshot.setupOptions.subjects.isEmpty;\n    final setupIsSettings =\n        _setupNextStepArea() == OrganizationManagementArea.settings;\n    return _ManagementAreaCard(\n"""
if old not in text:
    raise SystemExit('settings area head anchor not found')
text = text.replace(old, new, 1)

old = """            action: noSubjects\n                ? FilledButton.tonalIcon(\n                    onPressed: widget.busy ? null : widget.onAddSubject,\n                    icon: const Icon(Icons.add, size: 18),\n                    label: const Text('添加学科'),\n                  )\n                : TextButton.icon(\n                    onPressed: widget.busy ? null : widget.onAddSubject,\n                    icon: const Icon(Icons.add, size: 18),\n                    label: const Text('添加学科'),\n                  ),\n"""
new = """            action: setupIsSettings\n                ? null\n                : TextButton.icon(\n                    onPressed: widget.busy ? null : widget.onAddSubject,\n                    icon: const Icon(Icons.add, size: 18),\n                    label: const Text('添加学科'),\n                  ),\n"""
if old not in text:
    raise SystemExit('settings subject action anchor not found')
text = text.replace(old, new, 1)
areas.write_text(text, encoding='utf-8')

test = Path('test/features/organization_management_test.dart')
source = test.read_text(encoding='utf-8')

# First-student flows now use the single contextual setup action rather than a
# duplicate section-header button.
source = source.replace(
    "await tester.tap(find.widgetWithText(FilledButton, '添加学生'));",
    "await tester.tap(find.byKey(const Key('management-next-step-action')));",
    2,
)
source = source.replace(
    "final addStudent = find.widgetWithText(FilledButton, '添加学生');\n    await tester.ensureVisible(addStudent);\n    final addStudentButton = tester.widget<FilledButton>(addStudent);",
    "final addStudent = find.byKey(const Key('management-next-step-action'));\n    await tester.ensureVisible(addStudent);\n    final addStudentButton = tester.widget<FilledButton>(addStudent);",
    1,
)

# Existing behavior tests become the regression lock for one primary action.
source = source.replace(
    "expect(find.text('添加学科'), findsWidgets);\n    expect(find.text('机构成员'), findsNothing);",
    "expect(find.text('添加学科'), findsOneWidget);\n    expect(find.text('机构成员'), findsNothing);",
    1,
)
source = source.replace(
    "expect(find.widgetWithText(FilledButton, '配置老师学科'), findsOneWidget);\n    expect(find.text('基础设置'), findsNothing);",
    "expect(find.widgetWithText(FilledButton, '配置老师学科'), findsOneWidget);\n    expect(find.widgetWithText(TextButton, '邀请成员'), findsOneWidget);\n    expect(find.widgetWithText(FilledButton, '邀请成员'), findsNothing);\n    expect(find.widgetWithText(TextButton, '配置'), findsNothing);\n    expect(find.text('基础设置'), findsNothing);",
    1,
)

# Assert the first-student section does not expose a second direct action.
needle = """    await _pumpManagement(tester, repository);\n\n    await tester.tap(find.byKey(const Key('management-next-step-action')));\n"""
replacement = """    await _pumpManagement(tester, repository);\n\n    expect(find.text('添加第一位学生'), findsOneWidget);\n    expect(find.text('添加学生'), findsNothing);\n    await tester.tap(find.byKey(const Key('management-next-step-action')));\n"""
if source.count(needle) < 1:
    raise SystemExit('student setup test anchor not found')
source = source.replace(needle, replacement, 1)

test.write_text(source, encoding='utf-8')
