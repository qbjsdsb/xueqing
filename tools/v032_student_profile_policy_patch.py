from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    target = Path(path)
    text = target.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    target.write_text(text.replace(old, new, 1), encoding='utf-8')
    print(f'updated {label}')


# This patch is intentionally applied AFTER tools/v032_student_profile_gate.py.
# Product policy for v0.3.2:
# - student name + grade are the only basic profile fields that must be filled;
# - student code, class and campus stay optional;
# - changing grade/class/campus must not erase enrollment history.

# 1) New-student flow: grade belongs in the short required path, while code,
# class, campus and learning-background details remain behind the optional fold.
setup_path = 'lib/features/organization_management/presentation/organization_student_setup_dialog.dart'
replace_once(
    setup_path,
    "先填写学生姓名、服务学科和负责老师；保存后会一次完成建档和首个负责关系。其他资料需要时再展开填写。",
    "先填写学生姓名、年级、服务学科和负责老师；保存后会一次完成建档和首个负责关系。其他资料需要时再展开填写。",
    'student setup intro copy',
)

name_to_subject = """                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<OrganizationSetupSubject>(
"""
name_to_grade_subject = """                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  key: const Key('student-setup-grade-field'),
                  controller: _gradeController,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '年级 *',
                    hintText: '例如：初三',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return '请输入年级。';
                    if (text.length > 120) return '年级不能超过 120 个字符。';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<OrganizationSetupSubject>(
"""
replace_once(setup_path, name_to_subject, name_to_grade_subject, 'required grade field in student setup')

optional_grade = """                            const SizedBox(height: AppSpacing.xs),
                            TextFormField(
                              controller: _gradeController,
                              maxLength: 120,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: '年级',
                                hintText: '可选',
                              ),
                            ),
"""
replace_once(setup_path, optional_grade, '', 'remove grade from optional setup details')
replace_once(
    setup_path,
    '这些信息不是建档必填项；如果现在已知，可以一起保存。',
    '学生编号、班级、校区和学情背景都不是必填项；如果现在已知，可以一起保存。',
    'optional student setup explanation',
)

# 2) Existing-student profile edit: grade is required, code/class/campus stay
# optional. This RPC is new, so its client contract can be strict without
# breaking the already-released seven-argument lifecycle RPC.
edit_path = 'lib/features/organization_management/presentation/organization_student_edit_dialog.dart'
replace_once(edit_path, '  final String? grade;\n', '  final String grade;\n', 'profile draft grade type')
replace_once(
    edit_path,
    '          grade: _nullableText(_gradeController.text),\n',
    '          grade: _gradeController.text.trim(),\n',
    'profile draft grade normalization',
)
old_grade_field = """                TextFormField(
                  key: const Key('student-edit-grade-field'),
                  controller: _gradeController,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '年级',
                    hintText: '可选，例如 初三',
                  ),
                ),
"""
new_grade_field = """                TextFormField(
                  key: const Key('student-edit-grade-field'),
                  controller: _gradeController,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '年级 *',
                    hintText: '例如：初三',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return '请输入年级。';
                    if (text.length > 120) return '年级不能超过 120 个字符。';
                    return null;
                  },
                ),
"""
replace_once(edit_path, old_grade_field, new_grade_field, 'required grade field in profile edit')

repo_path = 'lib/cloud/organization_management_repository.dart'
interface_old = """  Future<OrganizationStudentUpdateResult> updateStudentProfile({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    String? grade,
    String? className,
    String? campus,
  });
"""
interface_new = """  Future<OrganizationStudentUpdateResult> updateStudentProfile({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    required String grade,
    String? className,
    String? campus,
  });
"""
replace_once(repo_path, interface_old, interface_new, 'profile repository grade contract')

