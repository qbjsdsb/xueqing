begin;

select plan(10);

-- Seeded Teacher A is the active Lead for the only readable org-1 Profile.
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
  jsonb_array_length(
    public.get_workspace_responsibility_context(
      '00000000-0000-0000-0000-000000000001'
    )->'profile_responsibilities'
  ),
  1,
  'teacher responsibility snapshot contains exactly the Profile they may read'
);

select is(
  public.get_workspace_responsibility_context(
    '00000000-0000-0000-0000-000000000001'
  )->'profile_responsibilities'->0->>'profile_id',
  '67000000-0000-0000-0000-000000000001',
  'Profile responsibility keeps stable Profile identity'
);

select is(
  public.get_workspace_responsibility_context(
    '00000000-0000-0000-0000-000000000001'
  )->'profile_responsibilities'->0->>'lead_membership_id',
  '61000000-0000-0000-0000-000000000001',
  'teacher sees the server-authoritative current Lead membership'
);

reset role;

-- Turn the existing live user-without-membership into a pure manager. They have
-- no teaching scope or Assignment, so Personal remains empty while organization
-- supervision may read the Profile responsibility fact.
insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '8f300000-0000-0000-0000-000000000001',
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
  '8f400000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '8f300000-0000-0000-0000-000000000001',
  'org_admin'
);

-- Add an unrelated active teacher membership. No Profile, Case, Action, event,
-- or Lead references this membership; the minimal directory must not expose it.
insert into public.app_users (
  id,
  auth_provider,
  auth_subject_id,
  display_name,
  status
)
values (
  '8f100000-0000-0000-0000-000000000002',
  'fixture',
  'unrelated-profile-responsibility-reader',
  '无关测试老师',
  'active'
);

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '8f300000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  '8f100000-0000-0000-0000-000000000002',
  'active'
);

insert into public.membership_roles (
  id,
  organization_id,
  membership_id,
  role
)
values (
  '8f400000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  '8f300000-0000-0000-0000-000000000002',
  'teacher'
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
  jsonb_array_length(
    public.get_workspace_responsibility_context(
      '00000000-0000-0000-0000-000000000001'
    )->'personal_assignments'
  ),
  0,
  'pure manager still has no Personal teaching Assignment'
);

select is(
  jsonb_array_length(
    public.get_workspace_responsibility_context(
      '00000000-0000-0000-0000-000000000001'
    )->'profile_responsibilities'
  ),
  1,
  'manager organization supervision sees the readable Profile responsibility'
);

select is(
  public.get_workspace_responsibility_context(
    '00000000-0000-0000-0000-000000000001'
  )->'profile_responsibilities'->0->>'lead_membership_id',
  '61000000-0000-0000-0000-000000000001',
  'manager gets the same current Lead truth as the assigned teacher'
);

select is(
  (
    select item->>'display_name'
    from jsonb_array_elements(
      public.get_workspace_responsibility_context(
        '00000000-0000-0000-0000-000000000001'
      )->'member_display_names'
    ) as item
    where item->>'membership_id' = '61000000-0000-0000-0000-000000000001'
  ),
  '王老师',
  'current Lead display name is included for Organization responsibility UI'
);

select is(
  (
    select count(*)::integer
    from jsonb_array_elements(
      public.get_workspace_responsibility_context(
        '00000000-0000-0000-0000-000000000001'
      )->'member_display_names'
    ) as item
    where item->>'membership_id' = '8f300000-0000-0000-0000-000000000002'
  ),
  0,
  'minimal member directory does not expose an unrelated organization teacher'
);

reset role;

-- A Profile with no active Lead must stay visible to a manager but explicitly
-- report a responsibility gap instead of choosing a collaborator/manager.
update public.student_teacher_assignments
set assignment_role = 'collaborator'
where id = '68000000-0000-0000-0000-000000000001';

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
  public.get_workspace_responsibility_context(
    '00000000-0000-0000-0000-000000000001'
  )->'profile_responsibilities'->0->>'lead_membership_id',
  null,
  'missing Lead is represented explicitly as null instead of a fallback owner'
);

reset role;

-- Assignment role alone is insufficient: an expired teaching scope also makes
-- the current Lead invalid while manager supervision can still read the Profile.
update public.student_teacher_assignments
set assignment_role = 'lead'
where id = '68000000-0000-0000-0000-000000000001';

update public.membership_subject_scopes
set active_to = (now() at time zone 'Asia/Shanghai')::date - 1
where id = '65000000-0000-0000-0000-000000000001';

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
  public.get_workspace_responsibility_context(
    '00000000-0000-0000-0000-000000000001'
  )->'profile_responsibilities'->0->>'lead_membership_id',
  null,
  'expired Lead teaching scope produces an explicit responsibility gap'
);

select * from finish();
rollback;
