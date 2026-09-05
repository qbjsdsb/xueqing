begin;

select plan(52);

create temp table assignment_handoff_test_state (
  source_assignment_id uuid primary key,
  source_membership_id uuid not null,
  profile_id uuid not null,
  source_version integer not null,
  replacement_assignment_id uuid
);

grant all on table assignment_handoff_test_state to authenticated;

select is(
  (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'student_teacher_assignments'
      and column_name = 'version'
  ),
  1,
  'student teacher assignments have an optimistic version'
);

select is(
  to_regprocedure(
    'public.list_organization_student_teacher_assignments(uuid)'
  ) is not null,
  true,
  'student teacher assignment roster function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.list_organization_student_teacher_assignments(uuid)'
    )
  ),
  true,
  'assignment roster is security definer'
);

select is(
  to_regprocedure(
    'public.transfer_organization_student_teacher_assignment(uuid,uuid,uuid,integer,uuid)'
  ) is not null,
  true,
  'student teacher assignment transfer function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.transfer_organization_student_teacher_assignment(uuid,uuid,uuid,integer,uuid)'
    )
  ),
  true,
  'assignment transfer is security definer'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_organization_student_teacher_assignments(uuid)',
    'execute'
  ),
  false,
  'anon cannot list student teacher assignments'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.list_organization_student_teacher_assignments(uuid)',
    'execute'
  ),
  true,
  'authenticated can list assignments through the guarded command'
);

select is(
  has_function_privilege(
    'anon',
    'public.transfer_organization_student_teacher_assignment(uuid,uuid,uuid,integer,uuid)',
    'execute'
  ),
  false,
  'anon cannot transfer student teacher assignments'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.transfer_organization_student_teacher_assignment(uuid,uuid,uuid,integer,uuid)',
    'execute'
  ),
  true,
  'authenticated can transfer assignments through the guarded command'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.student_teacher_assignments',
    'update'
  ),
  false,
  'authenticated cannot update assignments directly'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.student_teacher_assignments',
    'insert'
  ),
  false,
  'authenticated cannot insert assignments directly'
);

insert into assignment_handoff_test_state (
  source_assignment_id,
  source_membership_id,
  profile_id,
  source_version
)
select
  assignment.id,
  assignment.membership_id,
  assignment.student_subject_profile_id,
  assignment.version
from public.student_teacher_assignments as assignment
where assignment.id = '68000000-0000-0000-0000-000000000001';

-- This is a fictional second teacher with no cross-organization membership.
insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '81000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000003',
  'active'
);

insert into public.membership_roles (
  id,
  organization_id,
  membership_id,
  role
)
values (
  '82000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000001',
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
  '83000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000001',
  '64000000-0000-0000-0000-000000000001',
  'teaching',
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
  first_observed_at,
  created_by_app_user_id,
  created_by_membership_id
)
values (
  '69000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  'knowledge',
  '交接前仍需处理的问题',
  '2026-09-05T00:00:00Z',
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
  status
)
values (
  '6a000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '69000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  'review',
  '交接前仍需完成的行动',
  true,
  'pending'
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
      'xueqing.assignment_roster',
      (
        select coalesce(jsonb_agg(item), '[]'::jsonb)
        from public.list_organization_student_teacher_assignments(
          '00000000-0000-0000-0000-000000000001'
        ) as item
      )::text,
      true
    )
  $$,
  'an organization manager can load the assignment roster'
);

select ok(
  jsonb_array_length(current_setting('xueqing.assignment_roster')::jsonb) > 0,
  'assignment roster is not empty for the fictional fixture'
);

select is(
  (
    select count(*)::int
    from jsonb_array_elements(
      current_setting('xueqing.assignment_roster')::jsonb
    ) as item
    where item ->> 'assignment_id' =
      '68000000-0000-0000-0000-000000000001'
      and item ->> 'status' = 'active'
  ),
  1,
  'roster exposes the current lead assignment'
);

