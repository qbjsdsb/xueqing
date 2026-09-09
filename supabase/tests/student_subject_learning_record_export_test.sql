begin;

select plan(6);

select is(
  (
    select prosecdef
    from pg_proc
    join pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'list_student_subject_learning_records'
      and pg_get_function_identity_arguments(pg_proc.oid) =
        'p_profile_id uuid, p_limit integer, p_offset integer'
  ),
  false,
  'student learning-record export keeps the public wrapper security-invoker'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_student_subject_learning_records(uuid,integer,integer)',
    'execute'
  ),
  false,
  'anonymous callers cannot execute student learning-record export'
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
  created_by_app_user_id,
  created_by_membership_id
) values (
  '9c000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  'knowledge',
  '导出记录人测试',
  '这是仅用于本地数据库测试的虚构记录。',
  'normal',
  'new',
  timestamptz '2026-09-09 10:00:00+08',
  '10000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);

insert into public.case_evidence (
  id,
  organization_id,
  learning_case_id,
  source_type,
  title,
  observed_at,
  summary,
  status,
  created_by_app_user_id,
  created_by_membership_id
) values (
  '9d000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '9c000000-0000-0000-0000-000000000001',
  'observation',
  '导出记录人测试',
  timestamptz '2026-09-09 10:00:00+08',
  '课堂观察的虚构证据。',
  'finalized',
  '10000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);

insert into public.case_events (
  id,
  organization_id,
  learning_case_id,
  event_type,
  actor_app_user_id,
  actor_membership_id,
  occurred_at,
  metadata
) values (
  '9e000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '9c000000-0000-0000-0000-000000000001',
  'case_created',
  '10000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  timestamptz '2026-09-09 10:00:00+08',
  jsonb_build_object('evidence_id', '9d000000-0000-0000-0000-000000000001')
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
  $$select *
    from public.list_student_subject_learning_records(
      '67000000-0000-0000-0000-000000000001',
      500,
      0
    )$$,
  'Teacher A can export records for the student-subject profile they teach'
);

select is(
  (
    select teacher_name
    from public.list_student_subject_learning_records(
      '67000000-0000-0000-0000-000000000001',
      500,
      0
    )
    where issue_title = '导出记录人测试'
      and record_kind = 'case_created'
  ),
  '王老师',
  'student export attributes the fact to its historical creator'
);

select is(
  (
    select count(*)::int
    from public.list_student_subject_learning_records(
      '67000000-0000-0000-0000-000000000001',
      500,
      0
    )
    where issue_title = '导出记录人测试'
  ),
  1,
  'Quick Capture initial Evidence is folded into the Case-created export row'
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

select throws_ok(
  $$select *
    from public.list_student_subject_learning_records(
      '67000000-0000-0000-0000-000000000001',
      500,
      0
    )$$,
  'P0001',
  'teaching_fact_gate',
  'Teacher B cannot export another organization student profile'
);

select * from finish();
rollback;
