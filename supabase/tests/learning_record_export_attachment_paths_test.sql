begin;

select plan(6);

select is(
  (
    select prosecdef
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'list_student_subject_learning_records_with_attachments'
  ),
  false,
  'student attachment export public wrapper is security-invoker'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_student_subject_learning_records_with_attachments(uuid,integer,integer)',
    'execute'
  ),
  false,
  'anonymous callers cannot execute student attachment export'
);

select is(
  (
    select prosecdef
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'list_teacher_learning_records_with_attachments'
  ),
  false,
  'teacher attachment export public wrapper is security-invoker'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_teacher_learning_records_with_attachments(uuid,uuid,integer,integer)',
    'execute'
  ),
  false,
  'anonymous callers cannot execute teacher attachment export'
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
  'ac000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  'knowledge',
  '图片导出测试',
  '仅用于本地测试的虚构学情。',
  'normal',
  'new',
  timestamptz '2026-09-10 16:00:00+08',
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
  'ad000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'ac000000-0000-0000-0000-000000000001',
  'observation',
  '图片导出测试',
  timestamptz '2026-09-10 16:00:00+08',
  '虚构课堂图片证据。',
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
  'ae000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'ac000000-0000-0000-0000-000000000001',
  'case_created',
  '10000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  timestamptz '2026-09-10 16:00:00+08',
  jsonb_build_object('evidence_id', 'ad000000-0000-0000-0000-000000000001')
);

insert into public.case_evidence_attachments (
  id,
  organization_id,
  learning_case_id,
  case_evidence_id,
  storage_path,
  original_file_name,
  content_type,
  size_bytes,
  created_by_app_user_id,
  created_by_membership_id
) values (
  'af000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'ac000000-0000-0000-0000-000000000001',
  'ad000000-0000-0000-0000-000000000001',
  'org/00000000-0000-0000-0000-000000000001/cases/ac000000-0000-0000-0000-000000000001/evidence/ad000000-0000-0000-0000-000000000001/af000000-0000-4000-8000-000000000001.jpg',
  '虚构作业.jpg',
  'image/jpeg',
  1024,
  '10000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);

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

select is(
  (
    select attachment_paths[1]
    from public.list_student_subject_learning_records_with_attachments(
      '67000000-0000-0000-0000-000000000001',
      500,
      0
    )
    where issue_title = '图片导出测试'
      and record_kind = 'case_created'
  ),
  'org/00000000-0000-0000-0000-000000000001/cases/ac000000-0000-0000-0000-000000000001/evidence/ad000000-0000-0000-0000-000000000001/af000000-0000-4000-8000-000000000001.jpg',
  'authorized teacher export maps initial evidence images onto the Case-created row'
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
  $$select *
    from public.list_student_subject_learning_records_with_attachments(
      '67000000-0000-0000-0000-000000000001',
      500,
      0
    )$$,
  'P0001',
  'teaching_fact_gate',
  'unauthorized teacher still cannot export another organization student images'
);

select * from finish();
rollback;
