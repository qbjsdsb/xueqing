begin;

select plan(11);

select is(
  (
    select count(*)::int
    from pg_class
    join pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'teacher_workspace_student_enrollments'
      and pg_class.relkind = 'v'
  ),
  1,
  'Teacher Workspace enrollment read model view exists'
);

select is(
  (
    select 'security_invoker=true' = any(coalesce(pg_class.reloptions, '{}'::text[]))
    from pg_class
    join pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'teacher_workspace_student_enrollments'
      and pg_class.relkind = 'v'
  ),
  true,
  'enrollment view invokes underlying RLS'
);

select is(
  has_table_privilege(
    'anon',
    'public.teacher_workspace_student_enrollments',
    'select'
  ),
  false,
  'anon cannot read the enrollment view'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.teacher_workspace_student_enrollments',
    'select'
  ),
  true,
  'authenticated can reach the enrollment read model'
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
)
values
  (
    '69000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '未来年级',
    '边界测试',
    '厦门校区',
    (now() at time zone 'Asia/Shanghai')::date + 1,
    null
  ),
  (
    '69000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '今天年级',
    '边界测试',
    '厦门校区',
    (now() at time zone 'Asia/Shanghai')::date,
    (now() at time zone 'Asia/Shanghai')::date
  ),
  (
    '69000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '过去年级',
    '边界测试',
    '厦门校区',
    (now() at time zone 'Asia/Shanghai')::date - 14,
    (now() at time zone 'Asia/Shanghai')::date - 1
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

select is(
  (
    select is_current
    from public.teacher_workspace_student_enrollments
    where id = '69000000-0000-0000-0000-000000000001'
  ),
  false,
  'an enrollment starting tomorrow is not current'
);

select is(
  (
    select is_current
    from public.teacher_workspace_student_enrollments
    where id = '69000000-0000-0000-0000-000000000002'
  ),
  true,
  'an enrollment ending today remains current'
);

select is(
  (
    select is_current
    from public.teacher_workspace_student_enrollments
    where id = '69000000-0000-0000-0000-000000000003'
  ),
  false,
  'an enrollment ending yesterday is not current'
);

select is(
  (
    select business_date
    from public.teacher_workspace_student_enrollments
    where id = '69000000-0000-0000-0000-000000000002'
  ),
  (now() at time zone 'Asia/Shanghai')::date,
  'the view exposes the organization business date'
);

select is(
  (
    select count(*)::int
    from public.teacher_workspace_student_enrollments
    where id in (
      '69000000-0000-0000-0000-000000000001',
      '69000000-0000-0000-0000-000000000002',
      '69000000-0000-0000-0000-000000000003'
    )
  ),
  3,
  'Teacher A can read assigned enrollment rows through the view'
);

reset role;
set local role anon;

select throws_ok(
  $$select * from public.teacher_workspace_student_enrollments$$,
  '42501',
  null,
  'anonymous requests cannot read the enrollment view'
);

reset role;
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

select is(
  (
    select count(*)::int
    from public.teacher_workspace_student_enrollments
    where organization_id = '00000000-0000-0000-0000-000000000001'
  ),
  0,
  'Teacher B cannot see Teacher A enrollment rows through the view'
);

select * from finish();
rollback;
