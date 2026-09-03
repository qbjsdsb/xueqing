begin;

select plan(38);

select is(
  (
    select data_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'organizations'
      and column_name = 'time_zone'
  ),
  'text',
  'organizations carry an IANA timezone text field'
);

select is(
  (
    select time_zone
    from public.organizations
    where id = '00000000-0000-0000-0000-000000000001'
  ),
  'Asia/Shanghai',
  'fictional Organization A uses its canonical timezone'
);

select is(
  (
    select data_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'identity_links'
      and column_name = 'external_subject'
  ),
  'text',
  'canonical external subjects remain opaque text'
);

select is(
  (select count(*)::int from public.identity_links),
  3,
  'each fictional application identity has one canonical identity link'
);

select is(
  (select count(*)::int from public.organization_memberships),
  2,
  'canonical memberships contain only the two fictional teachers'
);

select is(
  (select count(*)::int from public.student_subject_profiles),
  2,
  'each fictional student has one subject profile'
);

select is(
  (select count(*)::int from public.student_teacher_assignments),
  2,
  'each fictional profile has one explicit teacher assignment'
);

select is(
  (
    select (
      (
        timestamptz '2026-09-03 16:30:00+00'
        at time zone time_zone
      )::date
    )::text
    from public.organizations
    where id = '00000000-0000-0000-0000-000000000001'
  ),
  '2026-09-04',
  'business date follows organization timezone across UTC midnight'
);

select is(
  (
    select count(*)::int
    from pg_index as index_meta
    join pg_class as index_class
      on index_class.oid = index_meta.indexrelid
    where index_class.relname =
      'organization_memberships_one_non_disabled_per_user_idx'
      and index_meta.indisunique
      and index_meta.indpred is not null
  ),
  1,
  'one non-disabled organization membership is enforced per app user'
);

set local role anon;

select throws_ok(
  $$select * from public.student_subject_profiles$$,
  '42501',
  null,
  'anon cannot read canonical subject profiles'
);

reset role;
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
    'iss', 'supabase',
    'session_id', '50000000-0000-0000-0000-000000000001'
  )::text,
  true
);

select is(
  (select count(*)::int from public.organizations),
  1,
  'Teacher A can read one canonical organization'
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
  'Teacher A cannot read Organization B'
);

select is(
  (select count(*)::int from public.organization_memberships),
  1,
  'Teacher A can read their canonical membership'
);

select is(
  (
    select count(*)::int
    from public.membership_roles
    where role = 'teacher'
  ),
  1,
  'Teacher A can read their teacher role'
);

select is(
  (
    select count(*)::int
    from public.membership_subject_scopes
    where scope_kind = 'teaching'
  ),
  1,
  'Teacher A can read their teaching scope'
);

select is(
  (select count(*)::int from public.organization_subjects),
  1,
  'Teacher A can read their organization subject'
);

select is(
  (select count(*)::int from public.subjects),
  1,
  'Teacher A can read the subject behind their scope'
);

select is(
  (select count(*)::int from public.students),
  1,
  'Teacher A can read one assigned student'
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
    from public.student_enrollments
    where student_id = '30000000-0000-0000-0000-000000000001'
  ),
  1,
  'Teacher A can read Student A enrollment'
);

select is(
  (select count(*)::int from public.student_subject_profiles),
  1,
  'Teacher A can read one assigned subject profile'
);

select is(
  (
    select count(*)::int
    from public.student_subject_profiles
    where student_id = '30000000-0000-0000-0000-000000000002'
  ),
  0,
  'Teacher A cannot read Student B subject profile'
);

select is(
  (select count(*)::int from public.student_teacher_assignments),
  1,
  'Teacher A can read their teacher assignment'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments as assignment
    where assignment.membership_id =
      '61000000-0000-0000-0000-000000000002'
  ),
  0,
  'Teacher A cannot read Teacher B assignment'
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
    'iss', 'supabase',
    'session_id', '50000000-0000-0000-0000-000000000002'
  )::text,
  true
);

select is(
  (
    select count(*)::int
    from public.organizations
    where id = '00000000-0000-0000-0000-000000000002'
  ),
  1,
  'Teacher B can read Organization B'
);

select is(
  (
    select count(*)::int
    from public.organizations
    where id = '00000000-0000-0000-0000-000000000001'
  ),
  0,
  'Teacher B cannot read Organization A'
);

select is(
  (select count(*)::int from public.students),
  1,
  'Teacher B can read one assigned student'
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

select is(
  (select count(*)::int from public.student_subject_profiles),
  1,
  'Teacher B can read one assigned subject profile'
);

select is(
  (select count(*)::int from public.student_teacher_assignments),
  1,
  'Teacher B can read one assignment'
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
    'iss', 'supabase',
    'session_id', '50000000-0000-0000-0000-000000000003'
  )::text,
  true
);

select is(
  (select count(*)::int from public.organizations),
  0,
  'a user without canonical membership cannot read organizations'
);

select is(
  (select count(*)::int from public.students),
  0,
  'a user without canonical membership cannot read students'
);

select is(
  (select count(*)::int from public.student_subject_profiles),
  0,
  'a user without canonical membership cannot read subject profiles'
);

select is(
  (select count(*)::int from public.organization_memberships),
  0,
  'a user without canonical membership cannot read memberships'
);

select throws_ok(
  $$insert into public.student_subject_profiles (
      organization_id,
      student_id,
      organization_subject_id
    ) values (
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      '64000000-0000-0000-0000-000000000001'
    )$$,
  '42501',
  null,
  'authenticated clients cannot write the foundation tables'
);

select * from finish();
rollback;
