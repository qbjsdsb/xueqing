from pathlib import Path


def once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


rows_path = Path('lib/features/organization_management/presentation/organization_management_rows.dart')
rows = rows_path.read_text()
rows = once(
    rows,
    '''  OrganizationStudentTeacherAssignment? _assignmentFor(
    OrganizationStudentSubjectService service,
  ) {
    for (final assignment in activeAssignments) {
      if (assignment.isActive &&
          assignment.studentSubjectProfileId == service.profileId) {
        return assignment;
      }
    }
    return null;
  }
''',
    '''  List<OrganizationStudentTeacherAssignment> _assignmentsFor(
    OrganizationStudentSubjectService service,
  ) {
    final matches = activeAssignments
        .where(
          (assignment) =>
              assignment.isActive &&
              assignment.studentSubjectProfileId == service.profileId,
        )
        .toList(growable: false);
    matches.sort((a, b) {
      final aOrder = a.assignmentRole == 'lead' ? 0 : 1;
      final bOrder = b.assignmentRole == 'lead' ? 0 : 1;
      final roleOrder = aOrder.compareTo(bOrder);
      if (roleOrder != 0) return roleOrder;
      return a.teacherName.compareTo(b.teacherName);
    });
    return matches;
  }
''',
    'assignment grouping helper',
)
rows = once(
    rows,
    '                    assignment: _assignmentFor(service),\n',
    '                    assignments: _assignmentsFor(service),\n',
    'student subject assignments argument',
)
rows = once(
    rows,
    '''  const _StudentSubjectServiceRow({
    required this.service,
    required this.assignment,
    required this.busy,
    required this.onTransfer,
    required this.onToggle,
  });

  final OrganizationStudentSubjectService service;
  final OrganizationStudentTeacherAssignment? assignment;
''',
    '''  const _StudentSubjectServiceRow({
    required this.service,
    required this.assignments,
    required this.busy,
    required this.onTransfer,
    required this.onToggle,
  });

  final OrganizationStudentSubjectService service;
  final List<OrganizationStudentTeacherAssignment> assignments;
''',
    'student subject assignment list field',
)
rows = once(
    rows,
    '''  @override
  Widget build(BuildContext context) {
    final currentAssignment = assignment;
    return Padding(
''',
    '''  @override
  Widget build(BuildContext context) {
    return Padding(
''',
    'remove single current assignment local',
)
rows = once(
    rows,
    '''          if (service.isActive) ...[
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                Icon(
                  Icons.person_pin_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                Text(
                  currentAssignment == null
                      ? '暂未安排负责老师'
                      : '${_studentAssignmentRoleLabel(currentAssignment.assignmentRole)}：${currentAssignment.teacherName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (currentAssignment != null)
                  TextButton(
                    key: ValueKey<String>(
                      'student-assignment-transfer-${currentAssignment.assignmentId}',
                    ),
                    onPressed: busy
                        ? null
                        : () => onTransfer(currentAssignment),
                    child: const Text('交接老师'),
                  ),
              ],
            ),
          ],
''',
    '''          if (service.isActive) ...[
            const SizedBox(height: AppSpacing.xxs),
            if (assignments.isEmpty)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                children: [
                  Icon(
                    Icons.person_pin_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  Text(
                    '暂未安排负责老师',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )
            else
              for (final assignment in assignments)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    Icon(
                      Icons.person_pin_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    Text(
                      '${_studentAssignmentRoleLabel(assignment.assignmentRole)}：${assignment.teacherName}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(
                      key: ValueKey<String>(
                        'student-assignment-transfer-${assignment.assignmentId}',
                      ),
                      onPressed: busy ? null : () => onTransfer(assignment),
                      child: const Text('交接老师'),
                    ),
                  ],
                ),
          ],
''',
    'render every active assignment',
)
rows_path.write_text(rows)


test_path = Path('test/features/organization_management_test.dart')
test = test_path.read_text()
anchor = "  testWidgets('missing subjects opens settings first', (tester) async {\n"
new_test = r'''  testWidgets('student subject shows lead and collaborator together', (
    tester,
  ) async {
    final lead = _studentTeacherAssignment();
    final collaborator = OrganizationStudentTeacherAssignment(
      assignmentId: 'assignment-2',
      organizationId: 'org-1',
      studentSubjectProfileId: 'profile-1',
      studentId: 'student-1',
      studentName: '原学生',
      organizationSubjectId: 'subject-1',
      subjectName: '数学',
      subjectCode: 'math',
      membershipId: 'membership-2',
      teacherName: '协作老师',
      teacherEmail: 'collaborator@example.com',
      assignmentRole: 'collaborator',
      status: 'active',
      version: 1,
      activeFrom: DateTime(2026, 9, 1),
      activeTo: null,
      endedAt: null,
    );
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
      students: [_studentRecord()],
      studentTeacherAssignments: [collaborator, lead],
      setupOptions: const OrganizationSetupOptions(
        subjects: [
          OrganizationSetupSubject(id: 'subject-1', displayName: '数学'),
        ],
        teachers: [
          OrganizationSetupTeacher(
            membershipId: 'membership-1',
            displayName: '原老师',
            email: 'old-teacher@example.com',
            organizationSubjectIds: ['subject-1'],
          ),
          OrganizationSetupTeacher(
            membershipId: 'membership-2',
            displayName: '协作老师',
            email: 'collaborator@example.com',
            organizationSubjectIds: ['subject-1'],
          ),
        ],
      ),
    );

    await _pumpManagement(tester, repository);
    await _selectManagementArea(tester, '学生');

    expect(find.text('主责老师：原老师'), findsOneWidget);
    expect(find.text('协作老师：协作老师'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('student-assignment-transfer-assignment-1'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('student-assignment-transfer-assignment-2'),
      ),
      findsOneWidget,
    );
  });

'''
test = once(test, anchor, new_test + anchor, 'multi-assignment widget test')
test_path.write_text(test)

contract_path = Path('test/features/management_workflow_clarity_contract_test.dart')
contract = contract_path.read_text()
contract = once(
    contract,
    "    expect(rows, contains(\"'暂未安排负责老师'\"));\n",
    "    expect(rows, contains(\"'暂未安排负责老师'\"));\n    expect(rows, contains('for (final assignment in assignments)'));\n",
    'multi-assignment source contract',
)
contract_path.write_text(contract)
