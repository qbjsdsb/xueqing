begin;

select plan(3);

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

select throws_ok(
  $$select public.create_organization_invitation(
      '00000000-0000-0000-0000-000000000001',
      'teacher.b@xueqing.test',
      'teacher'
    )$$,
  'P0001',
  'user_already_member_elsewhere',
  'an owner is told before provisioning when an email already belongs to another organization'
);

reset role;
set local role service_role;

select is(
  (
    select count(*)::integer
    from public.organization_invitations
    where organization_id = '00000000-0000-0000-0000-000000000001'
      and lower(email) = 'teacher.b@xueqing.test'
      and status in ('pending', 'pending_owner_approval')
  ),
  0,
  'the impossible cross-organization invitation is not left pending'
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

select lives_ok(
  $$select public.create_organization_invitation(
      '00000000-0000-0000-0000-000000000001',
      'fresh.teacher@xueqing.test',
      'teacher'
    )$$,
  'a genuinely new teacher email can still be invited'
);

select * from finish();
rollback;
