begin;

select plan(60);

select is(
  (select prosecdef from pg_catalog.pg_proc
   join pg_catalog.pg_namespace on pg_catalog.pg_namespace.oid = pg_catalog.pg_proc.pronamespace
   where pg_catalog.pg_namespace.nspname = 'public'
     and pg_catalog.pg_proc.proname = 'reopen_case'),
  false,
  'public reopen_case is an invoker wrapper'
);

select is(
  (select prosecdef from pg_catalog.pg_proc
   join pg_catalog.pg_namespace on pg_catalog.pg_namespace.oid = pg_catalog.pg_proc.pronamespace
   where pg_catalog.pg_namespace.nspname = 'private'
     and pg_catalog.pg_proc.proname = 'reopen_case_v2'),
  true,
  'private reopen_case_v2 is security definer'
);

select is(
  has_function_privilege(
    'anon',
    'public.reopen_case(uuid,uuid,integer,uuid[],jsonb,text,text,date)',
    'execute'
  ),
  false,
  'anonymous clients cannot execute reopen_case'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.reopen_case(uuid,uuid,integer,uuid[],jsonb,text,text,date)',
    'execute'
  ),
  true,
  'authenticated teachers can execute reopen_case'
);

select is(
  has_function_privilege(
    'authenticated',
    'private.reopen_case_v2(uuid,uuid,integer,uuid[],jsonb,text,text,date)',
    'execute'
  ),
  true,
  'authenticated teachers can reach the private reopen implementation'
);

select is(
  has_function_privilege(
    'anon',
    'private.reopen_case_v2(uuid,uuid,integer,uuid[],jsonb,text,text,date)',
    'execute'
  ),
  false,
  'anonymous clients cannot reach the private reopen implementation'
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
  $$select public.quick_capture_case(
      '74000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1,
      'knowledge',
      '关闭后复发闭环测试',
      '验证关闭后的复发证据可以安全重新打开 Case。',
      timestamptz '2026-09-10 09:00:00+08',
      '初始课堂证据。',
      '首次干预行动',
      timestamptz '2026-09-11 09:00:00+08'
    )$$,
  'create the Case used by reopen tests'
);

select lives_ok(
  $$select public.confirm_case(
      '74000000-0000-0000-0000-000000000002',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      1,
      '确认后继续跟进',
      timestamptz '2026-09-11 09:00:00+08'
    )$$,
  'confirm the Case'
);

select lives_ok(
  $$select public.record_intervention(
      '74000000-0000-0000-0000-000000000003',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      2,
      '先复述步骤，再完成两道练习',
      '验证第一次干预。',
      timestamptz '2026-09-11 15:00:00+08',
      '安排验证',
      timestamptz '2026-09-13 09:00:00+08'
    )$$,
  'record the first Intervention'
);

select lives_ok(
  $$select public.record_assessment(
      '74000000-0000-0000-0000-000000000004',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      3,
      'passed',
      '第一次验证通过。',
      null,
      timestamptz '2026-09-14 09:00:00+08',
      '再观察一次后稳定',
      timestamptz '2026-09-15 09:00:00+08'
    )$$,
  'record the first Assessment'
);

select lives_ok(
  $$select public.stabilize_case(
      '74000000-0000-0000-0000-000000000005',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      4,
      timestamptz '2026-09-15 15:00:00+08',
      '保持观察',
      timestamptz '2026-09-16 09:00:00+08'
    )$$,
  'stabilize the first Case'
);

select lives_ok(
  $$select public.close_case(
      '74000000-0000-0000-0000-000000000006',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      5,
      timestamptz '2026-09-16 17:00:00+08'
    )$$,
  'close the first Case'
);

select is(
  (select status from public.learning_cases where title = '关闭后复发闭环测试'),
  'closed',
  'the Case is closed before recurrence'
);

select is(
  (select version from public.learning_cases where title = '关闭后复发闭环测试'),
  6,
  'the first close ends at Case version six'
);

select is(
  (select count(*)::int
   from public.case_events
   where learning_case_id = (select id from public.learning_cases where title = '关闭后复发闭环测试')
     and event_type = 'case_closed'
     and operation_id = '74000000-0000-0000-0000-000000000006'),
  1,
  'the first close creates one committed close boundary'
);

reset role;

select set_config(
  'xueqing.reopen_case_id',
  (select id::text
   from public.learning_cases
   where title = '关闭后复发闭环测试'),
  true
);
select set_config(
  'xueqing.reopen_evidence_id',
  (select id::text
   from public.case_evidence
   where title = '关闭后复发闭环测试'),
  true
);

set local role authenticated;

