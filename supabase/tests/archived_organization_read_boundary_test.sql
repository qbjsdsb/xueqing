begin;

select plan(17);

reset role;

update public.organizations
set status = 'archived'
where id = '00000000-0000-0000-0000-000000000001';

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

select is(
  (select private.can_read_organization(
    '00000000-0000-0000-0000-000000000001'
  )),
  false,
  'the legacy organization helper rejects an archived organization'
);

select is(
  (select private.can_read_organization_v2(
    '00000000-0000-0000-0000-000000000001'
  )),
  false,
  'the canonical organization helper rejects an archived organization'
);

select is(
  (select private.can_read_membership_v2(
    '61000000-0000-0000-0000-000000000001'
  )),
  false,
  'the canonical membership helper rejects an archived organization'
);

select is(
  (select private.can_read_assignment(
    '40000000-0000-0000-0000-000000000001'
  )),
  false,
  'the legacy assignment helper rejects an archived organization'
);

select is(
  (
    select count(*)::int
    from public.organizations
    where id = '00000000-0000-0000-0000-000000000001'
  ),
  0,
  'the archived organization is hidden'
);

select is(
  (
    select count(*)::int
    from public.app_users
    where id = '10000000-0000-0000-0000-000000000001'
  ),
  1,
  'the current application identity remains readable for account state'
);

select is(
  (
    select count(*)::int
    from public.memberships
    where organization_id = '00000000-0000-0000-0000-000000000001'
  ),
  0,
  'legacy membership metadata is hidden'
);

select is(
  (
    select count(*)::int
    from public.organization_memberships
    where organization_id = '00000000-0000-0000-0000-000000000001'
  ),
  0,
  'canonical membership metadata is hidden'
);

select is(
  (
    select count(*)::int
    from public.membership_roles
    where organization_id = '00000000-0000-0000-0000-000000000001'
  ),
  0,
  'organization roles are hidden'
);

select is(
  (
    select count(*)::int
    from public.organization_subjects
    where organization_id = '00000000-0000-0000-0000-000000000001'
  ),
  0,
  'organization subject metadata is hidden'
);

select is(
  (
    select count(*)::int
    from public.subjects
    where id = '63000000-0000-0000-0000-000000000001'
  ),
  0,
  'global subject metadata is hidden without an active organization path'
);

select is(
  (
    select count(*)::int
    from public.membership_subject_scopes
    where organization_id = '00000000-0000-0000-0000-000000000001'
  ),
  0,
  'teacher subject scopes are hidden'
);

select is(
  (
    select count(*)::int
    from public.students
    where organization_id = '00000000-0000-0000-0000-000000000001'
  ),
  0,
  'student roots remain hidden'
);

select is(
  (
    select count(*)::int
    from public.teacher_assignments
    where id = '40000000-0000-0000-0000-000000000001'
  ),
  0,
  'legacy teacher assignments are hidden'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments
    where organization_id = '00000000-0000-0000-0000-000000000001'
  ),
  0,
  'canonical teacher assignments remain hidden'
);

select is(
  (
    select count(*)::int
    from public.student_subject_profiles
    where organization_id = '00000000-0000-0000-0000-000000000001'
  ),
  0,
  'student subject profiles remain hidden'
);

select is(
  (
    select count(*)::int
    from public.teacher_workspace_context
    where id = '00000000-0000-0000-0000-000000000001'
  ),
  0,
  'the workspace context remains hidden'
);

select * from finish();

rollback;
