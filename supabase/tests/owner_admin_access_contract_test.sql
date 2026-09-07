begin;

select plan(10);

-- Fictional admin-only actor in Organization A.
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
  '21000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'admin-only@xueqing.test',
  crypt('XueqingDev-Only-Admin-123!', gen_salt('bf')),
  now(),
  now(),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  '',
  '',
  '',
  ''
);

insert into public.app_users (
  id, auth_provider, auth_subject_id, display_name, status
)
values (
  '12000000-0000-0000-0000-000000000001',
  'supabase',
  '21000000-0000-0000-0000-000000000001',
  '仅管理员测试账号',
  'active'
);

insert into public.identity_links (
  id, app_user_id, provider_key, issuer, external_subject, status
)
values (
  '61000000-0000-0000-0000-000000000101',
  '12000000-0000-0000-0000-000000000001',
  'supabase',
  'http://127.0.0.1:54321/auth/v1',
  '21000000-0000-0000-0000-000000000001',
  'active'
);

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status,
  onboarding_required,
  version
)
values (
  '61000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000001',
  '12000000-0000-0000-0000-000000000001',
  'active',
  false,
  1
);

insert into public.membership_roles (
  id, organization_id, membership_id, role
)
values (
  '62000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000101',
  'org_admin'
);

insert into auth.sessions (id, user_id, created_at, updated_at)
values (
  '51000000-0000-0000-0000-000000000101',
  '21000000-0000-0000-0000-000000000001',
  now(),
  now()
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '21000000-0000-0000-0000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '21000000-0000-0000-0000-000000000001',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '51000000-0000-0000-0000-000000000101'
  )::text,
  true
);

select is(
  (
    select count(*)::int
    from public.student_subject_profiles
    where id = '67000000-0000-0000-0000-000000000001'
  ),
  1,
  'RLS exposes an organization profile to an admin without a teacher assignment'
);

select is(
  (
    select count(*)::int
    from public.students
    where id = '30000000-0000-0000-0000-000000000001'
  ),
  1,
  'RLS exposes an organization student to an admin'
);

select ok(
  (
    select count(*)
    from public.learning_cases
    where student_subject_profile_id =
      '67000000-0000-0000-0000-000000000001'
  ) > 0,
  'an admin can read organization Learning Cases'
);

select throws_ok(
  $$
    select public.create_organization_invitation(
      '00000000-0000-0000-0000-000000000001',
      'admin-must-not-invite@xueqing.test',
      'teacher'
    )
  $$,
  'P0001',
  'organization_owner_required',
  'an admin cannot invite a member'
);

select throws_ok(
  $$
    select public.update_organization_membership_status(
      '92000000-0000-0000-0000-000000000101',
      '00000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      1,
      'disabled'
    )
  $$,
  'P0001',
  'organization_owner_required',
  'an admin cannot disable or restore another member'
);

reset role;
set local role service_role;

select throws_ok(
  $$
    select private.prepare_member_credential_reissue(
      '21000000-0000-0000-0000-000000000001',
      '51000000-0000-0000-0000-000000000101',
      '00000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  'organization_owner_required',
  'an admin cannot reissue another member credential through the service path'
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
    select public.create_organization_invitation(
      '00000000-0000-0000-0000-000000000001',
      'owner-can-invite@xueqing.test',
      'teacher'
    )
  $$,
  'an owner can invite a member'
);

select is(
  (
    select count(*)::int
    from public.student_subject_profiles
    where id = '67000000-0000-0000-0000-000000000001'
  ),
  1,
  'an owner keeps full organization learning access'
);

select ok(
  (
    select count(*)
    from public.learning_cases
    where student_subject_profile_id =
      '67000000-0000-0000-0000-000000000001'
  ) > 0,
  'an owner can read organization Learning Cases'
);

select is(
  (
    select count(*)::int
    from public.student_subject_profiles
    where id = '67000000-0000-0000-0000-000000000002'
  ),
  0,
  'organization boundaries still prevent an owner from reading another organization'
);

select * from finish();

rollback;
