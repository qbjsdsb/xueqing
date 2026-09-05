begin;

select plan(12);

select is(
  (
    select count(*)::int
    from pg_class
    join pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'teacher_workspace_action_queue'
      and pg_class.relkind = 'v'
  ),
  1,
  'Teacher Workspace action queue view exists'
);

select is(
  (
    select 'security_invoker=true' = any(coalesce(pg_class.reloptions, '{}'::text[]))
    from pg_class
    join pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'teacher_workspace_action_queue'
      and pg_class.relkind = 'v'
  ),
  true,
  'Teacher Workspace view invokes underlying RLS'
);

select is(
  has_table_privilege(
    'anon',
    'public.teacher_workspace_action_queue',
    'select'
  ),
  false,
  'anon cannot read the Teacher Workspace view'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.teacher_workspace_action_queue',
    'select'
  ),
  true,
  'authenticated can reach the read-only Teacher Workspace view'
);

set local role anon;

select throws_ok(
  $$select * from public.teacher_workspace_action_queue$$,
  '42501',
  null,
  'anonymous requests are rejected before view rows are exposed'
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

select is(
  (select count(*)::int from public.teacher_workspace_action_queue),
  0,
  'Teacher A starts with an empty current Action queue'
);

select lives_ok(
  $$select public.quick_capture_case(
      '72000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1,
      'knowledge',
      'Workspace read model test case',
      'Fictional read-model test data.',
      now(),
      'Fictional read-model evidence.',
      '待补充下一步',
      null
    )$$,
  'Teacher A can create a fictional Case for the read-model test'
);

select is(
  (
    select count(*)::int
    from public.teacher_workspace_action_queue
    where title = '待补充下一步'
  ),
  1,
  'the queue exposes the new pending primary Action'
);

select is(
  (
    select due_bucket
    from public.teacher_workspace_action_queue
    where title = '待补充下一步'
  ),
  'undated',
  'an Action without a date stays in the undated bucket'
);

select is(
  (
    select business_due_date is null
    from public.teacher_workspace_action_queue
    where title = '待补充下一步'
  ),
  true,
  'an undated Action has no business due date'
);

select is(
  (
    select case_status
    from public.teacher_workspace_action_queue
    where title = '待补充下一步'
  ),
  'new',
  'the queue preserves the Case status separately from Action status'
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
  (select count(*)::int from public.teacher_workspace_action_queue),
  0,
  'Teacher B cannot see Teacher A queue rows through the view'
);

select * from finish();
rollback;
