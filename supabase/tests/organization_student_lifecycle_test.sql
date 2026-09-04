begin;

select plan(37);

select is(
  to_regprocedure('public.list_organization_students(uuid)') is not null,
  true,
  'student roster function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure('public.list_organization_students(uuid)')
  ),
  true,
  'student roster function is security definer'
);

select is(
  to_regprocedure(
    'public.update_organization_student(uuid,uuid,uuid,integer,text,text,text)'
  ) is not null,
  true,
  'student lifecycle function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.update_organization_student(uuid,uuid,uuid,integer,text,text,text)'
    )
  ),
  true,
  'student lifecycle function is security definer'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_organization_students(uuid)',
    'execute'
  ),
  false,
  'anon cannot list organization students'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.list_organization_students(uuid)',
    'execute'
  ),
  true,
  'authenticated can list organization students through the guarded command'
);

select is(
  has_function_privilege(
    'anon',
    'public.update_organization_student(uuid,uuid,uuid,integer,text,text,text)',
    'execute'
  ),
  false,
  'anon cannot update organization students'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.update_organization_student(uuid,uuid,uuid,integer,text,text,text)',
    'execute'
  ),
  true,
  'authenticated can update organization students through the guarded command'
);

select is(
  has_table_privilege('authenticated', 'public.students', 'update'),
  false,
  'authenticated cannot update student roots directly'
);

select is(
  has_table_privilege('authenticated', 'public.student_enrollments', 'update'),
  false,
  'authenticated cannot update enrollments directly'
);

reset role;
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
      'xueqing.student_list',
      (
        select coalesce(jsonb_agg(item), '[]'::jsonb)::text
        from public.list_organization_students(
          '00000000-0000-0000-0000-000000000001'
        ) as item
      ),
      true
    )
  $$,
  'an organization manager can load the complete student roster'
);

select is(
  jsonb_array_length(current_setting('xueqing.student_list')::jsonb),
  1,
  'student roster contains the organization student'
);

select is(
  (
    select item ->> 'student_name'
    from jsonb_array_elements(current_setting('xueqing.student_list')::jsonb) as item
  ),
  '林雨桐',
  'student roster returns the student name'
);

select is(
  (
    select jsonb_array_length(item -> 'subjects')
    from jsonb_array_elements(current_setting('xueqing.student_list')::jsonb) as item
  ),
  1,
  'student roster includes active subject profiles'
);

select is(
  (
    select item ->> 'grade' || '|' || item ->> 'class_name'
    from jsonb_array_elements(current_setting('xueqing.student_list')::jsonb) as item
  ),
  '初二|A班',
  'student roster includes current enrollment context'
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
    select public.list_organization_students(
      '00000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  null,
  'a teacher cannot list another organization roster'
);

select throws_ok(
  $$
    select public.update_organization_student(
      '74000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      1,
      '越权修改',
      null,
      'active'
    )
  $$,
  'P0001',
  null,
  'a teacher cannot update another organization roster'
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
    select public.update_organization_student(
      '74000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      1,
      '无状态学生',
      null,
      null
    )
  $$,
  'P0001',
  null,
  'null lifecycle status is rejected'
);

select lives_ok(
  $$
    select set_config(
      'xueqing.student_update',
      public.update_organization_student(
        '74000000-0000-0000-0000-000000000003',
        '00000000-0000-0000-0000-000000000001',
        '30000000-0000-0000-0000-000000000001',
        1,
        '林雨桐（档案更新）',
        'S-UPDATED',
        'archived'
      )::text,
      true
    )
  $$,
  'a manager can archive and correct a student atomically'
);

select is(
  current_setting('xueqing.student_update')::jsonb ->> 'student_name',
  '林雨桐（档案更新）',
  'student update returns the normalized name'
);

select is(
  current_setting('xueqing.student_update')::jsonb ->> 'status',
  'archived',
  'student update returns the archived status'
);

select is(
  (current_setting('xueqing.student_update')::jsonb ->> 'version')::int,
  2,
  'student update increments the optimistic version'
);

select is(
  (
    select student.name || '|' || student.student_code || '|' ||
      student.status || '|' || student.version::text
    from public.students as student
    where student.id =
      '30000000-0000-0000-0000-000000000001'
  ),
  '林雨桐（档案更新）|S-UPDATED|archived|2',
  'student root stores lifecycle changes and version'
);

select isnt(
  (
    select archived_at
    from public.students
    where id = '30000000-0000-0000-0000-000000000001'
  ),
  null,
  'archiving records an archive timestamp'
);

select is(
  (
    select count(*)::int
    from public.students
    where id = '30000000-0000-0000-0000-000000000001'
  ),
  0,
  'archived students remain hidden from teaching student reads'
);

select is(
  (
    select count(*)::int
    from public.student_subject_profiles
    where student_id = '30000000-0000-0000-0000-000000000001'
  ),
  0,
  'archived student profiles remain hidden while history is retained'
);

select is(
  (
    select count(*)::int
    from public.student_enrollments
    where student_id = '30000000-0000-0000-0000-000000000001'
  ),
  0,
  'archived enrollments remain hidden from teaching reads'
);

select is(
  (
    select item ->> 'status'
    from public.list_organization_students(
      '00000000-0000-0000-0000-000000000001'
    ) as item
  ),
  'archived',
  'manager roster keeps archived students for lifecycle administration'
);

select lives_ok(
  $$
    select public.update_organization_student(
      '74000000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      1,
      'different retry name',
      'DIFFERENT',
      'inactive'
    )
  $$,
  'repeating the lifecycle operation returns its committed result'
);

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where operation_id =
      '74000000-0000-0000-0000-000000000003'
      and command_type = 'update_organization_student'
      and target_type = 'student'
      and result ->> 'student_name' = '林雨桐（档案更新）'
      and committed_at is not null
  ),
  1,
  'lifecycle retry keeps one committed operation receipt'
);

select lives_ok(
  $$
    select set_config(
      'xueqing.student_restore',
      public.update_organization_student(
        '74000000-0000-0000-0000-000000000004',
        '00000000-0000-0000-0000-000000000001',
        '30000000-0000-0000-0000-000000000001',
        2,
        '林雨桐',
        'S-RESTORED',
        'active'
      )::text,
      true
    )
  $$,
  'a manager can restore an archived student with the next version'
);

select is(
  current_setting('xueqing.student_restore')::jsonb ->> 'status',
  'active',
  'restoring a student returns active status'
);

select is(
  (current_setting('xueqing.student_restore')::jsonb ->> 'version')::int,
  3,
  'restoring a student returns the next optimistic version'
);

select is(
  current_setting('xueqing.student_restore')::jsonb ->> 'student_code',
  'S-RESTORED',
  'restoring a student returns the corrected student code'
);

select is(
  (
    select student.status || '|' || student.version::text || '|' ||
      case when student.archived_at is null then 'clear' else 'set' end
    from public.students as student
    where student.id =
      '30000000-0000-0000-0000-000000000001'
  ),
  'active|3|clear',
  'restoring clears archive timestamp and increments version'
);

select is(
  (
    select count(*)::int
    from public.students
    where id = '30000000-0000-0000-0000-000000000001'
  ),
  1,
  'restored active student is visible again to teaching reads'
);

select throws_ok(
  $$
    select public.update_organization_student(
      '74000000-0000-0000-0000-000000000005',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      2,
      '过期版本',
      null,
      'inactive'
    )
  $$,
  'P0001',
  null,
  'stale student version is rejected'
);

select * from finish();

rollback;