begin;

select plan(20);

select is(
  to_regprocedure(
    'public.add_organization_student_subject_service(uuid,uuid,uuid,uuid,uuid,date)'
  ) is not null,
  true,
  'student subject service function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.add_organization_student_subject_service(uuid,uuid,uuid,uuid,uuid,date)'
    )
  ),
  false,
  'student subject service public function is security-invoker'
);

select is(
  has_function_privilege(
    'anon',
    'public.add_organization_student_subject_service(uuid,uuid,uuid,uuid,uuid,date)',
    'execute'
  ),
  false,
  'anon cannot add a student subject service'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.add_organization_student_subject_service(uuid,uuid,uuid,uuid,uuid,date)',
    'execute'
  ),
  true,
  'authenticated may call the manager-gated subject service command'
);

reset role;

-- Add English and Science to organization A. English reuses the global English
-- dictionary item; Science is a new global dictionary fixture for this test.
insert into public.organization_subjects (
  id,
  organization_id,
  subject_id,
  display_name,
  status
)
values (
  '64000000-0000-0000-0000-000000000010',
  '00000000-0000-0000-0000-000000000001',
  '63000000-0000-0000-0000-000000000002',
  '英语',
  'active'
);

insert into public.subjects (id, code, name, status)
values (
  '63000000-0000-0000-0000-000000000010',
  'science-test',
  '科学',
  'active'
);

insert into public.organization_subjects (
  id,
  organization_id,
  subject_id,
  display_name,
  status
)
values (
  '64000000-0000-0000-0000-000000000011',
  '00000000-0000-0000-0000-000000000001',
  '63000000-0000-0000-0000-000000000010',
  '科学',
  'active'
);

-- The existing 王老师 may teach Math + English + Science.
insert into public.membership_subject_scopes (
  id,
  organization_id,
  membership_id,
  organization_subject_id,
  scope_kind,
  status,
  active_from
)
values
  (
    '65000000-0000-0000-0000-000000000010',
    '00000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000001',
    '64000000-0000-0000-0000-000000000010',
    'teaching',
    'active',
    '2026-01-01'
  ),
  (
    '65000000-0000-0000-0000-000000000011',
    '00000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000001',
    '64000000-0000-0000-0000-000000000011',
    'teaching',
    'active',
    '2026-01-01'
  );

-- A second teacher in the same organization may take another subject for the
-- same student. No provider identity is needed because this fixture never acts.
insert into public.app_users (
  id,
  auth_provider,
  auth_subject_id,
  display_name,
  status
)
values (
  '10000000-0000-0000-0000-000000000010',
  'supabase',
  '20000000-0000-0000-0000-000000000010',
  '赵老师',
  'active'
);

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '61000000-0000-0000-0000-000000000010',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000010',
  'active'
);

insert into public.membership_roles (
  id,
  organization_id,
  membership_id,
  role
)
values (
  '62000000-0000-0000-0000-000000000020',
  '00000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000010',
  'teacher'
);

