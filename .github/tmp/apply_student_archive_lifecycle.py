from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    assert count == 1, f"{path}: expected 1 match, found {count}"
    path.write_text(text.replace(old, new, 1))


# ---------------------------------------------------------------------------
# UI callback plumbing
# ---------------------------------------------------------------------------
areas = Path('lib/features/organization_management/presentation/organization_management_areas.dart')
replace_once(
    areas,
    """    required this.onToggleStudentSubjectService,\n    required this.onToggleStudentTeaching,\n    required this.onInviteMember,\n""",
    """    required this.onToggleStudentSubjectService,\n    required this.onToggleStudentTeaching,\n    required this.onToggleStudentArchive,\n    required this.onInviteMember,\n""",
)
replace_once(
    areas,
    """  final Future<void> Function(OrganizationStudentRecord student)\n  onToggleStudentTeaching;\n  final VoidCallback onInviteMember;\n""",
    """  final Future<void> Function(OrganizationStudentRecord student)\n  onToggleStudentTeaching;\n  final Future<void> Function(OrganizationStudentRecord student)\n  onToggleStudentArchive;\n  final VoidCallback onInviteMember;\n""",
)
replace_once(
    areas,
    """                          onToggleTeaching:\n                              student.isMerged ||\n                                  student.status != 'active' &&\n                                      student.status != 'inactive'\n                              ? null\n                              : () => widget.onToggleStudentTeaching(student),\n                          onEdit: student.isMerged\n""",
    """                          onToggleTeaching:\n                              student.isMerged ||\n                                  student.status != 'active' &&\n                                      student.status != 'inactive'\n                              ? null\n                              : () => widget.onToggleStudentTeaching(student),\n                          onToggleArchive: student.isMerged\n                              ? null\n                              : student.status == 'archived' ||\n                                    student.status == 'inactive' &&\n                                        !student.subjectServices.any(\n                                          (service) => service.isActive,\n                                        )\n                              ? () => widget.onToggleStudentArchive(student)\n                              : null,\n                          onEdit: student.isMerged\n""",
)

page = Path('lib/features/organization_management/presentation/organization_management_page.dart')
replace_once(
    page,
    """                        onToggleStudentTeaching: _toggleStudentTeaching,\n                        onInviteMember: _inviteMember,\n""",
    """                        onToggleStudentTeaching: _toggleStudentTeaching,\n                        onToggleStudentArchive: _toggleStudentArchive,\n                        onInviteMember: _inviteMember,\n""",
)

rows = Path('lib/features/organization_management/presentation/organization_management_rows.dart')
replace_once(
    rows,
    """    required this.onToggleSubjectService,\n    required this.onToggleTeaching,\n    required this.onEdit,\n""",
    """    required this.onToggleSubjectService,\n    required this.onToggleTeaching,\n    required this.onToggleArchive,\n    required this.onEdit,\n""",
)
replace_once(
    rows,
    """  final VoidCallback? onToggleTeaching;\n  final VoidCallback? onEdit;\n""",
    """  final VoidCallback? onToggleTeaching;\n  final VoidCallback? onToggleArchive;\n  final VoidCallback? onEdit;\n""",
)
replace_once(
    rows,
    """          if (onAddSubject != null ||\n              onToggleTeaching != null ||\n              onEdit != null) ...[\n""",
    """          if (onAddSubject != null ||\n              onToggleTeaching != null ||\n              onToggleArchive != null ||\n              onEdit != null) ...[\n""",
)
replace_once(
    rows,
    """                if (onEdit != null)\n                  TextButton.icon(\n                    onPressed: busy ? null : onEdit,\n""",
    """                if (onToggleArchive != null)\n                  TextButton.icon(\n                    key: ValueKey<String>(\n                      'student-archive-toggle-${student.studentId}',\n                    ),\n                    onPressed: busy ? null : onToggleArchive,\n                    icon: Icon(\n                      student.status == 'archived'\n                          ? Icons.unarchive_outlined\n                          : Icons.archive_outlined,\n                      size: 18,\n                    ),\n                    label: Text(\n                      student.status == 'archived' ? '取消归档' : '归档学生',\n                    ),\n                  ),\n                if (onEdit != null)\n                  TextButton.icon(\n                    onPressed: busy ? null : onEdit,\n""",
)

