begin;

select plan(8);

reset role;
update public.students
set status = 'archived',
    archived_at = timezone('utc', now())
where id = '30000000-0000-0000-0000-000000000001';

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
  (
    select count(*)::int
    from public.students
    where id = '30000000-0000-0000-0000-000000000001'
  ),
  0,
  'an archived student is hidden from the teacher student relation'
);
select is(
  (
    select count(*)::int
    from public.student_enrollments
    where student_id = '30000000-0000-0000-0000-000000000001'
  ),
  0,
  'an archived student enrollment is hidden through the RLS graph'
);
select is(
  (
    select count(*)::int
    from public.teacher_workspace_student_enrollments
    where student_id = '30000000-0000-0000-0000-000000000001'
  ),
  0,
  'an archived student enrollment is hidden from the workspace read model'
);
select is(
  (
    select count(*)::int
    from public.student_subject_profiles
    where student_id = '30000000-0000-0000-0000-000000000001'
  ),
  0,
  'an archived student profile is hidden from teachers'
);
select is(
  (
    select count(*)::int
    from public.student_teacher_assignments
    where student_subject_profile_id =
      '67000000-0000-0000-0000-000000000001'
  ),
  0,
  'an archived student assignment is hidden from teachers'
);
select is(
  (select private.can_read_student_v2(
    '30000000-0000-0000-0000-000000000001'
  )),
  false,
  'the student read helper rejects archived students'
);
select is(
  (select private.can_read_profile_v2(
    '67000000-0000-0000-0000-000000000001'
  )),
  false,
  'the profile read helper rejects profiles of archived students'
);
select is(
  (
    select count(*)::int
    from public.students
    where id = '30000000-0000-0000-0000-000000000002'
  ),
  0,
  'the teacher still cannot cross the organization boundary'
);

select * from finish();
rollback;
