begin;

select plan(21);

select is(
  to_regprocedure(
    'public.set_organization_student_subject_lead(uuid,uuid,uuid,integer,uuid)'
  ) is not null,
  true,
  'set student subject Lead function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.set_organization_student_subject_lead(uuid,uuid,uuid,integer,uuid)'
    )
  ),
  false,
  'public Lead repair function is security-invoker'
);

select is(
  has_function_privilege(
    'anon',
    'public.set_organization_student_subject_lead(uuid,uuid,uuid,integer,uuid)',
    'execute'
  ),
  false,
  'anon cannot set a student subject Lead'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.set_organization_student_subject_lead(uuid,uuid,uuid,integer,uuid)',
    'execute'
  ),
  true,
  'authenticated may call the manager-gated Lead repair command'
);

reset role;

-- Create a genuine responsibility gap: the subject service remains active while
-- its old Lead Assignment has ended. Existing teaching records deliberately
-- keep pointing at the old teacher to prove this repair does not rewrite them.
update public.student_teacher_assignments
set
  status = 'ended',
  active_to = '2026-09-11',
  ended_at = '2026-09-11T12:00:00Z'
where id = '68000000-0000-0000-0000-000000000001';

insert into public.learning_cases (
  id,
  organization_id,
  student_subject_profile_id,
  owner_membership_id,
  case_type,
  title,
  first_observed_at,
  created_by_app_user_id,
  created_by_membership_id
)
values (
  '8e300000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  'knowledge',
  '历史问题不应被补主责操作偷偷改写',
  '2026-09-11T01:00:00Z',
  '10000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);

insert into public.case_actions (
  id,
  organization_id,
  learning_case_id,
  assigned_membership_id,
  action_type,
  title,
  is_primary,
  status
)
values (
  '8e400000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '8e300000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  'verify',
  '历史待办仍由原负责人负责',
  true,
  'pending'
);

insert into public.case_events (
  id,
  organization_id,
  learning_case_id,
  event_type,
  actor_app_user_id,
  actor_membership_id,
  metadata
)
values (
  '8e500000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '8e300000-0000-0000-0000-000000000001',
  'case_created',
  '10000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  '{}'::jsonb
);

-- Valid replacement teacher with the active teaching scope for the profile.
insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '8e000000-0000-0000-0000-000000000001',
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
  '8e100000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '8e000000-0000-0000-0000-000000000001',
  'teacher'
);

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
  '8e200000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '8e000000-0000-0000-0000-000000000001',
  '64000000-0000-0000-0000-000000000001',
  'teaching',
  'active',
  '2026-01-01'
);

-- A second active teacher intentionally has no Math teaching scope.
insert into public.app_users (
  id,
  auth_provider,
  auth_subject_id,
  display_name,
  status
)
values (
  '8e010000-0000-0000-0000-000000000001',
  'supabase',
  '8e020000-0000-0000-0000-000000000001',
  '无范围老师',
  'active'
);

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '8e000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  '8e010000-0000-0000-0000-000000000001',
  'active'
);

insert into public.membership_roles (
  id,
  organization_id,
  membership_id,
  role
)
values (
  '8e100000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  '8e000000-0000-0000-0000-000000000002',
  'teacher'
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

select throws_ok(
  $$
    select public.set_organization_student_subject_lead(
      '8e600000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      (select version + 1 from public.student_subject_profiles
       where id = '67000000-0000-0000-0000-000000000001'),
      '8e000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  'student_subject_profile_version_conflict',
  'stale profile version fails closed'
);

select throws_ok(
  $$
    select public.set_organization_student_subject_lead(
      '8e600000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      (select version from public.student_subject_profiles
       where id = '67000000-0000-0000-0000-000000000001'),
      '8e000000-0000-0000-0000-000000000002'
    )
  $$,
  'P0001',
  'teacher_subject_scope_required',
  'teacher without the subject scope cannot become Lead'
);

select lives_ok(
  $$
    select set_config(
      'xueqing.set_lead_result',
      public.set_organization_student_subject_lead(
        '8e600000-0000-0000-0000-000000000003',
        '00000000-0000-0000-0000-000000000001',
        '67000000-0000-0000-0000-000000000001',
        (select version from public.student_subject_profiles
         where id = '67000000-0000-0000-0000-000000000001'),
        '8e000000-0000-0000-0000-000000000001'
      )::text,
      true
    )
  $$,
  'manager can establish the missing Lead'
);