# ---------------------------------------------------------------------------
# Explicit archive/unarchive action
# ---------------------------------------------------------------------------
actions = Path('lib/features/organization_management/presentation/organization_management_learning_actions.dart')
replace_once(
    actions,
    """  Future<void> _editStudent(OrganizationStudentRecord student) async {\n""",
    """  Future<void> _toggleStudentArchive(\n    OrganizationStudentRecord student,\n  ) async {\n    if (_busy || student.isMerged) return;\n    final archiving = student.status == 'inactive';\n    final unarchiving = student.status == 'archived';\n    if (!archiving && !unarchiving) return;\n\n    if (archiving &&\n        student.subjectServices.any((service) => service.isActive)) {\n      ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(\n          content: Text(\n            '这位学生仍有进行中的学科服务；如果只是暂时停课，请保持“暂不教学”。长期离开机构时，请先逐科完成结束再归档。',\n          ),\n        ),\n      );\n      return;\n    }\n\n    final confirmed = await _confirm(\n      title: archiving\n          ? '归档 ${student.studentName}？'\n          : '取消归档 ${student.studentName}？',\n      message: archiving\n          ? '归档用于学生长期结束服务或离开机构后的历史保留。已有学科、Case、证据和历史记录不会删除；若只是暂时停课，请不要归档。'\n          : '取消归档只把学生恢复为“暂不教学”，不会自动恢复老师工作台，也不会自动恢复已经结束的学科。需要继续教学时，再明确执行恢复教学和相应学科恢复。',\n      confirmLabel: archiving ? '确认归档' : '确认取消归档',\n    );\n    if (!mounted || !confirmed) return;\n\n    await _runMutation(\n      () => widget.repository.updateStudent(\n        operationId: createOperationId(),\n        organizationId: widget.organizationId,\n        studentId: student.studentId,\n        expectedStudentVersion: student.version,\n        name: student.studentName,\n        studentCode: student.studentCode,\n        status: archiving ? 'archived' : 'inactive',\n      ),\n      archiving\n          ? '已归档 ${student.studentName}；历史记录已保留。'\n          : '已取消归档 ${student.studentName}；当前为暂不教学。',\n    );\n  }\n\n  Future<void> _editStudent(OrganizationStudentRecord student) async {\n""",
)

# ---------------------------------------------------------------------------
# Error copy for server-enforced archive transitions
# ---------------------------------------------------------------------------
repo = Path('lib/cloud/organization_management_repository.dart')
replace_once(
    repo,
    """    'student_merged_immutable' => '已合并的学生档案不能直接修改。',\n    'version_conflict' => '这条学生档案刚刚被别人修改，请刷新后重试。',\n""",
    """    'student_merged_immutable' => '已合并的学生档案不能直接修改。',\n    'student_archive_requires_paused' => '归档前请先暂停教学；临时停课不需要归档。',\n    'student_archive_active_subjects' => '这位学生仍有进行中的学科服务，请先逐科完成结束后再归档。',\n    'student_unarchive_requires_inactive' => '取消归档后必须先回到暂不教学状态，再决定是否恢复教学。',\n    'version_conflict' => '这条学生档案刚刚被别人修改，请刷新后重试。',\n""",
)

# ---------------------------------------------------------------------------
# Server-side archive transition guard appended to current migration
# ---------------------------------------------------------------------------
migration = Path('supabase/migrations/20260908023000_student_teaching_pause_resume.sql')
text = migration.read_text()
assert 'guard_student_archive_transition_v2' not in text
migration.write_text(text + r'''

-- Keep long-term archive distinct from temporary teaching pause, including for
-- older clients that still call update_organization_student directly.
create or replace function private.guard_student_archive_transition_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.status = old.status then
    return new;
  end if;

  if new.status = 'archived' then
    if old.status <> 'inactive' then
      raise exception using
        errcode = 'P0001',
        message = 'student_archive_requires_paused';
    end if;

    if exists (
      select 1
      from public.student_subject_profiles as profile
      where profile.organization_id = old.organization_id
        and profile.student_id = old.id
        and profile.status = 'active'
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'student_archive_active_subjects';
    end if;
  end if;

  if old.status = 'archived'
    and new.status not in ('archived', 'inactive') then
    raise exception using
      errcode = 'P0001',
      message = 'student_unarchive_requires_inactive';
  end if;

  return new;
end
$function$;

revoke all on function private.guard_student_archive_transition_v2()
  from public, anon, authenticated, service_role;

drop trigger if exists guard_student_archive_transition_v2
  on public.students;
create trigger guard_student_archive_transition_v2
before update of status
on public.students
for each row
execute function private.guard_student_archive_transition_v2();
''')

