from pathlib import Path

migration = Path('supabase/migrations/20260908013000_student_subject_lifecycle.sql')
text = migration.read_text()
old = 'create or replace function public.list_organization_students(\n'
new = 'create or replace function private.list_organization_students(\n'
assert text.count(old) == 1, text.count(old)
# Preserve the hardened API boundary: the existing public SECURITY INVOKER
# wrapper continues to delegate to the private privileged implementation.
text = text.replace(old, new, 1)
migration.write_text(text)

test = Path('supabase/tests/student_subject_lifecycle_test.sql')
test.write_text(r'''begin;

select plan(24);

select is(
  to_regprocedure(
    'public.end_organization_student_subject_service(uuid,uuid,uuid,integer)'
  ) is not null,
  true,
  'end student subject service function exists'
);

select is(
  to_regprocedure(
    'public.restore_organization_student_subject_service(uuid,uuid,uuid,integer,uuid,date)'
  ) is not null,
  true,
  'restore student subject service function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.end_organization_student_subject_service(uuid,uuid,uuid,integer)'
    )
  ),
  false,
  'end public function is security-invoker'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.restore_organization_student_subject_service(uuid,uuid,uuid,integer,uuid,date)'
    )
  ),
  false,
  'restore public function is security-invoker'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure('public.list_organization_students(uuid)')
  ),
  false,
  'student roster remains a security-invoker public wrapper'
);

select is(
  has_function_privilege(
    'anon',
    'public.end_organization_student_subject_service(uuid,uuid,uuid,integer)',
    'execute'
  ),
  false,
  'anon cannot end a student subject service'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.end_organization_student_subject_service(uuid,uuid,uuid,integer)',
    'execute'
  ),
  true,
  'authenticated may call the manager-gated end command'
);

-- Dedicated lifecycle fixture. It deliberately does not depend on the seeded
-- student's Case/action/version state, so each blocker is deterministic.
reset role;

insert into public.students (
  id,
  organization_id,
  name,
  status,
  version
)
values (
  '30000000-0000-0000-0000-000000000099',
  '00000000-0000-0000-0000-000000000001',
  '生命周期测试学生',
  'active',
  1
);

insert into public.student_subject_profiles (
  id,
  organization_id,
  student_id,
  organization_subject_id,
  status,
  version
)
values (
  '67000000-0000-0000-0000-000000000099',
  '00000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000099',
  '64000000-0000-0000-0000-000000000001',
  'active',
  1
);

insert into public.student_teacher_assignments (
  id,
  organization_id,
  student_subject_profile_id,
  membership_id,
  assignment_role,
  status,
  active_from
)
values (
  '71000000-0000-0000-0000-000000000099',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000099',
  '61000000-0000-0000-0000-000000000001',
  'lead',
  'active',
  '2026-01-01'
);

insert into public.learning_cases (
  id,
  organization_id,
  student_subject_profile_id,
  owner_membership_id,
  case_type,
  title,
  priority,
  status,
  first_observed_at,
  version,
  created_by_app_user_id,
  created_by_membership_id
)
values (
  '72000000-0000-0000-0000-000000000099',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000099',
  '61000000-0000-0000-0000-000000000001',
  'knowledge',
  '生命周期阻断测试 Case',
  'normal',
  'confirmed',
  timezone('utc', now()),
  1,
  '10000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);

insert into public.case_actions (
  id,
  organization_id,
  learning_case_id,
  assigned_membership_id,
  action_type,
  title,
  is_primary,
  status,
  version
)
values (
  '73000000-0000-0000-0000-000000000099',
  '00000000-0000-0000-0000-000000000001',
  '72000000-0000-0000-0000-000000000099',
  '61000000-0000-0000-0000-000000000001',
  'verify',
  '先完成验证',
  true,
  'pending',
  1
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

select throws_ok(
  $$
    select public.end_organization_student_subject_service(
      '75000000-0000-0000-0000-000000000101',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000099',
      1
    )
  $$,
  'P0001',
  'student_subject_pending_actions',
  'ending refuses to strand a pending teaching action'
);

reset role;
update public.case_actions
set status = 'cancelled',
    is_primary = false,
    cancelled_at = timezone('utc', now()),
    cancelled_by_membership_id = '61000000-0000-0000-0000-000000000001',
    updated_at = timezone('utc', now())
where id = '73000000-0000-0000-0000-000000000099';

set local role authenticated;
select throws_ok(
  $$
    select public.end_organization_student_subject_service(
      '75000000-0000-0000-0000-000000000102',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000099',
      1
    )
  $$,
  'P0001',
  'student_subject_open_cases',
  'ending refuses to hide an unresolved Learning Case'
);

reset role;
update public.learning_cases
set status = 'closed',
    stable_at = timezone('utc', now()),
    closed_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
where id = '72000000-0000-0000-0000-000000000099';

set local role authenticated;
select is(
  public.end_organization_student_subject_service(
    '75000000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000001',
    '67000000-0000-0000-0000-000000000099',
    1
  ) ->> 'status',
  'inactive',
  'manager can end a clean subject service'
);

reset role;
select is(
  (
    select status
    from public.student_subject_profiles
    where id = '67000000-0000-0000-0000-000000000099'
  ),
  'inactive',
  'ending preserves the profile and marks it inactive'
);

select is(
  (
    select version
    from public.student_subject_profiles
    where id = '67000000-0000-0000-0000-000000000099'
  ),
  2,
  'ending increments profile version exactly once'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments
    where student_subject_profile_id = '67000000-0000-0000-0000-000000000099'
      and status = 'active'
  ),
  0,
  'ending leaves no active teaching responsibility'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments
    where student_subject_profile_id = '67000000-0000-0000-0000-000000000099'
      and status = 'ended'
  ),
  1,
  'ended assignment remains as history'
);

set local role authenticated;
select is(
  public.end_organization_student_subject_service(
    '75000000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000001',
    '67000000-0000-0000-0000-000000000099',
    1
  ) ->> 'status',
  'inactive',
  'same end operation replays its committed result'
);

select is(
  public.restore_organization_student_subject_service(
    '75000000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000001',
    '67000000-0000-0000-0000-000000000099',
    2,
    '61000000-0000-0000-0000-000000000001',
    null
  ) ->> 'status',
  'active',
  'manager restores the same profile with an eligible lead teacher'
);

reset role;
select is(
  (
    select status
    from public.student_subject_profiles
    where id = '67000000-0000-0000-0000-000000000099'
  ),
  'active',
  'restore reactivates the same durable profile'
);

select is(
  (
    select version
    from public.student_subject_profiles
    where id = '67000000-0000-0000-0000-000000000099'
  ),
  3,
  'restore increments profile version once'
);

select is(
  (
    select count(*)::int
    from public.student_subject_profiles
    where id = '67000000-0000-0000-0000-000000000099'
  ),
  1,
  'restore does not create a duplicate subject profile'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments
    where student_subject_profile_id = '67000000-0000-0000-0000-000000000099'
      and status = 'active'
      and assignment_role = 'lead'
  ),
  1,
  'restore creates exactly one current lead assignment'
);

set local role authenticated;
select is(
  public.restore_organization_student_subject_service(
    '75000000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000001',
    '67000000-0000-0000-0000-000000000099',
    2,
    '61000000-0000-0000-0000-000000000001',
    null
  ) ->> 'status',
  'active',
  'same restore operation replays without duplicate responsibility'
);

select is(
  (
    select subject_item ->> 'status'
    from public.list_organization_students(
      '00000000-0000-0000-0000-000000000001'
    ) as student_row
    cross join lateral jsonb_array_elements(student_row -> 'subjects') as subject_item
    where student_row ->> 'student_id' = '30000000-0000-0000-0000-000000000099'
      and subject_item ->> 'student_subject_profile_id' =
        '67000000-0000-0000-0000-000000000099'
  ),
  'active',
  'manager roster exposes the subject lifecycle status'
);

select is(
  (
    select (subject_item ->> 'version')::int
    from public.list_organization_students(
      '00000000-0000-0000-0000-000000000001'
    ) as student_row
    cross join lateral jsonb_array_elements(student_row -> 'subjects') as subject_item
    where student_row ->> 'student_id' = '30000000-0000-0000-0000-000000000099'
      and subject_item ->> 'student_subject_profile_id' =
        '67000000-0000-0000-0000-000000000099'
  ),
  3,
  'manager roster exposes current version for stale-write protection'
);

reset role;
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
    select public.end_organization_student_subject_service(
      '75000000-0000-0000-0000-000000000105',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000099',
      3
    )
  $$,
  'P0001',
  'organization_manager_required',
  'non-manager cannot end a student subject service'
);

select * from finish();
rollback;
''')
