begin;

select plan(13);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_app_meta_data,
  raw_user_meta_data, confirmation_token, email_change,
  email_change_token_new, recovery_token
)
values
  (
    '21100000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'lifecycle-admin@xueqing.test',
    crypt('XueqingDev-Only-Admin-456!', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb, '', '', '', ''
  ),
  (
    '21100000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'active-teacher-target@xueqing.test',
    crypt('XueqingDev-Only-Teacher-456!', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb, '', '', '', ''
  );

insert into public.app_users (
  id, auth_provider, auth_subject_id, display_name, status
)
values
  (
    '12100000-0000-0000-0000-000000000001',
    'supabase',
    '21100000-0000-0000-0000-000000000001',
    '管理员账号生命周期测试',
    'active'
  ),
  (
    '12100000-0000-0000-0000-000000000002',
    'supabase',
    '21100000-0000-0000-0000-000000000002',
    '纯老师生命周期目标',
    'active'
  );

insert into public.identity_links (
  id, app_user_id, provider_key, issuer, external_subject, status
)
values
  (
    '61100000-0000-0000-0000-000000000001',
    '12100000-0000-0000-0000-000000000001',
    'supabase',
    'http://127.0.0.1:54321/auth/v1',
    '21100000-0000-0000-0000-000000000001',
    'active'
  ),
  (
    '61100000-0000-0000-0000-000000000002',
    '12100000-0000-0000-0000-000000000002',
    'supabase',
    'http://127.0.0.1:54321/auth/v1',
    '21100000-0000-0000-0000-000000000002',
    'active'
  );

insert into public.organization_memberships (
  id, organization_id, app_user_id, status, onboarding_required, version
)
values
  (
    '61100000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000001',
    '12100000-0000-0000-0000-000000000001',
    'active', false, 1
  ),
  (
    '61100000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000001',
    '12100000-0000-0000-0000-000000000002',
    'active', false, 1
  );

insert into public.membership_roles (
  id, organization_id, membership_id, role
)
values
  (
    '62100000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000001',
    '61100000-0000-0000-0000-000000000101',
    'org_admin'
  ),
  (
    '62100000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000001',
    '61100000-0000-0000-0000-000000000102',
    'teacher'
  );

insert into auth.sessions (id, user_id, created_at, updated_at)
values (
  '51100000-0000-0000-0000-000000000101',
  '21100000-0000-0000-0000-000000000001',
  now(), now()
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '21100000-0000-0000-0000-000000000001', true);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '21100000-0000-0000-0000-000000000001',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '51100000-0000-0000-0000-000000000101'
  )::text,
  true
);

select lives_ok(
  $$select set_config(
      'xueqing.admin_teacher_invite',
      public.create_organization_invitation(
        '00000000-0000-0000-0000-000000000001',
        'new-teacher-by-admin@xueqing.test',
        'teacher'
      )::text,
      true
    )$$,
  'admin can create a teacher invitation'
);

select is(
  current_setting('xueqing.admin_teacher_invite')::jsonb ->> 'status',
  'pending',
  'admin teacher invitation is immediately pending'
);

select lives_ok(
  $$select set_config(
      'xueqing.admin_owner_nomination',
      public.create_organization_invitation(
        '00000000-0000-0000-0000-000000000001',
        'owner-nominated-by-admin@xueqing.test',
        'org_owner'
      )::text,
      true
    )$$,
  'admin can nominate an owner for owner approval'
);

select is(
  current_setting('xueqing.admin_owner_nomination')::jsonb ->> 'status',
  'pending_owner_approval',
  'admin owner nomination cannot bypass owner approval'
);

select throws_ok(
  $$select public.create_organization_invitation(
      '00000000-0000-0000-0000-000000000001',
      'admin-must-not-create-admin@xueqing.test',
      'org_admin'
    )$$,
  'P0001',
  'role_not_allowed',
  'admin cannot directly invite another admin'
);

select throws_ok(
  $$select public.create_organization_invitation(
      '00000000-0000-0000-0000-000000000001',
      'teacher.b@xueqing.test',
      'teacher'
    )$$,
  'P0001',
  'user_already_member_elsewhere',
  'cross-organization active account is rejected before creating an invitation'
);

select is(
  (
    select count(*)::int
    from public.organization_invitations
    where organization_id = '00000000-0000-0000-0000-000000000001'
      and email = 'teacher.b@xueqing.test'
      and status in ('pending', 'pending_owner_approval')
  ),
  0,
  'cross-organization preflight leaves no doomed pending invitation'
);

select lives_ok(
  $$select public.revoke_organization_invitation(
      (current_setting('xueqing.admin_teacher_invite')::jsonb ->> 'id')::uuid
    )$$,
  'admin can revoke a pending teacher invitation'
);

select lives_ok(
  $$select public.update_organization_membership_status(
      '92100000-0000-0000-0000-000000000101',
      '00000000-0000-0000-0000-000000000001',
      '61100000-0000-0000-0000-000000000102',
      1,
      'disabled'
    )$$,
  'admin can disable a pure teacher membership'
);

select is(
  (
    select status
    from public.organization_memberships
    where id = '61100000-0000-0000-0000-000000000102'
  ),
  'disabled',
  'teacher membership is disabled by the admin command'
);

select lives_ok(
  $$select public.update_organization_membership_status(
      '92100000-0000-0000-0000-000000000102',
      '00000000-0000-0000-0000-000000000001',
      '61100000-0000-0000-0000-000000000102',
      2,
      'active'
    )$$,
  'admin can restore a disabled pure teacher membership'
);

select is(
  (
    select status
    from public.organization_memberships
    where id = '61100000-0000-0000-0000-000000000102'
  ),
  'active',
  'teacher membership is restored by the admin command'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_app_meta_data,
  raw_user_meta_data, confirmation_token, email_change,
  email_change_token_new, recovery_token
)
values (
  '21100000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'provision-teacher-by-admin@xueqing.test',
  crypt('XueqingDev-Only-NewTeacher-456!', gen_salt('bf')),
  now(), now(), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb, '', '', '', ''
);

select set_config(
  'xueqing.provision_teacher_invite',
  public.create_organization_invitation(
    '00000000-0000-0000-0000-000000000001',
    'provision-teacher-by-admin@xueqing.test',
    'teacher'
  )::text,
  true
);

reset role;
set local role service_role;

select lives_ok(
  $$select set_config(
      'xueqing.provision_teacher_result',
      private.provision_organization_member_from_auth(
        '21100000-0000-0000-0000-000000000001',
        '51100000-0000-0000-0000-000000000101',
        'http://127.0.0.1:54321/auth/v1',
        (current_setting('xueqing.provision_teacher_invite')::jsonb ->> 'id')::uuid,
        '21100000-0000-0000-0000-000000000003',
        '管理员开通的老师'
      )::text,
      true
    )$$,
  'trusted provisioning path allows an admin to provision a teacher'
);

select lives_ok(
  $$select private.prepare_member_credential_reissue(
      '21100000-0000-0000-0000-000000000001',
      '51100000-0000-0000-0000-000000000101',
      '00000000-0000-0000-0000-000000000001',
      (current_setting('xueqing.provision_teacher_result')::jsonb ->> 'membership_id')::uuid
    )$$,
  'trusted credential path allows an admin to reissue an onboarding teacher credential'
);

select * from finish();
rollback;