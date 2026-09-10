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

select throws_ok(
  $$
    select public.update_organization_student_profile(
      '76100000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      1,
      '林雨桐',
      null,
      null,
      null,
      null
    )
  $$,
  'P0001',
  'invalid_student_profile_update_input',
  'grade is required by the new student profile command'
);

select lives_ok(
  $$
    select public.update_organization_student_profile(
      '76100000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      1,
      '林雨桐',
      null,
      '初三',
      null,
      null
    )
  $$,
  'manager can update required grade while leaving class and campus empty'
);

reset role;

select is(
  (
    select student.status || '|' || student.version::text
    from public.students as student
    where student.id = '30000000-0000-0000-0000-000000000001'
  ),
  'active|2',
  'profile edit keeps lifecycle status and increments one aggregate version'
);

select is(
  (
    select enrollment.grade || '|' || enrollment.class_name || '|' || enrollment.campus
    from public.student_enrollments as enrollment
    where enrollment.id = '66000000-0000-0000-0000-000000000001'
  ),
  '初二|A班|厦门校区',
  'previous enrollment context is preserved instead of overwritten'
);

select is(
  (
    select ends_on
    from public.student_enrollments
    where id = '66000000-0000-0000-0000-000000000001'
  ),
  (
    select (now() at time zone organization.time_zone)::date - 1
    from public.organizations as organization
    where organization.id = '00000000-0000-0000-0000-000000000001'
  ),
  'previous enrollment slice closes on the day before the new context'
);

select is(
  (
    select count(*)::int
    from public.student_enrollments as enrollment
    join public.organizations as organization
      on organization.id = enrollment.organization_id
    where enrollment.organization_id = '00000000-0000-0000-0000-000000000001'
      and enrollment.student_id = '30000000-0000-0000-0000-000000000001'
      and enrollment.grade = '初三'
      and enrollment.class_name is null
      and enrollment.campus is null
      and enrollment.starts_on = (now() at time zone organization.time_zone)::date
      and enrollment.ends_on is null
  ),
  1,
  'new enrollment slice stores required grade and keeps optional fields nullable'
);

select * from finish();

rollback;
