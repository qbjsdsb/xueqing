begin;

select plan(11);

select is(
  (
    select count(*)::int
    from pg_class
    join pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'teacher_workspace_context'
      and pg_class.relkind = 'v'
  ),
  1,
  'Teacher Workspace context read model view exists'
);

select is(
  (
    select 'security_invoker=true' = any(coalesce(pg_class.reloptions, '{}'::text[]))
    from pg_class
    join pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'teacher_workspace_context'
      and pg_class.relkind = 'v'
  ),
  true,
  'context view invokes underlying RLS'
);

select is(
  has_table_privilege('anon', 'public.teacher_workspace_context', 'select'),
  false,
  'anon cannot read the context view'
);
select is(
  has_table_privilege(
    'authenticated',
    'public.teacher_workspace_context',
    'select'
  ),
  true,
  'authenticated can reach the context read model'
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
    select count(*)::int
    from public.teacher_workspace_context
    where id = '00000000-0000-0000-0000-000000000001'
  ),
  1,
  'Teacher A can read the context for Organization A'
);
select is(
  (
    select time_zone
    from public.teacher_workspace_context
    where id = '00000000-0000-0000-0000-000000000001'
  ),
  'Asia/Shanghai',
  'the context exposes the organization timezone'
);
select is(
  (
    select business_date
    from public.teacher_workspace_context
    where id = '00000000-0000-0000-0000-000000000001'
  ),
  (now() at time zone 'Asia/Shanghai')::date,
  'the context exposes the server business date'
);
select is(
  (
    select count(*)::int
    from public.teacher_workspace_context
    where id = '00000000-0000-0000-0000-000000000002'
  ),
  0,
  'Teacher A cannot read the other organization context'
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

select is(
  (
    select count(*)::int
    from public.teacher_workspace_context
    where id = '00000000-0000-0000-0000-000000000001'
  ),
  0,
  'Teacher B cannot read Organization A context'
);
select is(
  (
    select count(*)::int
    from public.teacher_workspace_context
    where id = '00000000-0000-0000-0000-000000000002'
  ),
  1,
  'Teacher B can read the context for Organization B'
);

select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-000000000003',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '20000000-0000-0000-0000-000000000003',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000003'
  )::text,
  true
);

select is(
  (select count(*)::int from public.teacher_workspace_context),
  0,
  'a user without membership cannot read organization context'
);

select * from finish();
rollback;
