from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text()
    if old not in text:
        raise SystemExit(f"marker not found in {path}: {old[:120]!r}")
    if text.count(old) != 1:
        raise SystemExit(f"marker not unique in {path}: {old[:120]!r}")
    file.write_text(text.replace(old, new, 1))


repo = "lib/cloud/organization_management_repository.dart"

lead_result = r'''class OrganizationStudentSubjectLeadResult {
  const OrganizationStudentSubjectLeadResult({
    required this.operationId,
    required this.organizationId,
    required this.studentId,
    required this.studentName,
    required this.studentSubjectProfileId,
    required this.organizationSubjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.assignmentId,
    required this.assignmentRole,
    required this.assignmentStatus,
    required this.assignmentVersion,
    required this.teacherMembershipId,
    required this.teacherDisplayName,
    required this.teacherEmail,
    required this.teacherScopeId,
    required this.activeFrom,
  });

  final String operationId;
  final String organizationId;
  final String studentId;
  final String studentName;
  final String studentSubjectProfileId;
  final String organizationSubjectId;
  final String subjectName;
  final String subjectCode;
  final String assignmentId;
  final String assignmentRole;
  final String assignmentStatus;
  final int assignmentVersion;
  final String teacherMembershipId;
  final String teacherDisplayName;
  final String teacherEmail;
  final String teacherScopeId;
  final DateTime? activeFrom;

  factory OrganizationStudentSubjectLeadResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationStudentSubjectLeadResult(
      operationId: _requiredString(json['operation_id'], 'operation_id'),
      organizationId: _requiredString(
        json['organization_id'],
        'organization_id',
      ),
      studentId: _requiredString(json['student_id'], 'student_id'),
      studentName: _stringValue(json['student_name']) ?? '未命名学生',
      studentSubjectProfileId: _requiredString(
        json['student_subject_profile_id'],
        'student_subject_profile_id',
      ),
      organizationSubjectId: _requiredString(
        json['organization_subject_id'],
        'organization_subject_id',
      ),
      subjectName: _stringValue(json['subject_name']) ?? '未命名学科',
      subjectCode: _stringValue(json['subject_code']) ?? '—',
      assignmentId: _requiredString(json['assignment_id'], 'assignment_id'),
      assignmentRole: _requiredString(
        json['assignment_role'],
        'assignment_role',
      ),
      assignmentStatus: _requiredString(
        json['assignment_status'],
        'assignment_status',
      ),
      assignmentVersion:
          _requiredPositiveInt(json['assignment_version'], 'assignment_version'),
      teacherMembershipId: _requiredString(
        json['teacher_membership_id'],
        'teacher_membership_id',
      ),
      teacherDisplayName:
          _stringValue(json['teacher_display_name']) ?? '未命名老师',
      teacherEmail: _stringValue(json['teacher_email']) ?? '',
      teacherScopeId: _requiredString(
        json['teacher_scope_id'],
        'teacher_scope_id',
      ),
      activeFrom: _dateTimeValue(json['active_from']),
    );
  }
}

'''
replace_once(
    repo,
    "class OrganizationTeachingHandoffCase {",
    lead_result + "class OrganizationTeachingHandoffCase {",
)

interface_marker = r'''  Future<List<OrganizationStudentTeacherAssignment>>
  listStudentTeacherAssignments({required String organizationId});

'''
interface_add = interface_marker + r'''  Future<OrganizationStudentSubjectLeadResult> setStudentSubjectLead({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
    required String teacherMembershipId,
  });

'''
replace_once(repo, interface_marker, interface_add)

impl_marker = r'''  @override
  Future<List<OrganizationStudentTeacherAssignment>>
  listStudentTeacherAssignments({required String organizationId}) async {
    final response = await _callRows(
      'list_organization_student_teacher_assignments',
      <String, dynamic>{'p_organization_id': organizationId},
    );
    return _mapList(response, OrganizationStudentTeacherAssignment.fromJson);
  }

'''
impl_add = impl_marker + r'''  @override
  Future<OrganizationStudentSubjectLeadResult> setStudentSubjectLead({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
    required String teacherMembershipId,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentSubjectProfileId.trim().isEmpty ||
        expectedProfileVersion <= 0 ||
        teacherMembershipId.trim().isEmpty) {
      throw ArgumentError('Student subject Lead assignment identity is invalid.');
    }
    final response = await _call(
      'set_organization_student_subject_lead',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_subject_profile_id': studentSubjectProfileId,
        'p_expected_profile_version': expectedProfileVersion,
        'p_teacher_membership_id': teacherMembershipId,
      },
    );
    return OrganizationStudentSubjectLeadResult.fromJson(_mapResponse(response));
  }

'''
replace_once(repo, impl_marker, impl_add)

