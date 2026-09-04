begin;

select plan(43);

select is(
  to_regprocedure(
    'public.list_organization_setup_options(uuid)'
  ) is not null,
  true,
  'setup options function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.list_organization_setup_options(uuid)'
    )
  ),
  true,
  'setup options function is security definer'
);

select is(
  to_regprocedure(
    'public.create_organization_student(uuid,uuid,text,text,text,text,text,uuid,uuid,date,text,text,text)'
  ) is not null,
  true,
  'student setup function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.create_organization_student(uuid,uuid,text,text,text,text,text,uuid,uuid,date,text,text,text)'
    )
  ),
  true,
  'student setup function is security definer'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_organization_setup_options(uuid)',
    'execute'
  ),
  false,
  'anon cannot list organization setup options'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.list_organization_setup_options(uuid)',
    'execute'
  ),
  true,
  'authenticated can list setup options through the guarded command'
);

select is(
  has_function_privilege(
    'anon',
    'public.create_organization_student(uuid,uuid,text,text,text,text,text,uuid,uuid,date,text,text,text)',
    'execute'
  ),
  false,
  'anon cannot create students'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.create_organization_student(uuid,uuid,text,text,text,text,text,uuid,uuid,date,text,text,text)',
    'execute'
  ),
  true,
  'authenticated can create students through the guarded command'
);

select is(
  has_table_privilege('authenticated', 'public.students', 'insert'),
  false,
  'authenticated cannot insert students directly'
);

select is(
  has_table_privilege('authenticated', 'public.student_enrollments', 'insert'),
  false,
  'authenticated cannot insert enrollments directly'
);

select is(
  has_table_privilege('authenticated', 'public.student_subject_profiles', 'insert'),
  false,
  'authenticated cannot insert subject profiles directly'
);

select is(
  has_table_privilege('authenticated', 'public.student_teacher_assignments', 'insert'),
  false,
  'authenticated cannot insert teacher assignments directly'
);

select is(
  has_table_privilege('authenticated', 'public.membership_subject_scopes', 'insert'),
  false,
  'authenticated cannot insert subject scopes directly'
);

reset role;

-- Teacher A already has the fictional org_admin/org_owner seed roles.
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

select lives_ok(
  $$
    select set_config(
      'xueqing.setup_options',
      public.list_organization_setup_options(
        '00000000-0000-0000-0000-000000000001'
      )::text,
      true
    )
  $$,
  'an organization manager can load setup options'
);

select is(
  jsonb_array_length(
    current_setting('xueqing.setup_options')::jsonb -> 'subjects'
  ),
  1,
  'setup options contain the active organization subject'
);

select is(
  jsonb_array_length(
    current_setting('xueqing.setup_options')::jsonb -> 'teachers'
  ),
  1,
  'setup options contain the active teacher membership'
);

select is(
  current_setting('xueqing.setup_options')::jsonb
    -> 'teachers' -> 0 -> 'organization_subject_ids' ->> 0,
  '64000000-0000-0000-0000-000000000001',
  'setup options expose only the teacher effective subject scopes'
);

select lives_ok(
  $$
    select set_config(
      'xueqing.student_setup',
      public.create_organization_student(
        '73000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000001',
        '机构初始化学生',
        'S-001',
        '初二',
        'A班',
        '厦门校区',
        '64000000-0000-0000-0000-000000000001',
        '61000000-0000-0000-0000-000000000001',
        null,
        '函数基础需要持续巩固',
        '愿意复盘错题',
        '每周一次'
      )::text,
      true
    )
  $$,
  'an organization manager can atomically create a student service profile'
);

select isnt(
  current_setting('xueqing.student_setup')::jsonb ->> 'student_id',
  null,
  'student setup returns the created student id'
);

select is(
  current_setting('xueqing.student_setup')::jsonb ->> 'student_name',
  '机构初始化学生',
  'student setup returns the normalized student name'
);

select is(
  current_setting('xueqing.student_setup')::jsonb ->> 'subject_name',
  '数学',
  'student setup returns the selected subject'
);

select is(
  current_setting('xueqing.student_setup')::jsonb ->> 'teacher_display_name',
  '王老师',
  'student setup returns the selected teacher'
);

select is(
  current_setting('xueqing.student_setup')::jsonb ->> 'starts_on',
  ((now() at time zone 'Asia/Shanghai')::date)::text,
  'a missing start date uses the organization business date'
);

select is(
  (
    select student_code
    from public.students
    where name = '机构初始化学生'
  ),
  'S-001',
  'student root stores the optional student code'
);

select is(
  (
    select enrollment.grade || '|' || enrollment.class_name || '|' ||
      enrollment.campus
    from public.student_enrollments as enrollment
    join public.students as student
      on student.id = enrollment.student_id
    where student.name = '机构初始化学生'
  ),
  '初二|A班|厦门校区',
  'student enrollment stores school context'
);

select is(
  (
    select profile.positioning
    from public.student_subject_profiles as profile
    join public.students as student
      on student.id = profile.student_id
    where student.name = '机构初始化学生'
  ),
  '函数基础需要持续巩固',
  'subject profile stores learning positioning'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments as assignment
    join public.student_subject_profiles as profile
      on profile.id = assignment.student_subject_profile_id
    join public.students as student
      on student.id = profile.student_id
    where student.name = '机构初始化学生'
      and assignment.assignment_role = 'lead'
      and assignment.status = 'active'
  ),
  1,
  'student setup creates one active lead assignment'
);

