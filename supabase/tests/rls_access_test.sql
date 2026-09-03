begin;

select plan(14);

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
  (select count(*)::int from public.app_users),
  1,
  'Teacher A can read only the matching application identity'
);
select is(
  (select count(*)::int from public.memberships),
  1,
  'Teacher A can read the active membership'
);
select is(
  (select count(*)::int from public.students),
  1,
  'Teacher A can read exactly one assigned student'
);
select is(
  (
    select count(*)::int
    from public.students
    where id = '30000000-0000-0000-0000-000000000001'
  ),
  1,
  'Teacher A can read Student A'
);
select is(
  (
    select count(*)::int
    from public.students
    where id = '30000000-0000-0000-0000-000000000002'
  ),
  0,
  'Teacher A cannot read Student B'
);
select is(
  (
    select count(*)::int
    from public.organizations
    where id = '00000000-0000-0000-0000-000000000001'
  ),
  1,
  'Teacher A can read Organization A'
);
select is(
  (
    select count(*)::int
    from public.organizations
    where id = '00000000-0000-0000-0000-000000000002'
  ),
  0,
  'Teacher A cannot read the other organization'
);

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
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000002'
  )::text,
  true
);

select is(
  (
    select count(*)::int
    from public.students
    where id = '30000000-0000-0000-0000-000000000002'
  ),
  1,
  'Teacher B can read Student B'
);
select is(
  (
    select count(*)::int
    from public.students
    where id = '30000000-0000-0000-0000-000000000001'
  ),
  0,
  'Teacher B cannot read Student A'
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
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000003'
  )::text,
  true
);

select is(
  (select count(*)::int from public.students),
  0,
  'A user without membership cannot read students'
);
select is(
  (select count(*)::int from public.organizations),
  0,
  'A user without membership cannot read organizations'
);

reset role;
delete from auth.sessions
where id = '50000000-0000-0000-0000-000000000001';

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
  (select count(*)::int from public.students),
  0,
  'A revoked session cannot read students with the old session claim'
);
select is(
  (select count(*)::int from public.app_users),
  0,
  'A revoked session cannot resolve a business identity'
);
select is(
  (select count(*)::int from public.organizations),
  0,
  'A revoked session cannot read organizations'
);

select * from finish();
rollback;
