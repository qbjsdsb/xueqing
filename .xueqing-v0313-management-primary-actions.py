from pathlib import Path

areas = Path('lib/features/organization_management/presentation/organization_management_areas.dart')
text = areas.read_text(encoding='utf-8')

# People: when the setup banner already owns the current setup action, remove
# duplicate strong section actions. Keep invitation available as a secondary
# text action only when the current setup step is teacher-scope configuration.
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

# Students: when the setup banner says "add the first student", do not repeat a
# second add-student button in the section header.
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

# Settings: the setup banner is the sole strong "add subject" action during
# initial setup. Once setup is complete, adding another subject remains a quiet
# secondary action.
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

# Add behavior-level widget coverage to the existing management test harness.
test = Path('test/features/organization_management_test.dart')
source = test.read_text(encoding='utf-8')
anchor = """  testWidgets(\n    'owner can approve a nomination and admin cannot invite members',\n"""
if anchor not in source:
    raise SystemExit('test insertion anchor not found')
new_tests = r'''  testWidgets(
    'initial setup exposes one direct primary action instead of duplicates',
    (tester) async {
      final noSubjectRepository = _FakeOrganizationManagementRepository(
        members: const [],
        invitations: const [],
        setupOptions: const OrganizationSetupOptions(
          subjects: [],
          teachers: [],
        ),
      );
      await _pumpManagement(tester, noSubjectRepository);

      expect(find.byKey(const Key('management-next-step-action')), findsOneWidget);
      expect(find.text('先添加机构学科'), findsOneWidget);
      expect(find.text('添加学科'), findsOneWidget);

      final noTeacherRepository = _FakeOrganizationManagementRepository(
        members: const [],
        invitations: const [],
        setupOptions: const OrganizationSetupOptions(
          subjects: [
            OrganizationSetupSubject(id: 'subject-1', displayName: '数学'),
          ],
          teachers: [],
        ),
      );
      await _pumpManagement(tester, noTeacherRepository);

      expect(find.byKey(const Key('management-next-step-action')), findsOneWidget);
      expect(find.text('下一步：加入一位老师'), findsOneWidget);
      expect(find.text('邀请老师'), findsOneWidget);
      expect(find.text('邀请成员'), findsNothing);
    },
  );

  testWidgets(
    'teacher-scope setup keeps invitation secondary and removes duplicate config action',
    (tester) async {
      final repository = _FakeOrganizationManagementRepository(
        members: [
          _member(
            name: '示例老师',
            email: 'teacher@example.com',
            roles: ['teacher'],
          ),
        ],
        invitations: const [],
        setupOptions: const OrganizationSetupOptions(
          subjects: [
            OrganizationSetupSubject(id: 'subject-1', displayName: '数学'),
          ],
          teachers: [
            OrganizationSetupTeacher(
              membershipId: 'membership-1',
              displayName: '示例老师',
              email: 'teacher@example.com',
              organizationSubjectIds: [],
            ),
          ],
        ),
      );
      await _pumpManagement(tester, repository);

      expect(find.byKey(const Key('management-next-step-action')), findsOneWidget);
      expect(find.text('下一步：配置老师可教学科'), findsOneWidget);
      expect(find.text('配置老师学科'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '邀请成员'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '邀请成员'), findsNothing);
      expect(find.widgetWithText(TextButton, '配置'), findsNothing);
    },
  );

  testWidgets(
    'first-student setup does not repeat add-student action in section header',
    (tester) async {
      final repository = _FakeOrganizationManagementRepository(
        members: const [],
        invitations: const [],
      );
      await _pumpManagement(tester, repository);

      expect(find.byKey(const Key('management-next-step-action')), findsOneWidget);
      expect(find.text('准备完成，可以添加第一位学生'), findsOneWidget);
      expect(find.text('添加第一位学生'), findsOneWidget);
      expect(find.text('添加学生'), findsNothing);
    },
  );

'''
source = source.replace(anchor, new_tests + anchor, 1)
test.write_text(source, encoding='utf-8')