# ---------------------------------------------------------------------------
# Database coverage: direct/legacy calls must obey archive boundary too
# ---------------------------------------------------------------------------
dbtest = Path('supabase/tests/student_teaching_pause_resume_test.sql')
replace_once(dbtest, 'select plan(47);', 'select plan(56);')
fixture_anchor = """insert into public.students (\n  id, organization_id, name, status, version, archived_at\n) values (\n  '30000000-0000-0000-0000-000000000097',\n"""
assert dbtest.read_text().count(fixture_anchor) == 1
fixture_prefix = """insert into public.students (\n  id, organization_id, name, status, version\n) values\n  (\n    '30000000-0000-0000-0000-000000000096',\n    '00000000-0000-0000-0000-000000000001',\n    '可归档测试学生',\n    'inactive',\n    1\n  ),\n  (\n    '30000000-0000-0000-0000-000000000095',\n    '00000000-0000-0000-0000-000000000001',\n    '仍有活跃学科测试学生',\n    'inactive',\n    1\n  );\n\ninsert into public.student_subject_profiles (\n  id, organization_id, student_id, organization_subject_id, status, version\n) values\n  (\n    '67000000-0000-0000-0000-000000000096',\n    '00000000-0000-0000-0000-000000000001',\n    '30000000-0000-0000-0000-000000000096',\n    '64000000-0000-0000-0000-000000000001',\n    'inactive',\n    1\n  ),\n  (\n    '67000000-0000-0000-0000-000000000095',\n    '00000000-0000-0000-0000-000000000001',\n    '30000000-0000-0000-0000-000000000095',\n    '64000000-0000-0000-0000-000000000001',\n    'active',\n    1\n  );\n\n"""
replace_once(dbtest, fixture_anchor, fixture_prefix + fixture_anchor)
finish_anchor = """-- TEST 47\nselect is((select count(*)::int from public.case_actions where learning_case_id = '72000000-0000-0000-0000-000000000098'), 1, 'pause and resume never duplicate Actions');\n\nselect * from finish();\n"""
archive_tests = """-- TEST 47\nselect is((select count(*)::int from public.case_actions where learning_case_id = '72000000-0000-0000-0000-000000000098'), 1, 'pause and resume never duplicate Actions');\n\nset local role authenticated;\nselect set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000001', true);\nselect set_config(\n  'request.jwt.claims',\n  json_build_object(\n    'role', 'authenticated',\n    'sub', '20000000-0000-0000-0000-000000000001',\n    'iss', 'http://127.0.0.1:54321/auth/v1',\n    'session_id', '50000000-0000-0000-0000-000000000001'\n  )::text,\n  true\n);\n-- TEST 48\nselect throws_ok(\n  $$select public.update_organization_student('76000000-0000-0000-0000-000000000209','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000098',3,'暂停恢复测试学生','PAUSE-098','archived')$$,\n  'P0001', 'student_archive_requires_paused', 'active student cannot skip temporary pause and jump directly to archive'\n);\n-- TEST 49\nselect throws_ok(\n  $$select public.update_organization_student('76000000-0000-0000-0000-000000000210','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000095',1,'仍有活跃学科测试学生',null,'archived')$$,\n  'P0001', 'student_archive_active_subjects', 'paused student with an active subject cannot be misclassified as archived'\n);\n-- TEST 50\nselect is(\n  public.update_organization_student(\n    '76000000-0000-0000-0000-000000000211',\n    '00000000-0000-0000-0000-000000000001',\n    '30000000-0000-0000-0000-000000000096',\n    1,\n    '可归档测试学生',\n    null,\n    'archived'\n  ) ->> 'status',\n  'archived',\n  'paused student whose subject services have ended can be archived'\n);\n\nreset role;\n-- TEST 51\nselect is((select status from public.students where id = '30000000-0000-0000-0000-000000000096'), 'archived', 'archive persists root archive state');\n-- TEST 52\nselect is((select archived_at is not null from public.students where id = '30000000-0000-0000-0000-000000000096'), true, 'archive records archive timestamp');\n\nset local role authenticated;\nselect set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000001', true);\nselect set_config(\n  'request.jwt.claims',\n  json_build_object(\n    'role', 'authenticated',\n    'sub', '20000000-0000-0000-0000-000000000001',\n    'iss', 'http://127.0.0.1:54321/auth/v1',\n    'session_id', '50000000-0000-0000-0000-000000000001'\n  )::text,\n  true\n);\n-- TEST 53\nselect throws_ok(\n  $$select public.update_organization_student('76000000-0000-0000-0000-000000000212','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000096',2,'可归档测试学生',null,'active')$$,\n  'P0001', 'student_unarchive_requires_inactive', 'archived student cannot jump directly back into teaching'\n);\n-- TEST 54\nselect is(\n  public.update_organization_student(\n    '76000000-0000-0000-0000-000000000213',\n    '00000000-0000-0000-0000-000000000001',\n    '30000000-0000-0000-0000-000000000096',\n    2,\n    '可归档测试学生',\n    null,\n    'inactive'\n  ) ->> 'status',\n  'inactive',\n  'explicit unarchive returns student to paused state'\n);\n\nreset role;\n-- TEST 55\nselect is((select version from public.students where id = '30000000-0000-0000-0000-000000000096'), 3, 'archive and unarchive each increment root version once');\n-- TEST 56\nselect is((select archived_at is null from public.students where id = '30000000-0000-0000-0000-000000000096'), true, 'unarchive clears archive timestamp without restoring teaching');\n\nselect * from finish();\n"""
replace_once(dbtest, finish_anchor, archive_tests)