insert into public.membership_subject_scopes (
  id,
  organization_id,
  membership_id,
  organization_subject_id,
  scope_kind,
  status,
  active_from
)
values (
  '65000000-0000-0000-0000-000000000012',
  '00000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000010',
  '64000000-0000-0000-0000-000000000011',
  'teaching',
  'active',
  '2026-01-01'
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

select lives_ok(
  $$
    select set_config(
      'xueqing.add_english',
      public.add_organization_student_subject_service(
        '73000000-0000-0000-0000-000000000100',
        '00000000-0000-0000-0000-000000000001',
        '30000000-0000-0000-0000-000000000001',
        '64000000-0000-0000-0000-000000000010',
        '61000000-0000-0000-0000-000000000001',
        null
      )::text,
      true
    )
  $$,
  'manager can add a second subject with the same teacher'
);

select is(
  current_setting('xueqing.add_english')::jsonb ->> 'student_id',
  '30000000-0000-0000-0000-000000000001',
  'subject addition stays on the existing student root'
);

select is(
  current_setting('xueqing.add_english')::jsonb ->> 'subject_name',
  '英语',
  'subject addition returns the new subject'
);

select is(
  current_setting('xueqing.add_english')::jsonb ->> 'teacher_display_name',
  '王老师',
  'same teacher may lead another subject for the same student'
);

select lives_ok(
  $$
    select set_config(
      'xueqing.add_science',
      public.add_organization_student_subject_service(
        '73000000-0000-0000-0000-000000000101',
        '00000000-0000-0000-0000-000000000001',
        '30000000-0000-0000-0000-000000000001',
        '64000000-0000-0000-0000-000000000011',
        '61000000-0000-0000-0000-000000000010',
        null
      )::text,
      true
    )
  $$,
  'manager can add a third subject with another teacher'
);

reset role;

select is(
  (
    select count(*)::int
    from public.student_subject_profiles as profile
    where profile.organization_id = '00000000-0000-0000-0000-000000000001'
      and profile.student_id = '30000000-0000-0000-0000-000000000001'
  ),
  3,
  'one student now has three independent subject profiles'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments as assignment
    join public.student_subject_profiles as profile
      on profile.id = assignment.student_subject_profile_id
     and profile.organization_id = assignment.organization_id
    where profile.student_id = '30000000-0000-0000-0000-000000000001'
      and assignment.status = 'active'
      and assignment.assignment_role = 'lead'
  ),
  3,
  'each subject has one active lead assignment'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments as assignment
    join public.student_subject_profiles as profile
      on profile.id = assignment.student_subject_profile_id
     and profile.organization_id = assignment.organization_id
    where profile.student_id = '30000000-0000-0000-0000-000000000001'
      and assignment.membership_id = '61000000-0000-0000-0000-000000000001'
      and assignment.status = 'active'
      and assignment.assignment_role = 'lead'
  ),
  2,
  'one teacher may lead multiple subjects for the same student'
);

select is(
  (
    select count(distinct assignment.membership_id)::int
    from public.student_teacher_assignments as assignment
    join public.student_subject_profiles as profile
      on profile.id = assignment.student_subject_profile_id
     and profile.organization_id = assignment.organization_id
    where profile.student_id = '30000000-0000-0000-0000-000000000001'
      and assignment.status = 'active'
  ),
  2,
  'one student may have multiple active teachers across subjects'
);

select is(
  (
    select status
    from public.student_teacher_assignments
    where id = '68000000-0000-0000-0000-000000000001'
  ),
  'active',
  'adding subjects does not modify the existing Math assignment'
);

set local role authenticated;

select lives_ok(
  $$
    select public.add_organization_student_subject_service(
      '73000000-0000-0000-0000-000000000100',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      '64000000-0000-0000-0000-000000000010',
      '61000000-0000-0000-0000-000000000001',
      null
    )
  $$,
  'same operation id safely returns the committed result'
);

reset role;

select is(
  (
    select count(*)::int
    from public.student_subject_profiles
    where organization_id = '00000000-0000-0000-0000-000000000001'
      and student_id = '30000000-0000-0000-0000-000000000001'
      and organization_subject_id = '64000000-0000-0000-0000-000000000010'
  ),
  1,
  'idempotent retry does not duplicate the subject profile'
);

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where organization_id = '00000000-0000-0000-0000-000000000001'
      and operation_id = '73000000-0000-0000-0000-000000000100'
      and command_type = 'add_organization_student_subject_service'
      and committed_at is not null
  ),
  1,
  'subject addition commits one operation receipt'
);

set local role authenticated;

select throws_ok(
  $$
    select public.add_organization_student_subject_service(
      '73000000-0000-0000-0000-000000000102',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      '64000000-0000-0000-0000-000000000010',
      '61000000-0000-0000-0000-000000000001',
      null
    )
  $$,
  'P0001',
  'student_subject_profile_already_exists',
  'a new operation cannot duplicate an existing student subject profile'
);

reset role;

select is(
  (
    select count(*)::int
    from public.student_subject_profiles
    where organization_id = '00000000-0000-0000-0000-000000000001'
      and student_id = '30000000-0000-0000-0000-000000000001'
  ),
  3,
  'rejected duplicate leaves the profile set unchanged'
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
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000002'
  )::text,
  true
);

select throws_ok(
  $$
    select public.add_organization_student_subject_service(
      '73000000-0000-0000-0000-000000000103',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      '64000000-0000-0000-0000-000000000011',
      '61000000-0000-0000-0000-000000000010',
      null
    )
  $$,
  'P0001',
  'organization_manager_required',
  'a non-manager teacher cannot add a student subject service'
);

reset role;

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where command_type = 'add_organization_student_subject_service'
      and organization_id = '00000000-0000-0000-0000-000000000001'
  ),
  2,
  'only the two successful subject additions have committed receipts'
);

select * from finish();
rollback;
