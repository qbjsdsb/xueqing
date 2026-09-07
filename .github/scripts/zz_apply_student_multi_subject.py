from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected exactly one anchor, found {count}")
    file_path.write_text(text.replace(old, new, 1), encoding="utf-8")


repo = "lib/cloud/organization_management_repository.dart"
replace_once(
    repo,
    """  Future<List<OrganizationStudentTeacherAssignment>>
  listStudentTeacherAssignments({required String organizationId});

  Future<OrganizationStudentTeacherAssignmentTransferResult>
""",
    """  Future<List<OrganizationStudentTeacherAssignment>>
  listStudentTeacherAssignments({required String organizationId});

  Future<OrganizationStudentSetupResult> addStudentSubject({
    required String operationId,
    required String organizationId,
    required String studentId,
    required String organizationSubjectId,
    required String teacherMembershipId,
    DateTime? startsOn,
  });

  Future<OrganizationStudentTeacherAssignmentTransferResult>
""",
)

replace_once(
    repo,
    """  @override
  Future<OrganizationStudentTeacherAssignmentTransferResult>
  transferStudentTeacherAssignment({
""",
    """  @override
  Future<OrganizationStudentSetupResult> addStudentSubject({
    required String operationId,
    required String organizationId,
    required String studentId,
    required String organizationSubjectId,
    required String teacherMembershipId,
    DateTime? startsOn,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentId.trim().isEmpty ||
        organizationSubjectId.trim().isEmpty ||
        teacherMembershipId.trim().isEmpty) {
      throw ArgumentError('Student subject setup identity is invalid.');
    }
    final response = await _call(
      'add_organization_student_subject_service',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_id': studentId,
        'p_organization_subject_id': organizationSubjectId,
        'p_teacher_membership_id': teacherMembershipId,
        'p_starts_on': _dateOnlyValue(startsOn),
      },
    );
    return OrganizationStudentSetupResult.fromJson(_mapResponse(response));
  }

  @override
  Future<OrganizationStudentTeacherAssignmentTransferResult>
  transferStudentTeacherAssignment({
""",
)

replace_once(
    repo,
    """  return switch (detail.toLowerCase()) {
    'invalid_student_setup_input' => '学生信息不完整或过长，请检查后重试。',
""",
    """  return switch (detail.toLowerCase()) {
    'invalid_student_setup_input' => '学生信息不完整或过长，请检查后重试。',
    'invalid_student_subject_setup_input' => '学生、学科或负责老师信息不完整，请刷新后重试。',
    'student_subject_profile_already_exists' => '这个学生已经有这门学科的档案；如需恢复历史学科，请不要重复新增。',
""",
)

page = "lib/features/organization_management/presentation/organization_management_page.dart"
replace_once(
    page,
    """import 'organization_student_setup_dialog.dart';
import 'organization_student_teacher_assignment_transfer_dialog.dart';
""",
    """import 'organization_student_setup_dialog.dart';
import 'organization_student_subject_setup_dialog.dart';
import 'organization_student_teacher_assignment_transfer_dialog.dart';
""",
)
replace_once(
    page,
    """                        onAddStudent: _addStudent,
                        onInviteMember: _inviteMember,
""",
    """                        onAddStudent: _addStudent,
                        onAddStudentSubject: _addStudentSubject,
                        onInviteMember: _inviteMember,
""",
)

actions = "lib/features/organization_management/presentation/organization_management_learning_actions.dart"
replace_once(
    actions,
    """  Future<void> _transferStudentTeacherAssignment(
    OrganizationStudentTeacherAssignment assignment,
  ) async {
""",
    """  Future<void> _addStudentSubject(OrganizationStudentRecord student) async {
    if (_busy || !student.isActive) return;
    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) return;

      final existingSubjectIds = <String>{
        for (final assignment in snapshot.studentTeacherAssignments)
          if (assignment.studentId == student.studentId)
            assignment.organizationSubjectId,
      };
      final availableSubjects = <OrganizationSetupSubject>[
        for (final subject in snapshot.setupOptions.subjectsWithAvailableTeachers)
          if (!existingSubjectIds.contains(subject.id)) subject,
      ];
      if (availableSubjects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('这个学生暂时没有可新增的学科；已有或历史学科不会重复建档。'),
          ),
        );
        return;
      }

      final draft =
          await showDialog<OrganizationStudentSubjectSetupDraft>(
            context: context,
            builder: (context) => OrganizationStudentSubjectSetupDialog(
              student: student,
              subjects: availableSubjects,
              teachers: snapshot.setupOptions.teachers,
            ),
          );
      if (!mounted || draft == null) return;

      await _runMutation(
        () => widget.repository.addStudentSubject(
          operationId: draft.operationId,
          organizationId: widget.organizationId,
          studentId: draft.studentId,
          organizationSubjectId: draft.organizationSubjectId,
          teacherMembershipId: draft.teacherMembershipId,
        ),
        '已为 ${student.studentName} 增加 ${draft.subjectName} · ${draft.teacherName} 负责。',
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    }
  }

  Future<void> _transferStudentTeacherAssignment(
    OrganizationStudentTeacherAssignment assignment,
  ) async {
""",
)