# ---------------------------------------------------------------------------
# Widget fake becomes stateful enough to verify archive/unarchive refresh
# ---------------------------------------------------------------------------
widget_test = Path('test/features/organization_management_test.dart')
replace_once(
    widget_test,
    """    studentUpdateCount++;\n    updatedStudent = OrganizationStudentUpdateResult(\n      operationId: operationId,\n      studentId: studentId,\n      studentName: name,\n      studentCode: studentCode,\n      status: status,\n      version: expectedStudentVersion + 1,\n    );\n    return updatedStudent!;\n""",
    """    studentUpdateCount++;\n    final index = students.indexWhere((student) => student.studentId == studentId);\n    if (index < 0) throw StateError('Student not found.');\n    final previous = students[index];\n    final next = OrganizationStudentRecord(\n      studentId: previous.studentId,\n      studentName: name,\n      studentCode: studentCode,\n      status: status,\n      version: expectedStudentVersion + 1,\n      grade: previous.grade,\n      className: previous.className,\n      campus: previous.campus,\n      startsOn: previous.startsOn,\n      endsOn: previous.endsOn,\n      subjectNames: previous.subjectNames,\n      subjectServices: previous.subjectServices,\n    );\n    students[index] = next;\n    updatedStudent = OrganizationStudentUpdateResult(\n      operationId: operationId,\n      studentId: studentId,\n      studentName: next.studentName,\n      studentCode: next.studentCode,\n      status: next.status,\n      version: next.version,\n    );\n    return updatedStudent!;\n""",
)
replace_once(
    widget_test,
    """  String status = 'active',\n  int version = 3,\n}) {\n""",
    """  String status = 'active',\n  int version = 3,\n  String subjectStatus = 'active',\n}) {\n""",
)
replace_once(
    widget_test,
    """    subjectNames: ['数学'],\n    subjectServices: const [\n      OrganizationStudentSubjectService(\n        profileId: 'profile-1',\n        organizationSubjectId: 'subject-1',\n        subjectName: '数学',\n        status: 'active',\n        version: 1,\n      ),\n    ],\n""",
    """    subjectNames: subjectStatus == 'active' ? const ['数学'] : const [],\n    subjectServices: [\n      OrganizationStudentSubjectService(\n        profileId: 'profile-1',\n        organizationSubjectId: 'subject-1',\n        subjectName: '数学',\n        status: subjectStatus,\n        version: 1,\n      ),\n    ],\n""",
)
insert_before = """  testWidgets('admin edits student identity without changing lifecycle', (\n"""
archive_widget_tests = r'''  testWidgets(
    'temporary pause with active subject does not expose archive action',
    (tester) async {
      final repository = _FakeOrganizationManagementRepository(
        members: const [],
        invitations: const [],
        students: [_studentRecord(status: 'inactive')],
      );
      await _pumpManagement(tester, repository);
      await _selectManagementArea(tester, '学生');

      expect(find.text('暂不教学'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('student-archive-toggle-student-1')),
        findsNothing,
      );
      expect(find.text('恢复教学'), findsOneWidget);
    },
  );

  testWidgets(
    'manager archives only ended student service and unarchives to paused state',
    (tester) async {
      final repository = _FakeOrganizationManagementRepository(
        members: const [],
        invitations: const [],
        students: [
          _studentRecord(status: 'inactive', subjectStatus: 'inactive'),
        ],
      );
      await _pumpManagement(tester, repository);
      await _selectManagementArea(tester, '学生');

      final archive = find.byKey(
        const ValueKey<String>('student-archive-toggle-student-1'),
      );
      await tester.ensureVisible(archive);
      expect(find.text('归档学生'), findsOneWidget);
      await tester.tap(archive);
      await tester.pumpAndSettle();
      expect(find.text('归档 原学生？'), findsOneWidget);
      expect(
        find.text(
          '归档用于学生长期结束服务或离开机构后的历史保留。已有学科、Case、证据和历史记录不会删除；若只是暂时停课，请不要归档。',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, '确认归档'));
      await tester.pumpAndSettle();

      expect(repository.studentUpdateCount, 1);
      expect(repository.students.single.status, 'archived');
      expect(repository.students.single.version, 4);
      expect(repository.students.single.subjectServices.single.status, 'inactive');
      expect(find.text('已归档'), findsOneWidget);
      expect(find.text('恢复教学'), findsNothing);
      expect(find.text('取消归档'), findsOneWidget);

      final unarchive = find.byKey(
        const ValueKey<String>('student-archive-toggle-student-1'),
      );
      await tester.ensureVisible(unarchive);
      await tester.tap(unarchive);
      await tester.pumpAndSettle();
      expect(find.text('取消归档 原学生？'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '确认取消归档'));
      await tester.pumpAndSettle();

      expect(repository.studentUpdateCount, 2);
      expect(repository.students.single.status, 'inactive');
      expect(repository.students.single.version, 5);
      expect(repository.students.single.subjectServices.single.status, 'inactive');
      expect(find.text('暂不教学'), findsOneWidget);
      expect(find.text('恢复教学'), findsOneWidget);
      expect(find.text('归档学生'), findsOneWidget);
    },
  );

'''
replace_once(widget_test, insert_before, archive_widget_tests + insert_before)

# Repository copy test for new server errors.
repo_test = Path('test/cloud/organization_management_repository_test.dart')
anchor = """  test('maps duplicate student identity errors to actionable guidance', () {\n"""
extra = r'''  test('maps archive boundary errors to explicit lifecycle guidance', () {
    expect(
      organizationStudentLifecycleErrorMessage(
        const AuthException('student_archive_requires_paused'),
      ),
      '归档前请先暂停教学；临时停课不需要归档。',
    );
    expect(
      organizationStudentLifecycleErrorMessage(
        const AuthException('student_archive_active_subjects'),
      ),
      '这位学生仍有进行中的学科服务，请先逐科完成结束后再归档。',
    );
    expect(
      organizationStudentLifecycleErrorMessage(
        const AuthException('student_unarchive_requires_inactive'),
      ),
      '取消归档后必须先回到暂不教学状态，再决定是否恢复教学。',
    );
  });

'''
replace_once(repo_test, anchor, extra + anchor)