select throws_ok(
  $$select public.reopen_case(
      '74000000-0000-0000-0000-000000000010',
      current_setting('xueqing.reopen_case_id')::uuid,
      6,
      array[current_setting('xueqing.reopen_evidence_id')::uuid],
      jsonb_build_object(current_setting('xueqing.reopen_evidence_id'), 1),
      'review',
      '没有日期的复查不得创建',
      null
    )$$,
  'P0001',
  'review_due_date_required',
  'review Action requires a due date'
);

set local role anon;

select throws_ok(
  $$select public.reopen_case(
      '74000000-0000-0000-0000-000000000011',
      current_setting('xueqing.reopen_case_id')::uuid,
      6,
      array[current_setting('xueqing.reopen_evidence_id')::uuid],
      jsonb_build_object(current_setting('xueqing.reopen_evidence_id'), 1),
      'verify',
      '匿名不得重新打开',
      date '2026-09-18'
    )$$,
  '42501',
  null,
  'anonymous callers cannot invoke reopen_case'
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
    'session_id', '50000000-0000-0000-0000-0000000000ff'
  )::text,
  true
);

select throws_ok(
  $$select public.reopen_case(
      '74000000-0000-0000-0000-000000000012',
      current_setting('xueqing.reopen_case_id')::uuid,
      6,
      array[current_setting('xueqing.reopen_evidence_id')::uuid],
      jsonb_build_object(current_setting('xueqing.reopen_evidence_id'), 1),
      'verify',
      '撤销会话不得重新打开',
      date '2026-09-18'
    )$$,
  'P0001',
  null,
  'a revoked session cannot reopen a Case'
);

select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000003', true);
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
  $$select public.reopen_case(
      '74000000-0000-0000-0000-000000000013',
      current_setting('xueqing.reopen_case_id')::uuid,
      6,
      array[current_setting('xueqing.reopen_evidence_id')::uuid],
      jsonb_build_object(current_setting('xueqing.reopen_evidence_id'), 1),
      'verify',
      '无机构账号不得重新打开',
      date '2026-09-18'
    )$$,
  'P0001',
  null,
  'a user without membership cannot reopen a Case'
);

reset role;

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status,
  onboarding_expires_at,
  onboarding_started_at,
  onboarding_required
)
values (
  '61000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000003',
  'onboarding',
  now() + interval '7 days',
  now(),
  true
);

set local role authenticated;

select throws_ok(
  $$select public.reopen_case(
      '74000000-0000-0000-0000-000000000014',
      current_setting('xueqing.reopen_case_id')::uuid,
      6,
      array[current_setting('xueqing.reopen_evidence_id')::uuid],
      jsonb_build_object(current_setting('xueqing.reopen_evidence_id'), 1),
      'verify',
      'onboarding 账号不得重新打开',
      date '2026-09-18'
    )$$,
  'P0001',
  null,
  'an onboarding member cannot reopen a Case'
);

reset role;

delete from public.organization_memberships
where id = '61000000-0000-0000-0000-000000000003';

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status,
  onboarding_required
)
values (
  '61000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000003',
  'disabled',
  false
);

set local role authenticated;

select throws_ok(
  $$select public.reopen_case(
      '74000000-0000-0000-0000-000000000015',
      current_setting('xueqing.reopen_case_id')::uuid,
      6,
      array[current_setting('xueqing.reopen_evidence_id')::uuid],
      jsonb_build_object(current_setting('xueqing.reopen_evidence_id'), 1),
      'verify',
      'disabled 账号不得重新打开',
      date '2026-09-18'
    )$$,
  'P0001',
  null,
  'a disabled member cannot reopen a Case'
);

select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000002', true);
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
  $$select public.reopen_case(
      '74000000-0000-0000-0000-000000000016',
      current_setting('xueqing.reopen_case_id')::uuid,
      6,
      array[current_setting('xueqing.reopen_evidence_id')::uuid],
      jsonb_build_object(current_setting('xueqing.reopen_evidence_id'), 1),
      'verify',
      '跨组织账号不得重新打开',
      date '2026-09-18'
    )$$,
  'P0001',
  null,
  'a teacher from another organization cannot reopen a Case'
);

reset role;

delete from public.organization_memberships
where id = '61000000-0000-0000-0000-000000000003';

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '61000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000003',
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
  '64000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '63000000-0000-0000-0000-000000000002',
  '英语',
  'active'
);

insert into public.membership_roles (
  id,
  organization_id,
  membership_id,
  role
)
values (
  '62000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000003',
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
  '65000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000003',
  '64000000-0000-0000-0000-000000000003',
  'teaching',
  'active',
  '2026-01-01'
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
  '68000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000003',
  'collaborator',
  'active',
  '2026-01-01'
);