error_marker = r'''  return switch (detail.toLowerCase()) {
    'invalid_student_teacher_assignment_transfer_input' => '任课交接信息不完整，请刷新后重试。',
'''
error_add = r'''  return switch (detail.toLowerCase()) {
    'invalid_student_subject_lead_assignment_input' =>
      '主责老师设置信息不完整，请刷新后重试。',
    'student_subject_profile_version_conflict' =>
      '这门学生学科档案刚刚发生变化，请刷新后重试。',
    'student_subject_lead_already_assigned' =>
      '这门学科刚刚已经明确了主责老师，请刷新后核对。',
    'teacher_membership_not_found' => '所选老师已不在本机构，请刷新后重新选择。',
    'invalid_student_teacher_assignment_transfer_input' => '任课交接信息不完整，请刷新后重试。',
'''
replace_once(repo, error_marker, error_add)

page = "lib/features/organization_management/presentation/organization_management_page.dart"
replace_once(
    page,
    "import 'organization_student_subject_restore_dialog.dart';\n",
    "import 'organization_student_subject_lead_dialog.dart';\n"
    "import 'organization_student_subject_restore_dialog.dart';\n",
)
replace_once(
    page,
    "                              onTransferStudentTeacherAssignment:\n                                  _transferStudentTeacherAssignment,\n",
    "                              onSetStudentSubjectLead:\n                                  _setStudentSubjectLead,\n"
    "                              onTransferStudentTeacherAssignment:\n"
    "                                  _transferStudentTeacherAssignment,\n",
)

learning = "lib/features/organization_management/presentation/organization_management_learning_actions.dart"
transfer_marker = r'''  Future<void> _transferStudentTeacherAssignment(
'''
lead_action = r'''  Future<void> _setStudentSubjectLead(
    OrganizationStudentRecord student,
    OrganizationStudentSubjectService service,
  ) async {
    if (_busy || !student.isActive || !service.isActive) return;
    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) return;
      final candidates = snapshot.setupOptions.teachersForSubject(
        service.organizationSubjectId,
      );
      if (candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '当前没有可负责${service.subjectName}的在岗老师。请先配置老师的可教学科。',
            ),
          ),
        );
        return;
      }

      final draft = await showDialog<OrganizationStudentSubjectLeadDraft>(
        context: context,
        builder: (context) => OrganizationStudentSubjectLeadDialog(
          studentName: student.studentName,
          service: service,
          candidates: candidates,
        ),
      );
      if (!mounted || draft == null) return;

      await _runMutation(
        () => widget.repository.setStudentSubjectLead(
          operationId: draft.operationId,
          organizationId: widget.organizationId,
          studentSubjectProfileId: service.profileId,
          expectedProfileVersion: service.version,
          teacherMembershipId: draft.teacherMembershipId,
        ),
        '已为 ${student.studentName} · ${service.subjectName} 设置主责老师${draft.teacherName}。',
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    }
  }

'''
replace_once(learning, transfer_marker, lead_action + transfer_marker)

areas = "lib/features/organization_management/presentation/organization_management_areas.dart"
replace_once(
    areas,
    "    required this.onToggleTeacherScope,\n    required this.onTransferStudentTeacherAssignment,\n",
    "    required this.onToggleTeacherScope,\n"
    "    required this.onSetStudentSubjectLead,\n"
    "    required this.onTransferStudentTeacherAssignment,\n",
)
replace_once(
    areas,
    "  final Future<void> Function(OrganizationStudentTeacherAssignment assignment)\n  onTransferStudentTeacherAssignment;\n",
    "  final Future<void> Function(\n"
    "    OrganizationStudentRecord student,\n"
    "    OrganizationStudentSubjectService service,\n"
    "  )\n"
    "  onSetStudentSubjectLead;\n"
    "  final Future<void> Function(OrganizationStudentTeacherAssignment assignment)\n"
    "  onTransferStudentTeacherAssignment;\n",
)
replace_once(
    areas,
    "                          onTransferAssignment: (assignment) => widget\n                              .onTransferStudentTeacherAssignment(assignment),\n",
    "                          onSetSubjectLead: (service) => widget\n"
    "                              .onSetStudentSubjectLead(student, service),\n"
    "                          onTransferAssignment: (assignment) => widget\n"
    "                              .onTransferStudentTeacherAssignment(assignment),\n",
)

