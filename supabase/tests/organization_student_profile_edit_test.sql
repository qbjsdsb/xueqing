begin;

select plan(20);

select is(
  to_regprocedure(
    'public.update_organization_student_profile(uuid,uuid,uuid,integer,text,text,text,text,text)'
  ) is not null,
  true,
  'student profile function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.update_organization_student_profile(uuid,uuid,uuid,integer,text,text,text,text,text)'
    )
  ),
  false,
  'student profile public function is security-invoker wrapper'
);

select is(
  has_function_privilege(
    'anon',
    'public.update_organization_student_profile(uuid,uuid,uuid,integer,text,text,text,text,text)',
    'execute'
  ),
  false,
  'anon cannot update student profiles'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.update_organization_student_profile(uuid,uuid,uuid,integer,text,text,text,text,text)',
    'execute'
  ),
  true,
  'authenticated can reach the guarded student profile command'
);

select is(
  to_regprocedure(
    'public.update_organization_student(uuid,uuid,uuid,integer,text,text,text)'
  ) is not null,
  true,
  'legacy seven-argument student lifecycle RPC remains available'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.update_organization_student(uuid,uuid,uuid,integer,text,text,text)',
    'execute'
  ),
  true,
  'legacy student lifecycle RPC remains callable by authenticated clients'
);

reset role;

insert into public.student_enrollments (
  id,
  organization_id,
  student_id,
  grade,
  class_name,
  campus,
  starts_on,
  ends_on
) values (
  '76000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  '历史年级',
  '历史班级',
  '历史校区',
  date '2025-01-01',
  date '2025-06-30'
);

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
      'xueqing.student_profile_update',
      public.update_organization_student_profile(
        '76000000-0000-0000-0000-000000000010',
        '00000000-0000-0000-0000-000000000001',
        '30000000-0000-0000-0000-000000000001',
        1,
        '林雨桐（资料更新）',
        'S-PROFILE',
        '初三',
        '3班',
        '湖里校区'
      )::text,
      true
    )
  $$,
  'manager can atomically update student profile data'
);

select is(
  current_setting('xueqing.student_profile_update')::jsonb ->> 'status',
  'active',
  'profile edit preserves teaching lifecycle status'
);

select is(
  (current_setting('xueqing.student_profile_update')::jsonb ->> 'version')::int,
  2,
  'profile edit increments the student optimistic version'
);

select is(
  current_setting('xueqing.student_profile_update')::jsonb ->> 'grade',
  '初三',
  'profile edit returns the corrected grade'
);

reset role;

select is(
  (
    select student.name || '|' || student.student_code || '|' ||
      student.status || '|' || student.version::text
    from public.students as student
    where student.id = '30000000-0000-0000-0000-000000000001'
  ),
  '林雨桐（资料更新）|S-PROFILE|active|2',
  'student root stores identity correction without lifecycle drift'
);

select is(
  (
    select enrollment.grade || '|' || enrollment.class_name || '|' || enrollment.campus
    from public.student_enrollments as enrollment
    where enrollment.student_id = '30000000-0000-0000-0000-000000000001'
      and enrollment.id <> '76000000-0000-0000-0000-000000000001'
    order by enrollment.starts_on desc, enrollment.id desc
    limit 1
  ),
  '初三|3班|湖里校区',
  'roster-visible current enrollment stores the corrected school context'
);

select is(
  (
    select enrollment.grade || '|' || enrollment.class_name || '|' || enrollment.campus
    from public.student_enrollments as enrollment
    where enrollment.id = '76000000-0000-0000-0000-000000000001'
  ),
  '历史年级|历史班级|历史校区',
  'profile correction does not rewrite historical enrollment context'
);

set local role authenticated;
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
    select public.update_organization_student_profile(
      '76000000-0000-0000-0000-000000000011',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      2,
      '越权学生',
      null,
      '越权年级',
      null,
      null
    )
  $$,
  'P0001',
  null,
  'teacher cannot use manager student profile command'
);

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
      '76000000-0000-0000-0000-000000000012',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      1,
      '过期版本',
      null,
      '初三',
      null,
      null
    )
  $$,
  'P0001',
  null,
  'stale student version is rejected'
);

select lives_ok(
  $$
    select public.update_organization_student_profile(
      '76000000-0000-0000-0000-000000000010',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      1,
      '不同重试值',
      'DIFFERENT',
      '不同年级',
      '不同班级',
      '不同校区'
    )
  $$,
  'retry of a committed profile operation returns the original result'
);

reset role;

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where operation_id = '76000000-0000-0000-0000-000000000010'
      and command_type = 'update_organization_student_profile'
      and target_type = 'student'
      and result ->> 'student_name' = '林雨桐（资料更新）'
      and result ->> 'grade' = '初三'
      and committed_at is not null
  ),
  1,
  'profile retry keeps one committed operation receipt'
);

select is(
  (
    select count(*)::int
    from public.students
    where id = '30000000-0000-0000-0000-000000000001'
      and name = '林雨桐（资料更新）'
      and student_code = 'S-PROFILE'
      and status = 'active'
      and version = 2
  ),
  1,
  'retry does not apply the alternate profile payload'
);

select is(
  (
    select count(*)::int
    from public.student_enrollments
    where student_id = '30000000-0000-0000-0000-000000000001'
      and grade = '初三'
      and class_name = '3班'
      and campus = '湖里校区'
  ),
  1,
  'only the intended enrollment context carries the corrected profile'
);

select is(
  has_table_privilege('authenticated', 'public.student_enrollments', 'update'),
  false,
  'authenticated still cannot bypass the guarded RPC with direct enrollment updates'
);

select * from finish();

rollback;