areas = "lib/features/organization_management/presentation/organization_management_areas.dart"
replace_once(
    areas,
    """    required this.onAddStudent,
    required this.onInviteMember,
""",
    """    required this.onAddStudent,
    required this.onAddStudentSubject,
    required this.onInviteMember,
""",
)
replace_once(
    areas,
    """  final VoidCallback onAddStudent;
  final VoidCallback onInviteMember;
""",
    """  final VoidCallback onAddStudent;
  final Future<void> Function(OrganizationStudentRecord student)
  onAddStudentSubject;
  final VoidCallback onInviteMember;
""",
)
replace_once(
    areas,
    """                        _OrganizationStudentTile(
                          student: student,
                          busy: widget.busy,
                          onEdit: student.isMerged
                              ? null
                              : () => widget.onEditStudent(student),
                        ),
""",
    """                        _OrganizationStudentTile(
                          student: student,
                          busy: widget.busy,
                          onAddSubject: student.isActive && !student.isMerged
                              ? () => widget.onAddStudentSubject(student)
                              : null,
                          onEdit: student.isMerged
                              ? null
                              : () => widget.onEditStudent(student),
                        ),
""",
)

rows = "lib/features/organization_management/presentation/organization_management_rows.dart"
replace_once(
    rows,
    """  const _OrganizationStudentTile({
    required this.student,
    required this.busy,
    required this.onEdit,
  });

  final OrganizationStudentRecord student;
  final bool busy;
  final VoidCallback? onEdit;
""",
    """  const _OrganizationStudentTile({
    required this.student,
    required this.busy,
    required this.onAddSubject,
    required this.onEdit,
  });

  final OrganizationStudentRecord student;
  final bool busy;
  final VoidCallback? onAddSubject;
  final VoidCallback? onEdit;
""",
)
replace_once(
    rows,
    """          Row(
            children: [
              Expanded(
                child: Text(
                  student.studentName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('编辑'),
                ),
            ],
          ),
""",
    """          Text(
            student.studentName,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
""",
)
replace_once(
    rows,
    """          if (student.subjectNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '学科：${student.subjectNames.join('、')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
""",
    """          if (student.subjectNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '学科：${student.subjectNames.join('、')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (onAddSubject != null || onEdit != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (onAddSubject != null)
                  TextButton.icon(
                    onPressed: busy ? null : onAddSubject,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('添加学科'),
                  ),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('编辑'),
                  ),
              ],
            ),
          ],
""",
)

