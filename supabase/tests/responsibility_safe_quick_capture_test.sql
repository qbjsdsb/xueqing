begin;

select plan(12);

-- The seeded teacher is the active Lead for the seeded Profile.
select is(
  private.membership_has_current_teaching_responsibility_v2(
    '67000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000001'
  ),
  true,
  'the seeded Lead has strict current teaching responsibility'
);

-- Add a fictional organization owner with no Assignment or teaching scope.
insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
values (
  '2f210000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'responsibility.safe.owner@xueqing.test',
  crypt('XueqingDev-Only-123!', gen_salt('bf')),
  now(), now(), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  '', '', '', ''
);

insert into auth.sessions (id, user_id, created_at, updated_at)
values (
  '2f510000-0000-0000-0000-000000000001',
  '2f210000-0000-0000-0000-000000000001',
  now(), now()
);

insert into public.app_users (
  id,
  auth_provider,
  auth_subject_id,
  display_name,
  status
)
values (
  '2f110000-0000-0000-0000-000000000001',
  'supabase',
  '2f210000-0000-0000-0000-000000000001',
  '责任安全测试负责人',
  'active'
);

insert into public.identity_links (
  id,
  app_user_id,
  provider_key,
  issuer,
  external_subject,
  status
)
values (
  '2f610000-0000-0000-0000-000000000001',
  '2f110000-0000-0000-0000-000000000001',
  'supabase',
  'http://127.0.0.1:54321/auth/v1',
  '2f210000-0000-0000-0000-000000000001',
  'active'
);

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '2f310000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '2f110000-0000-0000-0000-000000000001',
  'active'
);

insert into public.membership_roles (
  organization_id,
  membership_id,
  role
)
values (
  '00000000-0000-0000-0000-000000000001',
  '2f310000-0000-0000-0000-000000000001',
  'org_owner'
);

select is(
  private.membership_has_current_teaching_responsibility_v2(
    '67000000-0000-0000-0000-000000000001',
    '2f310000-0000-0000-0000-000000000001'
  ),
  false,
  'organization supervision alone is not teaching responsibility'
);

select is(
  private.current_active_lead_membership_for_profile_v2(
    '67000000-0000-0000-0000-000000000001'
  )::text,
  '61000000-0000-0000-0000-000000000001',
  'the strict Lead resolver returns the seeded teacher'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '2f210000-0000-0000-0000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '2f210000-0000-0000-0000-000000000001',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '2f510000-0000-0000-0000-000000000001'
  )::text,
  true
);

select lives_ok(
  $$select public.quick_capture_case(
      '2f710000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      (select version from public.student_subject_profiles where id = '67000000-0000-0000-0000-000000000001'),
      'knowledge',
      '责任安全：管理者补充观察',
      '管理者可以补充真实观察，但不能因此接管教学责任。',
      timestamptz '2026-09-12 14:00:00+08',
      '复核时发现学生仍会遗漏单位。',
      '下次课由任课负责人复查',
      timestamptz '2026-09-13 18:00:00+08'
    )$$,
  'unassigned owner can capture an organization learning fact when a valid Lead exists'
);

select is(
  (
    select owner_membership_id::text
    from public.learning_cases
    where title = '责任安全：管理者补充观察'
  ),
  '61000000-0000-0000-0000-000000000001',
  'manager-created Case responsibility defaults to the active Lead'
);

select is(
  (
    select created_by_membership_id::text
    from public.learning_cases
    where title = '责任安全：管理者补充观察'
  ),
  '2f310000-0000-0000-0000-000000000001',
  'Case creation audit keeps the manager as the real actor'
);

select is(
  (
    select created_by_membership_id::text
    from public.case_evidence
    where learning_case_id = (
      select id from public.learning_cases
      where title = '责任安全：管理者补充观察'
    )
  ),
  '2f310000-0000-0000-0000-000000000001',
  'Evidence creation audit keeps the manager as the real actor'
);

select is(
  (
    select actor_membership_id::text
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases
      where title = '责任安全：管理者补充观察'
    )
      and event_type = 'case_created'
  ),
  '2f310000-0000-0000-0000-000000000001',
  'case_created event records the manager actor instead of the responsible teacher'
);

select is(
  (
    select assigned_membership_id::text
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases
      where title = '责任安全：管理者补充观察'
    )
      and status = 'pending'
      and is_primary
  ),
  '61000000-0000-0000-0000-000000000001',
  'manager-created next Action stays assigned to the active Lead'
);

reset role;

-- Simulate a responsibility gap without changing the Profile itself: the
-- teacher remains a valid collaborator, but there is no active Lead.
update public.student_teacher_assignments
set assignment_role = 'collaborator'
where id = '68000000-0000-0000-0000-000000000001';

select is(
  private.current_active_lead_membership_for_profile_v2(
    '67000000-0000-0000-0000-000000000001'
  ),
  null,
  'Lead resolver returns null during a responsibility gap'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '2f210000-0000-0000-0000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '2f210000-0000-0000-0000-000000000001',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '2f510000-0000-0000-0000-000000000001'
  )::text,
  true
);

select throws_ok(
  $$select public.quick_capture_case(
      '2f710000-0000-0000-0000-000000000002',
      '67000000-0000-0000-0000-000000000001',
      (select version from public.student_subject_profiles where id = '67000000-0000-0000-0000-000000000001'),
      'knowledge',
      '责任安全：不应静默归管理员',
      null,
      timestamptz '2026-09-12 15:00:00+08',
      '没有 Lead 时应先修复任课责任。',
      null,
      null
    )$$,
  'P0001',
  null,
  'manager capture is rejected when no valid teaching responsibility target exists'
);

select is(
  (
    select count(*)::integer
    from public.learning_cases
    where title = '责任安全：不应静默归管理员'
  ),
  0,
  'no manager-owned Case is created during a Lead responsibility gap'
);

select * from finish();
rollback;
