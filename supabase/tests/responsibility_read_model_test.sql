begin;

select plan(21);

select is(
  (
    select count(*)::integer
    from pg_class
    join pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'teacher_workspace_personal_assignments'
      and pg_class.relkind = 'v'
  ),
  1,
  'Personal Assignment read model exists'
);

select is(
  (
    select 'security_invoker=true' = any(coalesce(pg_class.reloptions, '{}'::text[]))
    from pg_class
    join pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'teacher_workspace_personal_assignments'
      and pg_class.relkind = 'v'
  ),
  true,
  'Personal Assignment view invokes underlying RLS'
);

select is(
  has_table_privilege(
    'anon',
    'public.teacher_workspace_personal_assignments',
    'select'
  ),
  false,
  'anon cannot read Personal Assignments'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.teacher_workspace_personal_assignments',
    'select'
  ),
  true,
  'authenticated users can reach the guarded Personal Assignment view'
);

select is(
  has_function_privilege(
    'anon',
    'public.get_workspace_responsibility_context(uuid)',
    'execute'
  ),
  false,
  'anon cannot call responsibility context RPC'
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
    select count(*)::integer
    from public.teacher_workspace_personal_assignments
    where organization_id = '00000000-0000-0000-0000-000000000001'
  ),
  1,
  'manager who also truly teaches gets exactly their own current Assignment'
);

select is(
  (
    select count(*)::integer
    from public.teacher_workspace_personal_assignments
    where organization_id = '00000000-0000-0000-0000-000000000002'
  ),
  0,
  'Personal Projection never crosses organizations'
);

select is(
  (
    select membership_id::text
    from public.teacher_workspace_personal_assignments
    where organization_id = '00000000-0000-0000-0000-000000000001'
    limit 1
  ),
  '61000000-0000-0000-0000-000000000001',
  'Personal Assignment is bound to the current member, not manager-wide visibility'
);

select is(
  public.get_workspace_responsibility_context(
    '00000000-0000-0000-0000-000000000001'
  ) ->> 'current_membership_id',
  '61000000-0000-0000-0000-000000000001',
  'responsibility context exposes the current membership'
);

select is(
  jsonb_array_length(
    public.get_workspace_responsibility_context(
      '00000000-0000-0000-0000-000000000001'
    ) -> 'personal_assignments'
  ),
  1,
  'responsibility context exposes one Personal Assignment for seeded Teacher A'
);

select is(
  (
    public.get_workspace_responsibility_context(
      '00000000-0000-0000-0000-000000000001'
    ) -> 'personal_assignments' -> 0 ->> 'assignment_role'
  ),
  'lead',
  'Personal Assignment keeps the real assignment role'
);

-- Existing user 3 has a live identity/session but no organization membership.
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
  (select count(*)::integer from public.teacher_workspace_personal_assignments),
  0,
  'user without membership has no Personal Assignments'
);

select throws_ok(
  $$select public.get_workspace_responsibility_context(
      '00000000-0000-0000-0000-000000000001'
    )$$,
  'P0001',
  'organization_membership_required',
  'responsibility context fails closed without organization membership'
);

-- Turn user 3 into a pure manager. The existing manager-capability trigger also
-- grants teacher capability, but there is deliberately no teaching scope or
-- Student Teacher Assignment yet.
reset role;

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '7f300000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000003',
  'active'
);

insert into public.membership_roles (
  id,
  organization_id,
  membership_id,
  role
)
values (
  '7f400000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '7f300000-0000-0000-0000-000000000001',
  'org_admin'
);

set local role authenticated;
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
  (select count(*)::integer from public.teacher_workspace_personal_assignments),
  0,
  'pure manager stays out of Personal Projection even with teacher capability'
);

select is(
  jsonb_array_length(
    public.get_workspace_responsibility_context(
      '00000000-0000-0000-0000-000000000001'
    ) -> 'personal_assignments'
  ),
  0,
  'pure manager responsibility context has zero Personal Assignments'
);

select is(
  public.get_workspace_responsibility_context(
    '00000000-0000-0000-0000-000000000001'
  ) ->> 'current_membership_id',
  '7f300000-0000-0000-0000-000000000001',
  'pure manager still gets their real current organization membership'
);

select throws_ok(
  $$select public.get_workspace_responsibility_context(
      '00000000-0000-0000-0000-000000000002'
    )$$,
  'P0001',
  'organization_membership_required',
  'responsibility context cannot be requested for another organization'
);

-- Give the same manager an explicit teaching scope plus collaborator
-- Assignment. Only now may they enter Personal Projection.
reset role;

insert into public.membership_subject_scopes (
  id,
  organization_id,
  membership_id,
  organization_subject_id,
  scope_kind,
  status,
  active_from
)
values (
  '7f500000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '7f300000-0000-0000-0000-000000000001',
  '64000000-0000-0000-0000-000000000001',
  'teaching',
  'active',
  date '2026-01-01'
);

insert into public.student_teacher_assignments (
  id,
  organization_id,
  student_subject_profile_id,
  membership_id,
  assignment_role,
  status,
  active_from
)
values (
  '7f600000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000001',
  '7f300000-0000-0000-0000-000000000001',
  'collaborator',
  'active',
  date '2026-01-01'
);

set local role authenticated;
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
  (select count(*)::integer from public.teacher_workspace_personal_assignments),
  1,
  'manager enters Personal Projection only after a real current Assignment exists'
);

select is(
  (
    select assignment_role
    from public.teacher_workspace_personal_assignments
    limit 1
  ),
  'collaborator',
  'collaborator Assignment is a valid Personal teaching responsibility'
);

reset role;
update public.student_teacher_assignments
set active_to =
  (now() at time zone 'Asia/Shanghai')::date - 1
where id = '7f600000-0000-0000-0000-000000000001';

set local role authenticated;
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
  (select count(*)::integer from public.teacher_workspace_personal_assignments),
  0,
  'expired Assignment immediately leaves Personal Projection'
);

reset role;
update public.student_teacher_assignments
set active_to = null
where id = '7f600000-0000-0000-0000-000000000001';
update public.membership_subject_scopes
set active_to =
  (now() at time zone 'Asia/Shanghai')::date - 1
where id = '7f500000-0000-0000-0000-000000000001';

set local role authenticated;
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
  (select count(*)::integer from public.teacher_workspace_personal_assignments),
  0,
  'expired teaching scope immediately leaves Personal Projection'
);

select * from finish();
rollback;