rows = "lib/features/organization_management/presentation/organization_management_rows.dart"
replace_once(
    rows,
    "    required this.activeAssignments,\n    required this.onTransferAssignment,\n",
    "    required this.activeAssignments,\n"
    "    required this.onSetSubjectLead,\n"
    "    required this.onTransferAssignment,\n",
)
replace_once(
    rows,
    "  final List<OrganizationStudentTeacherAssignment> activeAssignments;\n  final Future<void> Function(OrganizationStudentTeacherAssignment assignment)\n  onTransferAssignment;\n",
    "  final List<OrganizationStudentTeacherAssignment> activeAssignments;\n"
    "  final Future<void> Function(OrganizationStudentSubjectService service)\n"
    "  onSetSubjectLead;\n"
    "  final Future<void> Function(OrganizationStudentTeacherAssignment assignment)\n"
    "  onTransferAssignment;\n",
)
replace_once(
    rows,
    "                    busy: busy,\n                    onTransfer: (assignment) =>\n                        onTransferAssignment(assignment),\n",
    "                    busy: busy,\n"
    "                    onSetLead: student.isActive && service.isActive\n"
    "                        ? () => onSetSubjectLead(service)\n"
    "                        : null,\n"
    "                    onTransfer: (assignment) =>\n"
    "                        onTransferAssignment(assignment),\n",
)
replace_once(
    rows,
    "    required this.busy,\n    required this.onTransfer,\n    required this.onToggle,\n",
    "    required this.busy,\n"
    "    required this.onSetLead,\n"
    "    required this.onTransfer,\n"
    "    required this.onToggle,\n",
)
replace_once(
    rows,
    "  final bool busy;\n  final Future<void> Function(OrganizationStudentTeacherAssignment assignment)\n  onTransfer;\n  final VoidCallback? onToggle;\n\n  @override\n  Widget build(BuildContext context) {\n",
    "  final bool busy;\n"
    "  final VoidCallback? onSetLead;\n"
    "  final Future<void> Function(OrganizationStudentTeacherAssignment assignment)\n"
    "  onTransfer;\n"
    "  final VoidCallback? onToggle;\n\n"
    "  @override\n"
    "  Widget build(BuildContext context) {\n"
    "    final hasLead = assignments.any(\n"
    "      (assignment) => assignment.isActive && assignment.isLead,\n"
    "    );\n",
)
old_responsibility = r'''          if (service.isActive) ...[
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
'''
new_responsibility = r'''          if (service.isActive) ...[
            const SizedBox(height: AppSpacing.xxs),
            if (!hasLead)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  Text(
                    '暂未明确主责老师',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  if (onSetLead != null)
                    TextButton(
                      key: ValueKey<String>(
                        'student-subject-set-lead-${service.profileId}',
                      ),
                      onPressed: busy ? null : onSetLead,
                      child: const Text('设置主责老师'),
                    ),
                ],
              ),
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
'''
replace_once(rows, old_responsibility, new_responsibility)

