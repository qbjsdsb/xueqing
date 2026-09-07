begin;

select plan(20);

create temp table attachment_behavior_test_state (
  learning_case_id uuid primary key,
  case_evidence_id uuid not null,
  attachment_id uuid not null,
  storage_path text not null
);

grant all on table attachment_behavior_test_state to authenticated;

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
      '91000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1,
      'knowledge',
      '附件权限行为测试',
      '仅用于虚构测试附件权限。',
      timestamptz '2026-09-07 09:00:00+08',
      '附件行为测试 Evidence',
      '继续观察附件权限',
      timestamptz '2026-09-08 09:00:00+08'
    )$$,
  'Teacher A can create the fictional Case and finalized Evidence fixture'
);

insert into attachment_behavior_test_state (
  learning_case_id,
  case_evidence_id,
  attachment_id,
  storage_path
)
select
  learning_case.id,
  evidence.id,
  '91000000-0000-4000-8000-000000000002'::uuid,
  format(
    'org/%s/cases/%s/evidence/%s/%s.jpg',
    learning_case.organization_id,
    learning_case.id,
    evidence.id,
    '91000000-0000-4000-8000-000000000002'
  )
from public.learning_cases as learning_case
join public.case_evidence as evidence
  on evidence.learning_case_id = learning_case.id
where learning_case.title = '附件权限行为测试'
  and evidence.summary = '附件行为测试 Evidence';

select is(
  (select count(*)::int from attachment_behavior_test_state),
  1,
  'fictional attachment behavior fixture resolves to exactly one Case and Evidence'
);

select is(
  (
    select private.can_write_case_evidence_attachment_v2(case_evidence_id)
    from attachment_behavior_test_state
  ),
  true,
  'Teacher A is authorized to write an attachment for assigned finalized Evidence'
);

select lives_ok(
  $$insert into storage.objects (bucket_id, name, metadata)
    select
      'case-evidence-private',
      storage_path,
      jsonb_build_object('mimetype', 'image/jpeg', 'size', 4)
    from attachment_behavior_test_state$$,
  'Teacher A can upload a canonical private Evidence object through Storage RLS'
);

select lives_ok(
  $$select public.create_case_evidence_attachment(
      '00000000-0000-0000-0000-000000000001',
      learning_case_id,
      case_evidence_id,
      attachment_id,
      storage_path,
      '课堂表现.jpg',
      'image/jpeg',
      4
    )
    from attachment_behavior_test_state$$,
  'Teacher A can register uploaded object metadata through the guarded RPC'
);

select is(
  (select count(*)::int from public.case_evidence_attachments),
  1,
  'Teacher A can read the committed attachment metadata'
);

select is(
  (
    select count(*)::int
    from storage.objects
    where bucket_id = 'case-evidence-private'
  ),
  1,
  'Teacher A can read the committed private Storage object'
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

select is(
  (select count(*)::int from public.case_evidence_attachments),
  0,
  'Teacher B cannot read Teacher A attachment metadata'
);

select is(
  (
    select count(*)::int
    from storage.objects
    where bucket_id = 'case-evidence-private'
  ),
  0,
  'Teacher B cannot read Teacher A private Storage object'
);

select is(
  (
    select private.can_write_case_evidence_attachment_v2(case_evidence_id)
    from attachment_behavior_test_state
  ),
  false,
  'Teacher B cannot write attachments to Teacher A Evidence'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name, metadata)
    select
      'case-evidence-private',
      format(
        'org/%s/cases/%s/evidence/%s/%s.jpg',
        '00000000-0000-0000-0000-000000000001',
        learning_case_id,
        case_evidence_id,
        '91000000-0000-4000-8000-000000000003'
      ),
      jsonb_build_object('mimetype', 'image/jpeg', 'size', 4)
    from attachment_behavior_test_state$$,
  '42501',
  null,
  'Teacher B Storage upload is rejected by RLS even with a canonical path'
);

select throws_ok(
  $$select public.create_case_evidence_attachment(
      '00000000-0000-0000-0000-000000000001',
      learning_case_id,
      case_evidence_id,
      '91000000-0000-4000-8000-000000000003',
      format(
        'org/%s/cases/%s/evidence/%s/%s.jpg',
        '00000000-0000-0000-0000-000000000001',
        learning_case_id,
        case_evidence_id,
        '91000000-0000-4000-8000-000000000003'
      ),
      '跨机构写入.jpg',
      'image/jpeg',
      4
    )
    from attachment_behavior_test_state$$,
  'P0001',
  null,
  'Teacher B cannot register attachment metadata for Teacher A Evidence'
);

reset role;

update public.student_teacher_assignments
set status = 'ended',
    active_to = date '2026-09-07',
    ended_at = timezone('utc', now())
where id = '68000000-0000-0000-0000-000000000001';

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
  (select count(*)::int from public.case_evidence_attachments),
  0,
  'ending Teacher A assignment immediately removes attachment metadata visibility'
);

select is(
  (
    select count(*)::int
    from storage.objects
    where bucket_id = 'case-evidence-private'
  ),
  0,
  'ending Teacher A assignment immediately removes private object visibility'
);

select is(
  (
    select private.can_write_case_evidence_attachment_v2(case_evidence_id)
    from attachment_behavior_test_state
  ),
  false,
  'ending Teacher A assignment immediately removes attachment write authority'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name, metadata)
    select
      'case-evidence-private',
      format(
        'org/%s/cases/%s/evidence/%s/%s.jpg',
        '00000000-0000-0000-0000-000000000001',
        learning_case_id,
        case_evidence_id,
        '91000000-0000-4000-8000-000000000004'
      ),
      jsonb_build_object('mimetype', 'image/jpeg', 'size', 4)
    from attachment_behavior_test_state$$,
  '42501',
  null,
  'ended assignment cannot upload a new private Evidence object'
);

reset role;

update public.student_teacher_assignments
set status = 'active',
    active_to = null,
    ended_at = null
where id = '68000000-0000-0000-0000-000000000001';

update public.organization_memberships
set status = 'disabled',
    updated_at = timezone('utc', now())
where id = '61000000-0000-0000-0000-000000000001';

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
  (select count(*)::int from public.case_evidence_attachments),
  0,
  'disabled membership cannot read attachment metadata even after assignment is restored'
);

select is(
  (
    select count(*)::int
    from storage.objects
    where bucket_id = 'case-evidence-private'
  ),
  0,
  'disabled membership cannot read private Storage objects'
);

select is(
  (
    select private.can_write_case_evidence_attachment_v2(case_evidence_id)
    from attachment_behavior_test_state
  ),
  false,
  'disabled membership cannot write private Evidence attachments'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name, metadata)
    select
      'case-evidence-private',
      format(
        'org/%s/cases/%s/evidence/%s/%s.jpg',
        '00000000-0000-0000-0000-000000000001',
        learning_case_id,
        case_evidence_id,
        '91000000-0000-4000-8000-000000000005'
      ),
      jsonb_build_object('mimetype', 'image/jpeg', 'size', 4)
    from attachment_behavior_test_state$$,
  '42501',
  null,
  'disabled membership cannot upload a new private Evidence object'
);

select * from finish();
rollback;