impl_old = """  Future<OrganizationStudentUpdateResult> updateStudentProfile({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    String? grade,
    String? className,
    String? campus,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentId.trim().isEmpty ||
        expectedStudentVersion <= 0 ||
        name.trim().isEmpty) {
      throw ArgumentError('Student profile update identity cannot be empty.');
    }
"""
impl_new = """  Future<OrganizationStudentUpdateResult> updateStudentProfile({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    required String grade,
    String? className,
    String? campus,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentId.trim().isEmpty ||
        expectedStudentVersion <= 0 ||
        name.trim().isEmpty ||
        grade.trim().isEmpty) {
      throw ArgumentError('Student profile update identity cannot be empty.');
    }
"""
replace_once(repo_path, impl_old, impl_new, 'Supabase profile grade validation')
replace_once(
    repo_path,
    "        'p_grade': _nullableText(grade),\n",
    "        'p_grade': grade.trim(),\n",
    'Supabase profile grade parameter',
)
replace_once(
    repo_path,
    "    'invalid_student_profile_update_input' => '学生姓名、编号、年级、班级或校区不符合要求。',",
    "    'invalid_student_profile_update_input' => '学生姓名和年级必填；学生编号、班级和校区可以留空。',",
    'student profile validation copy',
)

# Keep the widget fake aligned with the stricter new repository method.
feature_test = 'test/features/organization_management_test.dart'
fake_signature_old = """  Future<OrganizationStudentUpdateResult> updateStudentProfile({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    String? grade,
    String? className,
    String? campus,
  }) async {
"""
fake_signature_new = """  Future<OrganizationStudentUpdateResult> updateStudentProfile({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    required String grade,
    String? className,
    String? campus,
  }) async {
"""
replace_once(feature_test, fake_signature_old, fake_signature_new, 'feature fake required grade')

# The add-student happy path must prove that blank grade blocks saving and that
# the manager can proceed as soon as grade is supplied.
add_test_old = """    expect(find.text('学生姓名 *'), findsOneWidget);
    expect(find.text('服务学科 *'), findsOneWidget);
    expect(find.text('负责老师 *'), findsOneWidget);
    expect(find.text('学生编号'), findsNothing);
    expect(find.text('年级'), findsNothing);
    expect(find.text('学情背景（可选）'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, '新学生');
    await tester.tap(find.byKey(const Key('student-setup-submit')));
    await tester.pumpAndSettle();

    expect(repository.studentCreateCount, 1);
"""
add_test_new = """    expect(find.text('学生姓名 *'), findsOneWidget);
    expect(find.text('年级 *'), findsOneWidget);
    expect(find.text('服务学科 *'), findsOneWidget);
    expect(find.text('负责老师 *'), findsOneWidget);
    expect(find.text('学生编号'), findsNothing);
    expect(find.text('学情背景（可选）'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, '新学生');
    await tester.tap(find.byKey(const Key('student-setup-submit')));
    await tester.pumpAndSettle();
    expect(repository.studentCreateCount, 0);
    expect(find.text('请输入年级。'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('student-setup-grade-field')),
      '初三',
    );
    await tester.tap(find.byKey(const Key('student-setup-submit')));
    await tester.pumpAndSettle();

    expect(repository.studentCreateCount, 1);
"""
replace_once(feature_test, add_test_old, add_test_new, 'student setup grade-required regression')

optional_test_old = """    final toggle = find.byKey(const Key('student-setup-optional-toggle'));
    expect(toggle, findsOneWidget);
    expect(find.text('学生编号'), findsNothing);
    expect(find.text('年级'), findsNothing);
    expect(find.text('班级'), findsNothing);
    expect(find.text('校区'), findsNothing);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text('学生编号'), findsOneWidget);
    expect(find.text('年级'), findsOneWidget);
    expect(find.text('班级'), findsOneWidget);
    expect(find.text('校区'), findsOneWidget);
"""
optional_test_new = """    final toggle = find.byKey(const Key('student-setup-optional-toggle'));
    expect(toggle, findsOneWidget);
    expect(find.text('年级 *'), findsOneWidget);
    expect(find.text('学生编号'), findsNothing);
    expect(find.text('班级'), findsNothing);
    expect(find.text('校区'), findsNothing);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text('年级 *'), findsOneWidget);
    expect(find.text('学生编号'), findsOneWidget);
    expect(find.text('班级'), findsOneWidget);
    expect(find.text('校区'), findsOneWidget);
"""
replace_once(feature_test, optional_test_old, optional_test_new, 'optional student setup fields regression')