select is(
  current_setting('xueqing.set_lead_result')::jsonb ->> 'teacher_membership_id',
  '8e000000-0000-0000-0000-000000000001',
  'result identifies the new responsible teacher'
);

select is(
  current_setting('xueqing.set_lead_result')::jsonb ->> 'assignment_role',
  'lead',
  'result explicitly records Lead responsibility'
);

reset role;

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments
    where student_subject_profile_id = '67000000-0000-0000-0000-000000000001'
      and assignment_role = 'lead'
      and status = 'active'
  ),
  1,
  'repair creates exactly one active Lead Assignment'
);

select is(
  (
    select active_from
    from public.student_teacher_assignments
    where student_subject_profile_id = '67000000-0000-0000-0000-000000000001'
      and assignment_role = 'lead'
      and status = 'active'
  ),
  (
    select (now() at time zone time_zone)::date
    from public.organizations
    where id = '00000000-0000-0000-0000-000000000001'
  ),
  'new Lead starts on the organization business date'
);

select is(
  (select owner_membership_id::text from public.learning_cases
   where id = '8e300000-0000-0000-0000-000000000001'),
  '61000000-0000-0000-0000-000000000001',
  'setting a missing Lead does not rewrite an existing Case owner'
);

select is(
  (select assigned_membership_id::text from public.case_actions
   where id = '8e400000-0000-0000-0000-000000000001'),
  '61000000-0000-0000-0000-000000000001',
  'setting a missing Lead does not rewrite an existing Action assignee'
);

select is(
  (select actor_membership_id::text from public.case_events
   where id = '8e500000-0000-0000-0000-000000000001'),
  '61000000-0000-0000-0000-000000000001',
  'historical Actor remains unchanged'
);

set local role authenticated;

select lives_ok(
  $$
    select public.set_organization_student_subject_lead(
      '8e600000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      (select version from public.student_subject_profiles
       where id = '67000000-0000-0000-0000-000000000001'),
      '8e000000-0000-0000-0000-000000000001'
    )
  $$,
  'same operation id safely returns the committed result'
);

reset role;

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments
    where student_subject_profile_id = '67000000-0000-0000-0000-000000000001'
      and assignment_role = 'lead'
      and status = 'active'
  ),
  1,
  'idempotent retry does not duplicate the Lead Assignment'
);

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where organization_id = '00000000-0000-0000-0000-000000000001'
      and operation_id = '8e600000-0000-0000-0000-000000000003'
      and command_type = 'set_organization_student_subject_lead'
      and committed_at is not null
  ),
  1,
  'Lead repair commits one operation receipt'
);

set local role authenticated;

select throws_ok(
  $$
    select public.set_organization_student_subject_lead(
      '8e600000-0000-0000-0000-000000000004',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      (select version from public.student_subject_profiles
       where id = '67000000-0000-0000-0000-000000000001'),
      '8e000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  'student_subject_lead_already_assigned',
  'a second operation cannot create another active Lead'
);

select throws_ok(
  $$
    select public.set_organization_student_subject_lead(
      '8e600000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      (select version from public.student_subject_profiles
       where id = '67000000-0000-0000-0000-000000000001'),
      '8e000000-0000-0000-0000-000000000002'
    )
  $$,
  'P0001',
  'operation_id_reuse_conflict',
  'same operation id cannot be replayed with a different teacher'
);

-- A plain teacher cannot use the organization repair command even if the
-- target profile already has a Lead: authorization is checked first.
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

select throws_ok(
  $$
    select public.set_organization_student_subject_lead(
      '8e600000-0000-0000-0000-000000000005',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      (select version from public.student_subject_profiles
       where id = '67000000-0000-0000-0000-000000000001'),
      '8e000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  'organization_manager_required',
  'plain teacher cannot establish organization responsibility'
);

reset role;

select is(
  (
    select count(*)::int
    from public.learning_cases
    where id = '8e300000-0000-0000-0000-000000000001'
  ),
  1,
  'repair keeps the existing teaching history intact'
);

select * from finish();
rollback;