select is(
  (
    select count(*)::int
    from public.membership_subject_scopes
    where organization_id =
      '00000000-0000-0000-0000-000000000001'
      and membership_id =
        '61000000-0000-0000-0000-000000000001'
      and organization_subject_id =
        '64000000-0000-0000-0000-000000000001'
      and scope_kind = 'teaching'
      and status = 'active'
  ),
  1,
  'student setup reuses one active teaching scope'
);

select is(
  (
    select version
    from public.membership_subject_scopes
    where id = '65000000-0000-0000-0000-000000000001'
  ),
  1,
  'student setup does not rewrite the existing teaching scope'
);

reset role;

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where organization_id =
        '00000000-0000-0000-0000-000000000001'
      and operation_id =
        '73000000-0000-0000-0000-000000000001'
      and command_type = 'create_organization_student'
      and target_type = 'organization'
      and result is not null
      and committed_at is not null
  ),
  1,
  'student setup commits one operation receipt'
);

set local role authenticated;

select lives_ok(
  $$
    select public.create_organization_student(
      '73000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      'different name on retry',
      null,
      null,
      null,
      null,
      '64000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      null,
      null,
      null,
      null
    )
  $$,
  'repeating the same operation id returns the committed result'
);

select is(
  (
    select count(*)::int
    from public.students
    where organization_id =
        '00000000-0000-0000-0000-000000000001'
      and name = '机构初始化学生'
  ),
  1,
  'retrying student setup does not create a duplicate student'
);

reset role;

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where organization_id =
        '00000000-0000-0000-0000-000000000001'
      and operation_id =
        '73000000-0000-0000-0000-000000000001'
  ),
  1,
  'retrying student setup keeps one operation receipt'
);

update public.membership_subject_scopes
set status = 'ended',
    active_to = greatest(active_from, current_date)
where id = '65000000-0000-0000-0000-000000000001';

set local role authenticated;

select set_config(
  'xueqing.setup_options_without_scope',
  public.list_organization_setup_options(
    '00000000-0000-0000-0000-000000000001'
  )::text,
  true
);

select is(
  jsonb_array_length(
    current_setting('xueqing.setup_options_without_scope')::jsonb
      -> 'teachers' -> 0 -> 'organization_subject_ids'
  ),
  0,
  'an ended teaching scope is not offered for student setup'
);

select throws_ok(
  $$
    select public.create_organization_student(
      '73000000-0000-0000-0000-000000000005',
      '00000000-0000-0000-0000-000000000001',
      '教学范围已结束',
      null,
      null,
      null,
      null,
      '64000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      null,
      null,
      null,
      null
    )
  $$,
  'P0001',
  'teacher_subject_scope_required',
  'student setup rejects a teacher whose teaching scope has ended'
);

select is(
  (
    select count(*)::int
    from public.students
    where organization_id =
        '00000000-0000-0000-0000-000000000001'
      and name = '教学范围已结束'
  ),
  0,
  'a rejected teaching scope creates no student data'
);

select throws_ok(
  $$
    select public.create_organization_student(
      '73000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000001',
      '跨机构学科',
      null,
      null,
      null,
      null,
      '64000000-0000-0000-0000-000000000002',
      '61000000-0000-0000-0000-000000000001',
      null,
      null,
      null,
      null
    )
  $$,
  'P0001',
  null,
  'a manager cannot use another organization subject'
);

select throws_ok(
  $$
    select public.create_organization_student(
      '73000000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000001',
      '跨机构老师',
      null,
      null,
      null,
      null,
      '64000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000002',
      null,
      null,
      null,
      null
    )
  $$,
  'P0001',
  null,
  'a manager cannot use another organization teacher membership'
);

select is(
  (
    select count(*)::int
    from public.students
    where organization_id =
      '00000000-0000-0000-0000-000000000001'
      and name in ('跨机构学科', '跨机构老师')
  ),
  0,
  'rejected cross-organization setup creates no students'
);

select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-000000000002',
  true
);

select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '20000000-0000-0000-0000-000000000002',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000002'
  )::text,
  true
);

select throws_ok(
  $$
    select public.list_organization_setup_options(
      '00000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  null,
  'a teacher without management role cannot load setup options'
);

select throws_ok(
  $$
    select public.create_organization_student(
      '73000000-0000-0000-0000-000000000004',
      '00000000-0000-0000-0000-000000000001',
      '越权学生',
      null,
      null,
      null,
      null,
      '64000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      null,
      null,
      null,
      null
    )
  $$,
  'P0001',
  null,
  'a teacher cannot create a student'
);

select throws_ok(
  $$
    insert into public.students (
      organization_id,
      name
    )
    values (
      '00000000-0000-0000-0000-000000000002',
      'direct insert'
    )
  $$,
  '42501',
  null,
  'authenticated clients cannot insert student roots directly'
);

select throws_ok(
  $$
    insert into public.student_subject_profiles (
      organization_id,
      student_id,
      organization_subject_id
    )
    values (
      '00000000-0000-0000-0000-000000000002',
      '30000000-0000-0000-0000-000000000002',
      '64000000-0000-0000-0000-000000000002'
    )
  $$,
  '42501',
  null,
  'authenticated clients cannot insert profiles directly'
);

select * from finish();

rollback;