# In the edit regression, first prove that grade is the one required school
# field, then clear class/campus and save successfully.
edit_test_marker = """    await tester.enterText(
      find.byKey(const Key('student-edit-name-field')),
      '更新学生',
    );
    await tester.enterText(
      find.byKey(const Key('student-edit-code-field')),
      'S-UPDATED',
    );
    await tester.enterText(
      find.byKey(const Key('student-edit-grade-field')),
      '初三',
    );
    await tester.enterText(
      find.byKey(const Key('student-edit-class-field')),
      '3班',
    );
    await tester.enterText(
      find.byKey(const Key('student-edit-campus-field')),
      '湖里校区',
    );
    await tester.tap(find.byKey(const Key('student-edit-submit')));
    await tester.pumpAndSettle();

    expect(repository.studentProfileUpdateCount, 1);
"""
edit_test_replacement = """    await tester.enterText(
      find.byKey(const Key('student-edit-name-field')),
      '更新学生',
    );
    await tester.enterText(
      find.byKey(const Key('student-edit-code-field')),
      'S-UPDATED',
    );
    await tester.enterText(
      find.byKey(const Key('student-edit-grade-field')),
      '',
    );
    await tester.tap(find.byKey(const Key('student-edit-submit')));
    await tester.pumpAndSettle();
    expect(repository.studentProfileUpdateCount, 0);
    expect(find.text('请输入年级。'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('student-edit-grade-field')),
      '初三',
    );
    await tester.enterText(
      find.byKey(const Key('student-edit-class-field')),
      '',
    );
    await tester.enterText(
      find.byKey(const Key('student-edit-campus-field')),
      '',
    );
    await tester.tap(find.byKey(const Key('student-edit-submit')));
    await tester.pumpAndSettle();

    expect(repository.studentProfileUpdateCount, 1);
"""
replace_once(feature_test, edit_test_marker, edit_test_replacement, 'student edit grade-required regression')
replace_once(
    feature_test,
    "    expect(repository.students.single.className, '3班');\n    expect(repository.students.single.campus, '湖里校区');",
    "    expect(repository.students.single.className, isNull);\n    expect(repository.students.single.campus, isNull);",
    'student edit optional class and campus regression',
)

# 3) Database contract: grade is required for the new profile command, while
# class/campus remain nullable. More importantly, school-context changes append
# a new enrollment slice instead of overwriting the previous slice.
migration_path = 'supabase/migrations/20260910140000_organization_student_profile_edit.sql'
replace_once(
    migration_path,
    "  v_enrollment_id uuid;\n  is_claimed boolean;",
    """  v_enrollment_id uuid;
  v_enrollment_grade text;
  v_enrollment_class_name text;
  v_enrollment_campus text;
  v_enrollment_starts_on date;
  v_enrollment_ends_on date;
  is_claimed boolean;""",
    'profile migration enrollment state declarations',
)
replace_once(
    migration_path,
    "    or (v_grade is not null and char_length(v_grade) > 120)\n",
    "    or v_grade is null\n    or char_length(v_grade) > 120\n",
    'profile migration required grade validation',
)
old_select = """  select enrollment.id
  into v_enrollment_id
  from public.student_enrollments as enrollment
"""
new_select = """  select
    enrollment.id,
    enrollment.grade,
    enrollment.class_name,
    enrollment.campus,
    enrollment.starts_on,
    enrollment.ends_on
  into
    v_enrollment_id,
    v_enrollment_grade,
    v_enrollment_class_name,
    v_enrollment_campus,
    v_enrollment_starts_on,
    v_enrollment_ends_on
  from public.student_enrollments as enrollment
"""
replace_once(migration_path, old_select, new_select, 'profile migration current enrollment snapshot')

