begin;

select plan(6);

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
    select count(*)::integer
    from public.teacher_workspace_personal_assignments
    where student_subject_profile_id = '67000000-0000-0000-0000-000000000001'
  ),
  1,
  'seeded current teaching relationship starts inside Personal Projection'
);

reset role;
update public.student_subject_profiles
set status = 'inactive'
where id = '67000000-0000-0000-0000-000000000001';

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
  (select count(*)::integer from public.teacher_workspace_personal_assignments),
  0,
  'inactive Profile immediately leaves Personal Projection'
);

reset role;
update public.student_subject_profiles
set status = 'active'
where id = '67000000-0000-0000-0000-000000000001';
update public.students
set status = 'inactive'
where id = (
  select student_id
  from public.student_subject_profiles
  where id = '67000000-0000-0000-0000-000000000001'
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
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000001'
  )::text,
  true
);
select is(
  (select count(*)::integer from public.teacher_workspace_personal_assignments),
  0,
  'inactive Student immediately leaves Personal Projection'
);

reset role;
update public.students
set status = 'active'
where id = (
  select student_id
  from public.student_subject_profiles
  where id = '67000000-0000-0000-0000-000000000001'
);
update public.organization_subjects
set status = 'archived'
where id = (
  select organization_subject_id
  from public.student_subject_profiles
  where id = '67000000-0000-0000-0000-000000000001'
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
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000001'
  )::text,
  true
);
select is(
  (select count(*)::integer from public.teacher_workspace_personal_assignments),
  0,
  'archived Organization Subject immediately leaves Personal Projection'
);

reset role;
update public.organization_subjects
set status = 'active'
where id = (
  select organization_subject_id
  from public.student_subject_profiles
  where id = '67000000-0000-0000-0000-000000000001'
);
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
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000001'
  )::text,
  true
);
select is(
  (select count(*)::integer from public.teacher_workspace_personal_assignments),
  0,
  'archived organization immediately leaves Personal Projection'
);

reset role;
update public.organizations
set status = 'active'
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
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000001'
  )::text,
  true
);
select is(
  (
    select count(*)::integer
    from public.teacher_workspace_personal_assignments
    where student_subject_profile_id = '67000000-0000-0000-0000-000000000001'
  ),
  1,
  'restoring all service-state gates restores Personal Projection'
);

select * from finish();
rollback;