select is(
  (
    select (item ->> 'version')::int
    from jsonb_array_elements(
      current_setting('xueqing.assignment_roster')::jsonb
    ) as item
    where item ->> 'assignment_id' =
      '68000000-0000-0000-0000-000000000001'
  ),
  1,
  'roster exposes the initial assignment version'
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

select throws_ok(
  $$
    select public.list_organization_student_teacher_assignments(
      '00000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  null,
  'a teacher without management role cannot list assignments'
);

select throws_ok(
  $$
    select public.transfer_organization_student_teacher_assignment(
      '85000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '68000000-0000-0000-0000-000000000001',
      1,
      '81000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  null,
  'a teacher cannot transfer student assignments'
);

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
  $handoff_case_conflict$
    select public.transfer_organization_student_teacher_assignment(
      '85000000-0000-0000-0000-000000000010',
      '00000000-0000-0000-0000-000000000001',
      '68000000-0000-0000-0000-000000000001',
      1,
      '81000000-0000-0000-0000-000000000001'
    )
  $handoff_case_conflict$,
  'P0001',
  'teacher_scope_handoff_required',
  'handoff rejects an open Case and pending Action owned by the source teacher'
);

reset role;

select is(
  (
    select assignment.status
    from public.student_teacher_assignments as assignment
    where assignment.id = '68000000-0000-0000-0000-000000000001'
  ),
  'active',
  'blocked handoff leaves the source assignment active'
);

select is(
  (
    select assignment.version
    from public.student_teacher_assignments as assignment
    where assignment.id = '68000000-0000-0000-0000-000000000001'
  ),
  1,
  'blocked handoff leaves the source assignment version unchanged'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments as assignment
    where assignment.student_subject_profile_id =
      '67000000-0000-0000-0000-000000000001'
      and assignment.membership_id =
        '81000000-0000-0000-0000-000000000001'
      and assignment.status = 'active'
  ),
  0,
  'blocked handoff does not create a replacement assignment'
);

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where operation_id =
      '85000000-0000-0000-0000-000000000010'
  ),
  0,
  'blocked handoff does not leave an operation receipt'
);

delete from public.case_actions
where id = '6a000000-0000-0000-0000-000000000001';

delete from public.learning_cases
where id = '69000000-0000-0000-0000-000000000001';

insert into public.learning_cases (
  id,
  organization_id,
  student_subject_profile_id,
  owner_membership_id,
  case_type,
  title,
  first_observed_at,
  created_by_app_user_id,
  created_by_membership_id
)
values (
  '69000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000001',
  'knowledge',
  '接收老师仍需执行的行动',
  '2026-09-05T00:00:00Z',
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
  status
)
values (
  '6a000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  '69000000-0000-0000-0000-000000000002',
  '61000000-0000-0000-0000-000000000001',
  'review',
  '接收老师仍需完成的行动',
  true,
  'pending'
);

set local role authenticated;

select throws_ok(
  $handoff_action_conflict$
    select public.transfer_organization_student_teacher_assignment(
      '85000000-0000-0000-0000-000000000011',
      '00000000-0000-0000-0000-000000000001',
      '68000000-0000-0000-0000-000000000001',
      1,
      '81000000-0000-0000-0000-000000000001'
    )
  $handoff_action_conflict$,
  'P0001',
  'teacher_scope_handoff_required',
  'handoff rejects a pending Action assigned to the source teacher'
);

reset role;

select is(
  (
    select assignment.status
    from public.student_teacher_assignments as assignment
    where assignment.id = '68000000-0000-0000-0000-000000000001'
  ),
  'active',
  'Action conflict leaves the source assignment active'
);

select is(
  (
    select assignment.version
    from public.student_teacher_assignments as assignment
    where assignment.id = '68000000-0000-0000-0000-000000000001'
  ),
  1,
  'Action conflict leaves the source assignment version unchanged'
);

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where operation_id =
      '85000000-0000-0000-0000-000000000011'
  ),
  0,
  'Action conflict does not leave an operation receipt'
);

