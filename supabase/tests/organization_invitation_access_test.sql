begin;

select plan(30);

select is(
  (
    select relrowsecurity
    from pg_class
    join pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'organization_invitations'
  ),
  true,
  'organization invitations keep RLS enabled'
);

select is(
  has_table_privilege(
    'anon',
    'public.organization_invitations',
    'select'
  ),
  false,
  'anon cannot read invitations directly'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.organization_invitations',
    'select'
  ),
  false,
  'authenticated clients cannot read invitations directly'
);

select is(
  has_function_privilege(
    'anon',
    'public.create_organization_invitation(uuid,text,text)',
    'execute'
  ),
  false,
  'anon cannot create invitations'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_organization_members(uuid)',
    'execute'
  ),
  false,
  'anon cannot list members'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_organization_invitations(uuid)',
    'execute'
  ),
  false,
  'anon cannot list invitations'
);

select is(
  has_function_privilege(
    'anon',
    'public.approve_organization_invitation(uuid)',
    'execute'
  ),
  false,
  'anon cannot approve invitations'
);

select is(
  has_function_privilege(
    'anon',
    'public.revoke_organization_invitation(uuid)',
    'execute'
  ),
  false,
  'anon cannot revoke invitations'
);

select is(
  has_function_privilege(
    'anon',
    'public.accept_organization_invitation(text,text)',
    'execute'
  ),
  false,
  'anon cannot accept invitations'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.create_organization_invitation(uuid,text,text)',
    'execute'
  ),
  true,
  'authenticated clients can use the guarded create command'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.list_organization_members(uuid)',
    'execute'
  ),
  true,
  'authenticated managers can list members through the guarded command'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.list_organization_invitations(uuid)',
    'execute'
  ),
  true,
  'authenticated managers can list invitations through the guarded command'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.approve_organization_invitation(uuid)',
    'execute'
  ),
  true,
  'authenticated members can call the guarded approval command'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.revoke_organization_invitation(uuid)',
    'execute'
  ),
  true,
  'authenticated managers can call the guarded revoke command'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.accept_organization_invitation(text,text)',
    'execute'
  ),
  true,
  'authenticated invitees can call the guarded accept command'
);

reset role;

insert into public.membership_roles (
  id,
  organization_id,
  membership_id,
  role
)
values (
  '62000000-0000-0000-0000-000000000020',
  '00000000-0000-0000-0000-000000000002',
  '61000000-0000-0000-0000-000000000002',
  'org_admin'
);

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '61000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000002',
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
  '62000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000002',
  '61000000-0000-0000-0000-000000000003',
  'org_owner'
);

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
    'email', 'teacher.b@xueqing.test',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000002'
  )::text,
  true
);

select lives_ok(
  $$
    select set_config(
      'xueqing.owner_invite',
      public.create_organization_invitation(
        '00000000-0000-0000-0000-000000000002',
        'responsible@xueqing.test',
        'org_owner'
      )::text,
      true
    )
  $$,
  'an organization admin can nominate a responsible person'
);

select is(
  current_setting('xueqing.owner_invite')::jsonb ->> 'status',
  'pending_owner_approval',
  'an owner nomination waits for approval'
);

select throws_ok(
  $$
    select public.create_organization_invitation(
      '00000000-0000-0000-0000-000000000002',
      'another-admin@xueqing.test',
      'org_admin'
    )
  $$,
  'P0001',
  null,
  'an organization admin cannot directly invite another administrator'
);

select throws_ok(
  $$
    select public.approve_organization_invitation(
      (current_setting('xueqing.owner_invite')::jsonb ->> 'id')::uuid
    )
  $$,
  'P0001',
  null,
  'an organization admin cannot approve a responsible person'
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
    'email', 'no.membership@xueqing.test',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000003'
  )::text,
  true
);

select lives_ok(
  $$
    select public.approve_organization_invitation(
      (current_setting('xueqing.owner_invite')::jsonb ->> 'id')::uuid
    )
  $$,
  'an existing responsible person can approve a nomination'
);

