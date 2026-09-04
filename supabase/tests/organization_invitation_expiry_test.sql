begin;

select plan(5);

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
      'xueqing.expired_invite',
      public.create_organization_invitation(
        '00000000-0000-0000-0000-000000000001',
        'reinvite@xueqing.test',
        'teacher'
      )::text,
      true
    )
  $$,
  'an owner can create the first invitation'
);

reset role;

select lives_ok(
  $$
    update public.organization_invitations
    set expires_at = now() - interval '1 minute'
    where id = (
      current_setting('xueqing.expired_invite')::jsonb ->> 'id'
    )::uuid
  $$,
  'an open invitation can become expired in the fixture'
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
    'email', 'teacher.a@xueqing.test',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000001'
  )::text,
  true
);

select lives_ok(
  $$
    select public.create_organization_invitation(
      '00000000-0000-0000-0000-000000000001',
      'reinvite@xueqing.test',
      'teacher'
    )
  $$,
  'an owner can re-invite after the previous invitation expires'
);

reset role;

select is(
  (
    select count(*)::int
    from public.organization_invitations
    where organization_id = '00000000-0000-0000-0000-000000000001'
      and email = 'reinvite@xueqing.test'
      and role = 'teacher'
      and status = 'expired'
  ),
  1,
  'the old invitation is retained as expired history'
);

select is(
  (
    select count(*)::int
    from public.organization_invitations
    where organization_id = '00000000-0000-0000-0000-000000000001'
      and email = 'reinvite@xueqing.test'
      and role = 'teacher'
      and status = 'pending'
  ),
  1,
  'the replacement invitation remains pending'
);

select * from finish();

rollback;