delete from public.case_actions
where id = '6a000000-0000-0000-0000-000000000002';

delete from public.learning_cases
where id = '69000000-0000-0000-0000-000000000002';

set local role authenticated;

select lives_ok(
  $handoff_success$
    select set_config(
      'xueqing.assignment_transfer',
      public.transfer_organization_student_teacher_assignment(
        '85000000-0000-0000-0000-000000000002',
        '00000000-0000-0000-0000-000000000001',
        '68000000-0000-0000-0000-000000000001',
        1,
        '81000000-0000-0000-0000-000000000001'
      )::text,
      true
    )
  $handoff_success$,
  'a manager can transfer a current student teacher assignment'
);

select is(
  current_setting('xueqing.assignment_transfer')::jsonb ->> 'status',
  'transferred',
  'transfer returns a committed status'
);

select is(
  current_setting('xueqing.assignment_transfer')::jsonb ->> 'assignment_role',
  'lead',
  'transfer preserves the lead assignment role'
);

select is(
  current_setting('xueqing.assignment_transfer')::jsonb ->> 'student_id',
  '30000000-0000-0000-0000-000000000001',
  'transfer identifies the student'
);

select is(
  current_setting('xueqing.assignment_transfer')::jsonb ->> 'subject_name',
  '数学',
  'transfer identifies the subject'
);

select is(
  current_setting('xueqing.assignment_transfer')::jsonb ->> 'replacement_membership_id',
  '81000000-0000-0000-0000-000000000001',
  'transfer records the replacement teacher'
);

select is(
  (current_setting('xueqing.assignment_transfer')::jsonb ->>
    'replacement_assignment_version')::int,
  1,
  'replacement assignment starts at version one'
);

select isnt(
  current_setting('xueqing.assignment_transfer')::jsonb ->> 'replacement_scope_id',
  null,
  'transfer records the validated replacement teaching scope'
);

select is(
  current_setting('xueqing.assignment_transfer')::jsonb ->> 'active_from',
  ((now() at time zone 'Asia/Shanghai')::date)::text,
  'replacement starts on the organization business date'
);

reset role;

update assignment_handoff_test_state
set replacement_assignment_id = (
  current_setting('xueqing.assignment_transfer')::jsonb ->>
    'replacement_assignment_id'
)::uuid;

select is(
  (
    select assignment.status
    from public.student_teacher_assignments as assignment
    where assignment.id =
      '68000000-0000-0000-0000-000000000001'
  ),
  'ended',
  'previous assignment is ended'
);

select is(
  (
    select assignment.version
    from public.student_teacher_assignments as assignment
    where assignment.id =
      '68000000-0000-0000-0000-000000000001'
  ),
  2,
  'ending the previous assignment increments its version'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments as assignment
    where assignment.student_subject_profile_id =
      '67000000-0000-0000-0000-000000000001'
      and assignment.status = 'active'
  ),
  1,
  'the profile has exactly one active assignment after transfer'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments as assignment
    where assignment.student_subject_profile_id =
      '67000000-0000-0000-0000-000000000001'
      and assignment.membership_id =
        '61000000-0000-0000-0000-000000000001'
      and assignment.status = 'active'
  ),
  0,
  'the previous teacher no longer has an active assignment'
);

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where operation_id =
      '85000000-0000-0000-0000-000000000002'
      and command_type =
        'transfer_organization_student_teacher_assignment'
      and target_type = 'student_teacher_assignment'
      and result ->> 'status' = 'transferred'
      and committed_at is not null
  ),
  1,
  'transfer commits one operation receipt'
);

set local role authenticated;

select is(
  (
    select public.transfer_organization_student_teacher_assignment(
      '85000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000001',
      '68000000-0000-0000-0000-000000000001',
      1,
      '81000000-0000-0000-0000-000000000001'
    )
  ) ->> 'status',
  'transferred',
  'repeating the same operation returns the committed result'
);