select is(
  (
    select invitation ->> 'status'
    from public.list_organization_invitations(
      '00000000-0000-0000-0000-000000000002'
    ) as invitation
    where invitation ->> 'id' = (
      current_setting('xueqing.owner_invite')::jsonb ->> 'id'
    )
  ),
  'pending',
  'approved nominations become available for acceptance'
);

select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-000000000004',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '20000000-0000-0000-0000-000000000004',
    'email', 'responsible@xueqing.test',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '60000000-0000-0000-0000-000000000004'
  )::text,
  true
);

select lives_ok(
  $$
    select public.accept_organization_invitation(
      current_setting('xueqing.owner_invite')::jsonb ->> 'invite_code',
      '开发负责人'
    )
  $$,
  'the invited email can accept an approved invitation'
);

reset role;

select is(
  (
    select membership.status
    from public.organization_memberships as membership
    join public.app_users as app_user
      on app_user.id = membership.app_user_id
    where app_user.auth_subject_id = '20000000-0000-0000-0000-000000000004'
      and membership.organization_id =
        '00000000-0000-0000-0000-000000000002'
  ),
  'active',
  'accepted invitations create an active membership'
);

select is(
  (
    select membership_role.role
    from public.membership_roles as membership_role
    join public.organization_memberships as membership
      on membership.id = membership_role.membership_id
    join public.app_users as app_user
      on app_user.id = membership.app_user_id
    where app_user.auth_subject_id = '20000000-0000-0000-0000-000000000004'
      and membership.organization_id =
        '00000000-0000-0000-0000-000000000002'
  ),
  'org_owner',
  'accepted invitations assign the requested role'
);

select is(
  (
    select status
    from public.organization_invitations
    where id = (
      current_setting('xueqing.owner_invite')::jsonb ->> 'id'
    )::uuid
  ),
  'accepted',
  'accepted invitations become one-time facts'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-000000000004',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '20000000-0000-0000-0000-000000000004',
    'email', 'responsible@xueqing.test',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '60000000-0000-0000-0000-000000000004'
  )::text,
  true
);

select throws_ok(
  $$
    select public.accept_organization_invitation(
      current_setting('xueqing.owner_invite')::jsonb ->> 'invite_code',
      '重复接受'
    )
  $$,
  'P0001',
  null,
  'the same invitation cannot be accepted twice'
);

reset role;
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
    'email', 'no.membership@xueqing.test',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000003'
  )::text,
  true
);

select lives_ok(
  $$
    select set_config(
      'xueqing.mismatch_invite',
      public.create_organization_invitation(
        '00000000-0000-0000-0000-000000000002',
        'mismatch@xueqing.test',
        'teacher'
      )::text,
      true
    )
  $$,
  'a responsible person can create a teacher invitation'
);

select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-000000000004',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '20000000-0000-0000-0000-000000000004',
    'email', 'wrong@xueqing.test',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '60000000-0000-0000-0000-000000000004'
  )::text,
  true
);

select throws_ok(
  $$
    select public.accept_organization_invitation(
      current_setting('xueqing.mismatch_invite')::jsonb ->> 'invite_code',
      '错误邮箱'
    )
  $$,
  'P0001',
  null,
  'an invitation is bound to its email address'
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
    'email', 'no.membership@xueqing.test',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000003'
  )::text,
  true
);

select lives_ok(
  $$
    select set_config(
      'xueqing.admin_invite',
      public.create_organization_invitation(
        '00000000-0000-0000-0000-000000000002',
        'second-admin@xueqing.test',
        'org_admin'
      )::text,
      true
    )
  $$,
  'a responsible person can invite an administrator'
);

select is(
  (
    select count(*)::int
    from public.list_organization_invitations(
      '00000000-0000-0000-0000-000000000002'
    )
  ),
  2,
  'the manager can list the two pending invitations'
);

reset role;

select * from finish();

rollback;