# Main organization-management widget fake + focused UX test.
test = "test/features/organization_management_test.dart"
replace_once(
    test,
    "  int assignmentTransferCount = 0;\n",
    "  int assignmentTransferCount = 0;\n  int studentSubjectLeadSetCount = 0;\n",
)
fake_marker = r'''  @override
  Future<OrganizationStudentSetupResult> addStudentSubject({
'''
fake_method = r'''  @override
  Future<OrganizationStudentSubjectLeadResult> setStudentSubjectLead({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
    required String teacherMembershipId,
  }) async {
    studentSubjectLeadSetCount++;
    final student = students.firstWhere(
      (item) => item.subjectServices.any(
        (service) => service.profileId == studentSubjectProfileId,
      ),
    );
    final service = student.subjectServices.firstWhere(
      (item) => item.profileId == studentSubjectProfileId,
    );
    final teacher = setupOptions.teachersForSubject(
      service.organizationSubjectId,
    ).firstWhere((item) => item.membershipId == teacherMembershipId);
    final assignment = OrganizationStudentTeacherAssignment(
      assignmentId: 'assignment-set-lead-$studentSubjectLeadSetCount',
      organizationId: organizationId,
      studentSubjectProfileId: studentSubjectProfileId,
      studentId: student.studentId,
      studentName: student.studentName,
      organizationSubjectId: service.organizationSubjectId,
      subjectName: service.subjectName,
      subjectCode: service.subjectName.toLowerCase(),
      membershipId: teacher.membershipId,
      teacherName: teacher.displayName,
      teacherEmail: teacher.email,
      assignmentRole: 'lead',
      status: 'active',
      version: 1,
      activeFrom: DateTime(2026, 9, 12),
      activeTo: null,
      endedAt: null,
    );
    studentTeacherAssignments.add(assignment);
    return OrganizationStudentSubjectLeadResult(
      operationId: operationId,
      organizationId: organizationId,
      studentId: student.studentId,
      studentName: student.studentName,
      studentSubjectProfileId: studentSubjectProfileId,
      organizationSubjectId: service.organizationSubjectId,
      subjectName: service.subjectName,
      subjectCode: service.subjectName.toLowerCase(),
      assignmentId: assignment.assignmentId,
      assignmentRole: 'lead',
      assignmentStatus: 'active',
      assignmentVersion: 1,
      teacherMembershipId: teacher.membershipId,
      teacherDisplayName: teacher.displayName,
      teacherEmail: teacher.email,
      teacherScopeId: 'scope-set-lead',
      activeFrom: assignment.activeFrom,
    );
  }

'''
replace_once(test, fake_marker, fake_method + fake_marker)

test_marker = "  testWidgets('missing subjects opens settings first', (tester) async {\n"
new_test = r'''  testWidgets('active subject without Lead can explicitly set responsible teacher', (
    tester,
  ) async {
    final collaborator = OrganizationStudentTeacherAssignment(
      assignmentId: 'assignment-collaborator',
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
      studentTeacherAssignments: [collaborator],
      setupOptions: const OrganizationSetupOptions(
        subjects: [
          OrganizationSetupSubject(id: 'subject-1', displayName: '数学'),
        ],
        teachers: [
          OrganizationSetupTeacher(
            membershipId: 'membership-2',
            displayName: '协作老师',
            email: 'collaborator@example.com',
            organizationSubjectIds: ['subject-1'],
          ),
          OrganizationSetupTeacher(
            membershipId: 'membership-3',
            displayName: '新主责老师',
            email: 'lead@example.com',
            organizationSubjectIds: ['subject-1'],
          ),
        ],
      ),
    );

    await _pumpManagement(tester, repository);
    await _selectManagementArea(tester, '学生');

    expect(find.text('暂未明确主责老师'), findsOneWidget);
    expect(find.text('协作老师：协作老师'), findsOneWidget);
    final setLeadButton = find.byKey(
      const ValueKey<String>('student-subject-set-lead-profile-1'),
    );
    expect(setLeadButton, findsOneWidget);
    await tester.ensureVisible(setLeadButton);
    await tester.tap(setLeadButton);
    await tester.pumpAndSettle();

    expect(find.text('设置主责老师'), findsWidgets);
    expect(find.text('原学生 · 数学'), findsOneWidget);
    expect(find.text('这位老师将负责该学科后续新建立的问题。'), findsOneWidget);
    expect(find.text('已有问题的主责、待办负责人和历史记录不会自动修改。'), findsOneWidget);

    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('新主责老师').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-subject-set-lead-confirm')));
    await tester.pumpAndSettle();

    expect(repository.studentSubjectLeadSetCount, 1);
    expect(find.text('暂未明确主责老师'), findsNothing);
    expect(find.text('主责老师：新主责老师'), findsOneWidget);
    expect(find.text('协作老师：协作老师'), findsOneWidget);
  });

'''
replace_once(test, test_marker, new_test + test_marker)