reset role;

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where operation_id =
      '85000000-0000-0000-0000-000000000002'
  ),
  1,
  'transfer retry keeps one operation receipt'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments as assignment
    where assignment.student_subject_profile_id =
      '67000000-0000-0000-0000-000000000001'
      and assignment.status = 'active'
  ),
  1,
  'transfer retry does not create a duplicate active assignment'
);

set local role authenticated;

select throws_ok(
  $$
    select public.transfer_organization_student_teacher_assignment(
      '85000000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000001',
      '68000000-0000-0000-0000-000000000001',
      1,
      '81000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  null,
  'a stale assignment version is rejected'
);

reset role;

select is(
  (
    select assignment.status || '|' || assignment.version::text
    from public.student_teacher_assignments as assignment
    where assignment.id =
      '68000000-0000-0000-0000-000000000001'
  ),
  'ended|2',
  'stale transfer leaves the previous assignment unchanged'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments as assignment
    where assignment.student_subject_profile_id =
      '67000000-0000-0000-0000-000000000001'
      and assignment.membership_id =
        '81000000-0000-0000-0000-000000000001'
      and assignment.status = 'active'
  ),
  1,
  'stale transfer leaves the replacement assignment unchanged'
);

set local role authenticated;

select throws_ok(
  $$
    select public.transfer_organization_student_teacher_assignment(
      '85000000-0000-0000-0000-000000000004',
      '00000000-0000-0000-0000-000000000001',
      (
        select replacement_assignment_id
        from assignment_handoff_test_state
      ),
      1,
      '81000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  null,
  'transferring to the current teacher is rejected'
);

reset role;

insert into public.app_users (
  id,
  auth_provider,
  auth_subject_id,
  display_name,
  status
)
values (
  '10000000-0000-0000-0000-000000000004',
  'supabase',
  'student-handoff-no-scope',
  '无教学范围老师',
  'active'
);

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '81000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000004',
  'active'
);

insert into public.membership_roles (
  id,
  organization_id,
  membership_id,
  role
)
values (
  '82000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000002',
  'teacher'
);

set local role authenticated;

select throws_ok(
  $$
    select public.transfer_organization_student_teacher_assignment(
      '85000000-0000-0000-0000-000000000005',
      '00000000-0000-0000-0000-000000000001',
      (
        select replacement_assignment_id
        from assignment_handoff_test_state
      ),
      1,
      '81000000-0000-0000-0000-000000000002'
    )
  $$,
  'P0001',
  null,
  'replacement teacher without a subject scope is rejected'
);

reset role;

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments as assignment
    where assignment.student_subject_profile_id =
      '67000000-0000-0000-0000-000000000001'
      and assignment.status = 'active'
  ),
  1,
  'missing replacement scope leaves the active assignment unchanged'
);

set local role authenticated;

select throws_ok(
  $$
    select public.transfer_organization_student_teacher_assignment(
      '85000000-0000-0000-0000-000000000006',
      '00000000-0000-0000-0000-000000000001',
      (
        select replacement_assignment_id
        from assignment_handoff_test_state
      ),
      1,
      '61000000-0000-0000-0000-000000000002'
    )
  $$,
  'P0001',
  null,
  'a teacher membership from another organization is rejected'
);

select throws_ok(
  $$
    select public.transfer_organization_student_teacher_assignment(
      '85000000-0000-0000-0000-000000000007',
      '00000000-0000-0000-0000-000000000001',
      (
        select replacement_assignment_id
        from assignment_handoff_test_state
      ),
      0,
      '81000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  null,
  'a non-positive assignment version is rejected'
);

select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '20000000-0000-0000-0000-000000000001',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000999'
  )::text,
  true
);

select throws_ok(
  $$
    select public.list_organization_student_teacher_assignments(
      '00000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  null,
  'a revoked or unknown live session cannot list assignments'
);

select * from finish();

rollback;