old_enrollment_update = """  update public.student_enrollments
  set grade = v_grade,
      class_name = v_class_name,
      campus = v_campus
  where id = v_enrollment_id
    and organization_id = v_organization_id
    and student_id = p_student_id;

  command_result := jsonb_build_object(
"""
new_enrollment_update = """  if v_enrollment_grade is distinct from v_grade
    or v_enrollment_class_name is distinct from v_class_name
    or v_enrollment_campus is distinct from v_campus then
    -- Same-day/future rows are still editable planning/correction rows. Once a
    -- row represents a prior business day, preserve it and append a new slice.
    if v_enrollment_starts_on >= v_business_date then
      update public.student_enrollments
      set grade = v_grade,
          class_name = v_class_name,
          campus = v_campus
      where id = v_enrollment_id
        and organization_id = v_organization_id
        and student_id = p_student_id;
    else
      if v_enrollment_ends_on is null or v_enrollment_ends_on >= v_business_date then
        update public.student_enrollments
        set ends_on = v_business_date - 1
        where id = v_enrollment_id
          and organization_id = v_organization_id
          and student_id = p_student_id;
      end if;

      insert into public.student_enrollments (
        organization_id,
        student_id,
        grade,
        class_name,
        campus,
        starts_on,
        ends_on
      ) values (
        v_organization_id,
        p_student_id,
        v_grade,
        v_class_name,
        v_campus,
        v_business_date,
        case
          when v_enrollment_ends_on is not null
            and v_enrollment_ends_on >= v_business_date
            then v_enrollment_ends_on
          else null
        end
      );
    end if;
  end if;

  command_result := jsonb_build_object(
"""
replace_once(migration_path, old_enrollment_update, new_enrollment_update, 'append-only enrollment context transition')

# The original stale-version regression must still reach the version check now
# that null grade is invalid.
sql_test_path = 'supabase/tests/organization_student_profile_edit_test.sql'
replace_once(
    sql_test_path,
    "      '过期版本',\n      null,\n      null,\n      null,\n      null\n",
    "      '过期版本',\n      null,\n      '初三',\n      null,\n      null\n",
    'profile SQL stale-version grade input',
)

history_test = r'''begin;

select plan(6);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '20000000-0000-0000-0000-000000000001',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000001'
  )::text,
  true
);

select throws_ok(
  $$
    select public.update_organization_student_profile(
      '76100000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      1,
      '林雨桐',
      null,
      null,
      null,
      null
    )
  $$,
  'P0001',
  'invalid_student_profile_update_input',
  'grade is required by the new student profile command'
);

select lives_ok(
  $$
    select public.update_organization_student_profile(
      '76100000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      1,
      '林雨桐',
      null,
      '初三',
      null,
      null
    )
  $$,
  'manager can update required grade while leaving class and campus empty'
);

reset role;

select is(
  (
    select student.status || '|' || student.version::text
    from public.students as student
    where student.id = '30000000-0000-0000-0000-000000000001'
  ),
  'active|2',
  'profile edit keeps lifecycle status and increments one aggregate version'
);

select is(
  (
    select enrollment.grade || '|' || enrollment.class_name || '|' || enrollment.campus
    from public.student_enrollments as enrollment
    where enrollment.id = '66000000-0000-0000-0000-000000000001'
  ),
  '初二|A班|厦门校区',
  'previous enrollment context is preserved instead of overwritten'
);

select is(
  (
    select ends_on
    from public.student_enrollments
    where id = '66000000-0000-0000-0000-000000000001'
  ),
  (
    select (now() at time zone organization.time_zone)::date - 1
    from public.organizations as organization
    where organization.id = '00000000-0000-0000-0000-000000000001'
  ),
  'previous enrollment slice closes on the day before the new context'
);

select is(
  (
    select count(*)::int
    from public.student_enrollments as enrollment
    join public.organizations as organization
      on organization.id = enrollment.organization_id
    where enrollment.organization_id = '00000000-0000-0000-0000-000000000001'
      and enrollment.student_id = '30000000-0000-0000-0000-000000000001'
      and enrollment.grade = '初三'
      and enrollment.class_name is null
      and enrollment.campus is null
      and enrollment.starts_on = (now() at time zone organization.time_zone)::date
      and enrollment.ends_on is null
  ),
  1,
  'new enrollment slice stores required grade and keeps optional fields nullable'
);

select * from finish();

rollback;
'''
history_test_path = Path('supabase/tests/organization_student_profile_history_test.sql')
if history_test_path.exists():
    raise SystemExit(f'{history_test_path} already exists')
history_test_path.write_text(history_test, encoding='utf-8')
print('created enrollment-history regression')
