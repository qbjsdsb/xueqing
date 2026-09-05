begin;

select plan(8);

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
    'email', 'teacher.a@xueqing.test',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000001'
  )::text,
  true
);

select lives_ok(
  $$
    select set_config(
      'xueqing.archived_organization_invite',
      public.create_organization_invitation(
        '00000000-0000-0000-0000-000000000001',
        'responsible@xueqing.test',
        'teacher'
      )::text,
      true
    )
  $$,
  'an owner can create the invitation used by the archive test'
);

select is(
  current_setting('xueqing.archived_organization_invite')::jsonb ->> 'status',
  'pending',
  'the invitation starts pending while the organization is active'
);

reset role;

update public.organizations
set status = 'archived'
where id = '00000000-0000-0000-0000-000000000001';

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
      current_setting('xueqing.archived_organization_invite')::jsonb
        ->> 'invite_code',
      '归档机构邀请用户'
    )
  $$,
  'P0001',
  'organization_not_available',
  'an archived organization cannot accept an outstanding invitation'
);

reset role;

select is(
  (
    select invitation.status
    from public.organization_invitations as invitation
    where invitation.id = (
      current_setting('xueqing.archived_organization_invite')::jsonb ->> 'id'
    )::uuid
  ),
  'pending',
  'a rejected acceptance leaves the invitation pending'
);

select is(
  (
    select count(*)
    from public.app_users as app_user
    where app_user.auth_subject_id =
      '20000000-0000-0000-0000-000000000004'
  ),
  0::bigint,
  'a rejected acceptance does not create an application identity'
);

select is(
  (
    select count(*)
    from public.organization_memberships as membership
    join public.app_users as app_user
      on app_user.id = membership.app_user_id
    where app_user.auth_subject_id =
        '20000000-0000-0000-0000-000000000004'
      and membership.organization_id =
        '00000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'a rejected acceptance does not create organization membership'
);

select is(
  (
    select count(*)
    from public.identity_links as identity_link
    join public.app_users as app_user
      on app_user.id = identity_link.app_user_id
    where app_user.auth_subject_id =
      '20000000-0000-0000-0000-000000000004'
  ),
  0::bigint,
  'a rejected acceptance does not create an identity link'
);

select is(
  (
    select count(*)
    from public.membership_roles as membership_role
    join public.organization_memberships as membership
      on membership.id = membership_role.membership_id
    join public.app_users as app_user
      on app_user.id = membership.app_user_id
    where app_user.auth_subject_id =
        '20000000-0000-0000-0000-000000000004'
      and membership.organization_id =
        '00000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'a rejected acceptance does not assign an organization role'
);

select * from finish();

rollback;