test = "test/features/organization_management_test.dart"
replace_once(
    test,
    """  int teacherScopeUpdateCount = 0;
  int assignmentTransferCount = 0;
  OrganizationStudentSetupResult? createdStudent;
""",
    """  int teacherScopeUpdateCount = 0;
  int assignmentTransferCount = 0;
  int studentSubjectAddCount = 0;
  OrganizationStudentSetupResult? createdStudent;
  OrganizationStudentSetupResult? addedStudentSubject;
""",
)
replace_once(
    test,
    """  @override
  Future<OrganizationStudentTeacherAssignmentTransferResult>
  transferStudentTeacherAssignment({
""",
    """  @override
  Future<OrganizationStudentSetupResult> addStudentSubject({
    required String operationId,
    required String organizationId,
    required String studentId,
    required String organizationSubjectId,
    required String teacherMembershipId,
    DateTime? startsOn,
  }) async {
    studentSubjectAddCount++;
    final subject = setupOptions.subjects.firstWhere(
      (item) => item.id == organizationSubjectId,
    );
    final teacher = setupOptions.teachers.firstWhere(
      (item) => item.membershipId == teacherMembershipId,
    );
    addedStudentSubject = OrganizationStudentSetupResult(
      operationId: operationId,
      studentId: studentId,
      studentName: students.firstWhere(
        (item) => item.studentId == studentId,
      ).studentName,
      studentSubjectProfileId: 'profile-added-$studentSubjectAddCount',
      organizationSubjectId: organizationSubjectId,
      subjectName: subject.displayName,
      teacherMembershipId: teacherMembershipId,
      teacherDisplayName: teacher.displayName,
      startsOn: startsOn ?? DateTime(2026, 9, 4),
    );
    studentTeacherAssignments.add(
      OrganizationStudentTeacherAssignment(
        assignmentId: 'assignment-added-$studentSubjectAddCount',
        organizationId: organizationId,
        studentSubjectProfileId:
            addedStudentSubject!.studentSubjectProfileId,
        studentId: studentId,
        studentName: addedStudentSubject!.studentName,
        organizationSubjectId: organizationSubjectId,
        subjectName: subject.displayName,
        subjectCode: subject.displayName.toLowerCase(),
        membershipId: teacherMembershipId,
        teacherName: teacher.displayName,
        teacherEmail: teacher.email,
        assignmentRole: 'lead',
        status: 'active',
        version: 1,
        activeFrom: addedStudentSubject!.startsOn,
        activeTo: null,
        endedAt: null,
      ),
    );
    final studentIndex = students.indexWhere(
      (item) => item.studentId == studentId,
    );
    if (studentIndex >= 0) {
      final previous = students[studentIndex];
      students[studentIndex] = OrganizationStudentRecord(
        studentId: previous.studentId,
        studentName: previous.studentName,
        studentCode: previous.studentCode,
        status: previous.status,
        version: previous.version,
        grade: previous.grade,
        className: previous.className,
        campus: previous.campus,
        startsOn: previous.startsOn,
        endsOn: previous.endsOn,
        subjectNames: <String>[
          ...previous.subjectNames,
          if (!previous.subjectNames.contains(subject.displayName))
            subject.displayName,
        ],
      );
    }
    return addedStudentSubject!;
  }

  @override
  Future<OrganizationStudentTeacherAssignmentTransferResult>
  transferStudentTeacherAssignment({
""",
)
replace_once(
    test,
    """  testWidgets('keeps optional student details behind one disclosure', (
""",
    """  testWidgets('adds a second subject without replacing the existing teacher relation', (
    tester,
  ) async {
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
      students: [_studentRecord()],
      studentTeacherAssignments: [_studentTeacherAssignment()],
      setupOptions: const OrganizationSetupOptions(
        subjects: [
          OrganizationSetupSubject(id: 'subject-1', displayName: '数学'),
          OrganizationSetupSubject(id: 'subject-2', displayName: '英语'),
        ],
        teachers: [
          OrganizationSetupTeacher(
            membershipId: 'membership-1',
            displayName: '原老师',
            email: 'old-teacher@example.com',
            organizationSubjectIds: ['subject-1', 'subject-2'],
          ),
        ],
      ),
    );
    await _pumpManagement(tester, repository);
    await _selectManagementArea(tester, '学生');

    final addSubject = find.widgetWithText(TextButton, '添加学科');
    await tester.ensureVisible(addSubject);
    await tester.tap(addSubject);
    await tester.pumpAndSettle();

    expect(find.text('为 原学生 添加学科'), findsOneWidget);
    expect(
      find.text('同一位老师可以负责同一学生的多门学科，只要该老师已配置相应可教学科。'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('student-subject-setup-submit')));
    await tester.pumpAndSettle();

    expect(repository.studentSubjectAddCount, 1);
    expect(repository.addedStudentSubject?.organizationSubjectId, 'subject-2');
    expect(repository.addedStudentSubject?.teacherMembershipId, 'membership-1');
    expect(
      repository.studentTeacherAssignments.where((item) => item.isActive).length,
      2,
    );
    expect(repository.students.single.subjectNames, containsAll(['数学', '英语']));
  });

  testWidgets('keeps optional student details behind one disclosure', (
""",
)

print('student multi-subject patch applied')
