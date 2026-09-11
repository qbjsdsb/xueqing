begin;

select plan(20);

select is(
  public.xueqing_backend_compatibility()->>'schema_version',
  '20260911193000',
  'compatibility floor includes the voided-record integrity guard'
);

select is(
  (public.xueqing_backend_compatibility()->'capabilities'->>'voided_record_integrity_guard')::boolean,
  true,
  'compatibility advertises the installed integrity guard'
);

select is(
  (
    select count(*)::int
    from pg_catalog.pg_trigger as trigger_row
    join pg_catalog.pg_class as relation on relation.oid = trigger_row.tgrelid
    join pg_catalog.pg_namespace as namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'learning_cases'
      and trigger_row.tgname = 'learning_cases_voided_record_guard'
      and not trigger_row.tgisinternal
  ),
  1,
  'learning_cases has the voided-record update guard'
);

select is(
  (
    select count(*)::int
    from pg_catalog.pg_trigger as trigger_row
    where not trigger_row.tgisinternal
      and trigger_row.tgname in (
        'case_evidence_voided_record_guard',
        'interventions_voided_record_guard',
        'assessments_voided_record_guard',
        'case_actions_voided_record_guard',
        'case_events_voided_record_guard',
        'case_evidence_attachments_voided_record_guard'
      )
  ),
  6,
  'all teaching-history child tables reject writes after a Case is voided'
);

select ok(
  position(
    'learning_case.record_state = ''active''' in
    pg_catalog.pg_get_functiondef('private.can_read_case_core_v2(uuid)'::regprocedure)
  ) > 0,
  'ordinary child-read authorization excludes voided Cases'
);

select ok(
  position(
    'learning_case.record_state = ''active''' in
    pg_catalog.pg_get_functiondef('private.can_write_case_evidence_attachment_v2(uuid)'::regprocedure)
  ) > 0,
  'attachment writes exclude voided Cases'
);

select ok(
  position(
    'learning_case.record_state = ''active''' in
    pg_catalog.pg_get_functiondef(
      'private.end_organization_student_subject_service(uuid,uuid,uuid,integer)'::regprocedure
    )
  ) > 0,
  'ending a subject service ignores voided open-status history'
);

select ok(
  position(
    'learning_case.record_state = ''active''' in
    pg_catalog.pg_get_functiondef(
      'private.transfer_organization_student_teacher_assignment(uuid,uuid,uuid,integer,uuid)'::regprocedure
    )
  ) > 0,
  'teacher handoff ignores voided open-status history'
);

select ok(
  position(
    'learning_case.record_state = ''active''' in
    pg_catalog.pg_get_functiondef(
      'private.update_organization_teacher_subject_scope(uuid,uuid,uuid,uuid,uuid,integer,text)'::regprocedure
    )
  ) > 0,
  'ending a teaching subject scope ignores voided open-status history'
);

select ok(
  position(
    'learning_case.record_state = ''active''' in
    pg_catalog.pg_get_functiondef(
      'private.update_organization_membership_status_manager_legacy(uuid,uuid,uuid,integer,text)'::regprocedure
    )
  ) > 0,
  'member disable handoff checks ignore voided open-status history'
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

select lives_ok(
  $$select public.quick_capture_case(
      '7f000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1,
      'other',
      '作废后禁止旧命令继续写入',
      null,
      timestamptz '2026-09-11 18:00:00+08',
      '建立一条用于完整性护栏测试的初始证据。',
      null,
      null
    )$$,
  'manager can create the integrity-guard fixture Case'
);

select set_config(
  'xueqing.integrity_case_id',
  (select id::text from public.learning_cases where title = '作废后禁止旧命令继续写入'),
  true
);

select lives_ok(
  $$select public.void_learning_case(
      '7f000000-0000-0000-0000-000000000002',
      current_setting('xueqing.integrity_case_id')::uuid,
      1,
      'mistake',
      '完整性护栏测试'
    )$$,
  'the explicit audited void command still works with integrity triggers installed'
);

select throws_ok(
  $$select public.add_case_evidence(
      '7f000000-0000-0000-0000-000000000003',
      current_setting('xueqing.integrity_case_id')::uuid,
      2,
      'observation',
      '不应写入的旧入口证据',
      timestamptz '2026-09-11 18:10:00+08',
      '作废后任何旧教学入口都不应继续追加事实。'
    )$$,
  'P0001',
  'case_record_voided',
  'old evidence command cannot append to a voided Case'
);

reset role;

select is(
  (
    select count(*)::int
    from public.case_evidence
    where learning_case_id = current_setting('xueqing.integrity_case_id')::uuid
  ),
  1,
  'failed old command leaves the original evidence history unchanged'
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

select throws_ok(
  $$select public.end_case_follow_up(
      '7f000000-0000-0000-0000-000000000004',
      current_setting('xueqing.integrity_case_id')::uuid,
      2,
      'not_issue',
      '这次调用必须被完整性护栏拒绝',
      timestamptz '2026-09-11 18:20:00+08'
    )$$,
  'P0001',
  'case_record_voided',
  'old follow-up command cannot change a voided Case lifecycle'
);

reset role;

select is(
  (select status from public.learning_cases
   where id = current_setting('xueqing.integrity_case_id')::uuid),
  'new',
  'rejected old command does not falsify the preserved teaching lifecycle'
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
    select count(*)::int
    from public.case_evidence
    where learning_case_id = current_setting('xueqing.integrity_case_id')::uuid
  ),
  0,
  'ordinary RLS reads hide child Evidence while the Case is voided'
);

select is(
  (select private.can_write_case_evidence_attachment_v2(
    (select id from public.case_evidence
     where learning_case_id = current_setting('xueqing.integrity_case_id')::uuid
     limit 1)
  )),
  false,
  'attachment authorization rejects a voided Case'
);

select lives_ok(
  $$select public.restore_learning_case(
      '7f000000-0000-0000-0000-000000000005',
      current_setting('xueqing.integrity_case_id')::uuid,
      2
    )$$,
  'the explicit manager restore command is the permitted reactivation path'
);

select is(
  (
    select count(*)::int
    from public.case_evidence
    where learning_case_id = current_setting('xueqing.integrity_case_id')::uuid
  ),
  1,
  'restoring the Case makes the preserved Evidence readable again'
);

select * from finish();
rollback;
