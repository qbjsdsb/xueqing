begin;

select plan(14);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_app_meta_data,
  raw_user_meta_data, confirmation_token, email_change,
  email_change_token_new, recovery_token
)
values (
  '21000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'admin-only@xueqing.test',
  crypt('XueqingDev-Only-Admin-123!', gen_salt('bf')),
  now(), now(), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb, '', '', '', ''
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
  id, organization_id, app_user_id, status, onboarding_required, version
)
values (
  '61000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000001',
  '12000000-0000-0000-0000-000000000001',
  'active', false, 1
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
  now(), now()
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '21000000-0000-0000-0000-000000000001', true);
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
  'an admin can read organization learning profiles without a teacher assignment'
);

select lives_ok(
  $$select public.quick_capture_case(
      '93000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1,
      'knowledge',
      '管理员机构级学情测试',
      '仅用于虚构权限回归。',
      timestamptz '2026-09-07 18:00:00+08',
      '管理员可记录机构学情',
      '继续跟进',
      timestamptz '2026-09-08 18:00:00+08'
    )$$,
  'an admin can write organization learning data without a teacher assignment'
);

select is(
  (
    select count(*)::int
    from public.learning_cases
    where title = '管理员机构级学情测试'
  ),
  1,
  'an admin can read the Case created through the public learning command'
);

select lives_ok(
  $$select public.update_organization_member_display_name(
      '00000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      '管理员维护的示例姓名'
    )$$,
  'an admin can maintain a member display name without changing membership lifecycle'
);

select is(
  (
    select listed.member ->> 'display_name'
    from public.list_organization_members(
      '00000000-0000-0000-0000-000000000001'
    ) as listed(member)
    where listed.member ->> 'membership_id' =
      '61000000-0000-0000-0000-000000000001'
  ),
  '管理员维护的示例姓名',
  'member name maintenance persists through the public manager read model'
);

select throws_ok(
  $$select public.create_organization_invitation(
      '00000000-0000-0000-0000-000000000001',
      'admin-must-not-invite@xueqing.test',
      'teacher'
    )$$,
  'P0001',
  'organization_owner_required',
  'an admin cannot invite a member'
);

select throws_ok(
  $$select public.update_organization_membership_status(
      '92000000-0000-0000-0000-000000000101',
      '00000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      1,
      'disabled'
    )$$,
  'P0001',
  'organization_owner_required',
  'an admin cannot disable or restore another member'
);

reset role;
set local role service_role;

select throws_ok(
  $$select private.prepare_member_credential_reissue(
      '21000000-0000-0000-0000-000000000001',
      '51000000-0000-0000-0000-000000000101',
      '00000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001'
    )$$,
  'P0001',
  'organization_owner_required',
  'an admin cannot reissue another member credential through the trusted service path'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000001', true);
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
    from public.student_subject_profiles
    where id = '67000000-0000-0000-0000-000000000001'
  ),
  1,
  'an owner keeps organization-wide learning read access'
);

select lives_ok(
  $$select set_config(
      'xueqing.owner_test_invite',
      public.create_organization_invitation(
        '00000000-0000-0000-0000-000000000001',
        'owner-can-invite@xueqing.test',
        'teacher'
      )::text,
      true
    )$$,
  'an owner can invite a member'
);

select is(
  (
    select count(*)::int
    from public.learning_cases
    where title = '管理员机构级学情测试'
  ),
  1,
  'an owner can read organization learning data created by an admin'
);

select is(
  (
    select count(*)::int
    from public.student_subject_profiles
    where id = '67000000-0000-0000-0000-000000000002'
  ),
  0,
  'organization boundaries still block an owner from another organization'
);

select set_config('request.jwt.claim.sub', '21000000-0000-0000-0000-000000000001', true);
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

select throws_ok(
  $$select public.revoke_organization_invitation(
      (current_setting('xueqing.owner_test_invite')::jsonb ->> 'id')::uuid
    )$$,
  'P0001',
  'organization_owner_required',
  'an admin cannot revoke an owner-created invitation'
);

select is(
  (
    select count(*)::int
    from public.learning_cases
    where title = '管理员机构级学情测试'
  ),
  1,
  'member-account restrictions do not remove admin learning access'
);

select * from finish();
rollback;