set local role authenticated;

select throws_ok(
  $$select public.reopen_case(
      '74000000-0000-0000-0000-000000000017',
      current_setting('xueqing.reopen_case_id')::uuid,
      6,
      array[current_setting('xueqing.reopen_evidence_id')::uuid],
      jsonb_build_object(current_setting('xueqing.reopen_evidence_id'), 1),
      'verify',
      '跨学科账号不得重新打开',
      date '2026-09-18'
    )$$,
  'P0001',
  null,
  'a teacher without the matching subject scope cannot reopen a Case'
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


reset role;

insert into public.students (id, organization_id, name, status)
values (
  '30000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '跨学生目标测试学生',
  'active'
);

insert into public.student_enrollments (
  id,
  organization_id,
  student_id,
  grade,
  class_name,
  campus,
  starts_on
)
values (
  '66000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000003',
  '初二',
  'A班',
  '厦门校区',
  '2026-01-01'
);

insert into public.student_subject_profiles (
  id,
  organization_id,
  student_id,
  organization_subject_id,
  status,
  positioning,
  strengths,
  cadence_note
)
values (
  '67000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000003',
  '64000000-0000-0000-0000-000000000001',
  'active',
  '跨学生越权回归',
  '虚构测试资料',
  '仅用于权限测试'
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
  '68000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000003',
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
  description,
  priority,
  status,
  first_observed_at,
  stable_at,
  closed_at,
  version,
  created_by_app_user_id,
  created_by_membership_id
)
values (
  '69000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000003',
  '61000000-0000-0000-0000-000000000001',
  'knowledge',
  '跨学生目标测试',
  '仅用于验证目标 Case 与 Evidence 的归属检查。',
  'normal',
  'closed',
  timestamptz '2026-09-10 09:00:00+08',
  timestamptz '2026-09-15 12:00:00+08',
  timestamptz '2026-09-16 17:00:00+08',
  1,
  '10000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);

insert into public.operation_receipts (
  organization_id,
  operation_id,
  command_type,
  target_type,
  target_id,
  result,
  committed_at
)
values (
  '00000000-0000-0000-0000-000000000001',
  '74000000-0000-0000-0000-000000000018',
  'close_case',
  'learning_case',
  '69000000-0000-0000-0000-000000000003',
  jsonb_build_object(
    'operation_id', '74000000-0000-0000-0000-000000000018',
    'case_id', '69000000-0000-0000-0000-000000000003',
    'status', 'closed',
    'case_version', 1
  ),
  timestamptz '2026-09-16 17:01:00+08'
);

insert into public.case_events (
  organization_id,
  learning_case_id,
  event_type,
  actor_app_user_id,
  actor_membership_id,
  occurred_at,
  metadata,
  operation_id,
  operation_event_key
)
values (
  '00000000-0000-0000-0000-000000000001',
  '69000000-0000-0000-0000-000000000003',
  'case_closed',
  '10000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  timestamptz '2026-09-16 17:00:00+08',
  '{}'::jsonb,
  '74000000-0000-0000-0000-000000000018',
  'case_closed'
);

set local role authenticated;

select throws_ok(
  $$select public.reopen_case(
      '74000000-0000-0000-0000-000000000019',
      '69000000-0000-0000-0000-000000000003',
      1,
      array[current_setting('xueqing.reopen_evidence_id')::uuid],
      jsonb_build_object(current_setting('xueqing.reopen_evidence_id'), 1),
      'verify',
      '跨学生 Evidence 不得被复用',
      date '2026-09-18'
    )$$,
  'P0001',
  null,
  'an authorized teacher cannot reuse Evidence from another student Case'
);

select is(
  (select status from public.learning_cases where id =
    '69000000-0000-0000-0000-000000000003'),
  'closed',
  'cross-student Evidence rejection leaves the target Case closed'
);

reset role;
set local role authenticated;

select throws_ok(
  $$select public.add_case_evidence(
      '74000000-0000-0000-0000-000000000007',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      6,
      'observation',
      '补录但早于关闭',
      timestamptz '2026-09-16 16:59:59+08',
      '这条证据不得改变关闭边界。'
    )$$,
  'P0001',
  null,
  'evidence observed before close cannot be appended to a closed Case'
);

select is(
  (select count(*)::int
   from public.case_evidence
   where learning_case_id = (select id from public.learning_cases where title = '关闭后复发闭环测试')),
  1,
  'the rejected pre-close Evidence leaves no side effect'
);

select lives_ok(
  $$select public.add_case_evidence(
      '74000000-0000-0000-0000-000000000008',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      6,
      'observation',
      '关闭后真实复发',
      timestamptz '2026-09-17 09:00:00+08',
      '关闭后再次观察到同类表现。'
    )$$,
  'late Evidence can be appended after close'
);

select is(
  (select count(*)::int
   from public.case_evidence
   where learning_case_id = (select id from public.learning_cases where title = '关闭后复发闭环测试')),
  2,
  'late Evidence is committed exactly once'
);

select is(
  (select version from public.learning_cases where title = '关闭后复发闭环测试'),
  6,
  'appending Evidence does not mutate the Case version'
);

select throws_ok(
  $$select public.reopen_case(
      '74000000-0000-0000-0000-000000000009',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      6,
      array[(select id from public.case_evidence where title = '关闭后复发闭环测试')],
      jsonb_build_object(
        (select id::text from public.case_evidence where title = '关闭后复发闭环测试'),
        1
      ),
      'verify',
      '旧证据不得重新打开',
      date '2026-09-18'
    )$$,
  'P0001',
  null,
  'old Evidence alone cannot reopen a Case'
);

select is(
  (select status from public.learning_cases where title = '关闭后复发闭环测试'),
  'closed',
  'a rejected reopen leaves the Case closed'
);

select lives_ok(
  $$select public.reopen_case(
      '74000000-0000-0000-0000-00000000000a',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      6,
      array[(select id from public.case_evidence where title = '关闭后真实复发')],
      jsonb_build_object(
        (select id::text from public.case_evidence where title = '关闭后真实复发'),
        1
      ),
      'verify',
      '复发后安排验证',
      date '2026-09-18'
    )$$,
  'a fresh post-close Evidence reopens the Case'
);

select is(
  (select status from public.learning_cases where title = '关闭后复发闭环测试'),
  'confirmed',
  'reopen_case returns the Case to confirmed'
);

select is(
  (select version from public.learning_cases where title = '关闭后复发闭环测试'),
  7,
  'reopen_case increments the Case version once'
);

select is(
  (select reopened_count from public.learning_cases where title = '关闭后复发闭环测试'),
  1,
  'reopen_case increments reopened_count'
);

select is(
  (select closed_at is null and stable_at is null
   from public.learning_cases where title = '关闭后复发闭环测试'),
  true,
  'reopen_case clears closed and stable timestamps'
);

select is(
  (select count(*)::int
   from public.case_actions
   where learning_case_id = (select id from public.learning_cases where title = '关闭后复发闭环测试')
     and status = 'pending'
     and is_primary),
  1,
  'reopen_case creates exactly one pending primary Action'
);

select is(
  (select title
   from public.case_actions
   where learning_case_id = (select id from public.learning_cases where title = '关闭后复发闭环测试')
     and status = 'pending' and is_primary),
  '复发后安排验证',
  'reopen_case stores the new primary Action'
);

select is(
  (select count(*)::int
   from public.case_events
   where learning_case_id = (select id from public.learning_cases where title = '关闭后复发闭环测试')
     and event_type = 'case_reopened'),
  1,
  'reopen_case writes one immutable reopen event'
);

select is(
  (select metadata->>'previous_close_event_id'
   from public.case_events
   where learning_case_id = (select id from public.learning_cases where title = '关闭后复发闭环测试')
     and event_type = 'case_reopened'),
  (select id::text
   from public.case_events
   where learning_case_id = (select id from public.learning_cases where title = '关闭后复发闭环测试')
     and event_type = 'case_closed'
   order by occurred_at desc, id desc
   limit 1),
  'reopen event points to the committed close boundary'
);

select is(
  (select metadata->'recurrence_evidence_ids'
   from public.case_events
   where learning_case_id = (select id from public.learning_cases where title = '关闭后复发闭环测试'
     )
     and event_type = 'case_reopened'),
  jsonb_build_array(
    (select id::text from public.case_evidence where title = '关闭后真实复发')
  ),
  'reopen event records the selected recurrence Evidence'
);

select lives_ok(
  $$select public.reopen_case(
      '74000000-0000-0000-0000-00000000000a',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      6,
      array[(select id from public.case_evidence where title = '关闭后真实复发')],
      jsonb_build_object(
        (select id::text from public.case_evidence where title = '关闭后真实复发'),
        1
      ),
      'verify',
      '这个重试标题不应覆盖原 Action',
      date '2026-09-19'
    )$$,
  'replaying reopen_case is exactly once'
);

select is(
  (select count(*)::int
   from public.case_events
   where learning_case_id = (select id from public.learning_cases where title = '关闭后复发闭环测试')
     and event_type = 'case_reopened'),
  1,
  'reopen retry does not duplicate the event'
);

select is(
  (select count(*)::int
   from public.case_actions
   where learning_case_id = (select id from public.learning_cases where title = '关闭后复发闭环测试')
     and status = 'pending' and is_primary),
  1,
  'reopen retry does not create a second primary Action'
);

select is(
  (select version from public.learning_cases where title = '关闭后复发闭环测试'),
  7,
  'reopen retry does not increment the Case version again'
);

select lives_ok(
  $$select public.record_intervention(
      '74000000-0000-0000-0000-00000000000b',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      7,
      '重新讲解关键步骤',
      '验证重新打开后的正常教学链路。',
      timestamptz '2026-09-18 15:00:00+08',
      '重新安排验证',
      timestamptz '2026-09-20 09:00:00+08'
    )$$,
  'a reopened Case can continue through Intervention'
);

select lives_ok(
  $$select public.record_assessment(
      '74000000-0000-0000-0000-00000000000c',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      8,
      'passed',
      '重新打开后的验证通过。',
      null,
      timestamptz '2026-09-21 09:00:00+08',
      '稳定后再关闭',
      timestamptz '2026-09-22 09:00:00+08'
    )$$,
  'a reopened Case can continue through Assessment'
);

select lives_ok(
  $$select public.stabilize_case(
      '74000000-0000-0000-0000-00000000000d',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      9,
      timestamptz '2026-09-22 15:00:00+08',
      '第二轮观察稳定',
      timestamptz '2026-09-23 09:00:00+08'
    )$$,
  'a reopened Case can become stable again'
);

select lives_ok(
  $$select public.close_case(
      '74000000-0000-0000-0000-00000000000e',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      10,
      timestamptz '2026-09-22 17:00:00+08'
    )$$,
  'the reopened Case can be closed again'
);

select is(
  (select version from public.learning_cases where title = '关闭后复发闭环测试'),
  11,
  'the second close increments the Case version once'
);

select throws_ok(
  $$select public.reopen_case(
      '74000000-0000-0000-0000-00000000000f',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      11,
      array[(select id from public.case_evidence where title = '关闭后真实复发')],
      jsonb_build_object(
        (select id::text from public.case_evidence where title = '关闭后真实复发'),
        1
      ),
      'verify',
      '跨关闭边界的旧复发证据',
      date '2026-09-24'
    )$$,
  'P0001',
  null,
  'Evidence from the previous close cycle cannot reopen after a later close'
);

select is(
  (select status from public.learning_cases where title = '关闭后复发闭环测试'),
  'closed',
  'the second-cycle rejection leaves the Case closed'
);

select lives_ok(
  $$select public.add_case_evidence(
      '74000000-0000-0000-0000-000000000010',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      11,
      'observation',
      '第二次关闭后的复发',
      timestamptz '2026-09-23 09:00:00+08',
      '第二次关闭后再次观察到同类表现。'
    )$$,
  'a second-cycle late Evidence can be appended'
);

select lives_ok(
  $$select public.reopen_case(
      '74000000-0000-0000-0000-000000000011',
      (select id from public.learning_cases where title = '关闭后复发闭环测试'),
      11,
      array[(select id from public.case_evidence where title = '第二次关闭后的复发')],
      jsonb_build_object(
        (select id::text from public.case_evidence where title = '第二次关闭后的复发'),
        1
      ),
      'review',
      '第二轮复发后复核',
      date '2026-09-25'
    )$$,
  'fresh Evidence can reopen the second close cycle'
);

select is(
  (select status from public.learning_cases where title = '关闭后复发闭环测试'),
  'confirmed',
  'the second reopen returns the Case to confirmed'
);

select is(
  (select version from public.learning_cases where title = '关闭后复发闭环测试'),
  12,
  'the second reopen increments the Case version once'
);

select is(
  (select reopened_count from public.learning_cases where title = '关闭后复发闭环测试'),
  2,
  'reopened_count records both close cycles'
);

select is(
  (select count(*)::int
   from public.case_events
   where learning_case_id = (select id from public.learning_cases where title = '关闭后复发闭环测试')
     and event_type = 'case_reopened'),
  2,
  'there are two immutable reopen events after two cycles'
);

select is(
  (select count(*)::int
   from public.case_actions
   where learning_case_id = (select id from public.learning_cases where title = '关闭后复发闭环测试')
     and status = 'pending' and is_primary),
  1,
  'the second reopen also leaves one pending primary Action'
);

reset role;

select * from finish();
rollback;