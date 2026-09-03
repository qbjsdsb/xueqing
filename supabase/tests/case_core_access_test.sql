begin;

select plan(59);

select is(
  (
    select count(*)::int
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'learning_cases'
  ),
  1,
  'Learning Case table exists'
);

select is(
  (
    select count(*)::int
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'case_evidence'
      and column_name = 'observed_at'
      and data_type = 'timestamp with time zone'
  ),
  1,
  'Evidence preserves the observed business timestamp'
);

select is(
  (
    select count(*)::int
    from pg_class as index_class
    join pg_index as index_meta
      on index_meta.indexrelid = index_class.oid
    where index_class.relname = 'case_actions_one_pending_primary_idx'
      and index_meta.indisunique
      and index_meta.indpred is not null
  ),
  1,
  'one pending primary Action is structurally unique per Case'
);

select is(
  (
    select count(*)::int
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'operation_receipts'
      and column_name = 'operation_id'
      and data_type = 'uuid'
  ),
  1,
  'operation ids are provider-independent UUIDs'
);

select is(
  (
    select prosecdef
    from pg_proc
    join pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'quick_capture_case'
  ),
  true,
  'Quick Capture is a security-definer server command'
);

select is(
  has_function_privilege(
    'anon',
    'public.quick_capture_case(uuid,uuid,integer,text,text,text,timestamptz,text,text,timestamptz)',
    'execute'
  ),
  false,
  'anon cannot execute the teaching command'
);

set local role anon;

select throws_ok(
  $$select * from public.learning_cases$$,
  '42501',
  null,
  'anon cannot read Learning Cases'
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
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000001'
  )::text,
  true
);

select lives_ok(
  $$select public.quick_capture_case(
      '71000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1,
      'knowledge',
      '异分母比较步骤不稳定',
      '学生知道要通分，但遇到新题时容易跳过步骤。',
      timestamptz '2026-09-03 09:00:00+08',
      '课堂练习 3 道题中有 2 道跳过通分，口头复述尚未稳定。',
      '补充两道迁移题并核对过程',
      timestamptz '2026-09-04 09:00:00+08'
    )$$,
  'Teacher A can create a Quick Capture Case'
);

select is(
  (select count(*)::int
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  1,
  'Quick Capture creates exactly one Case'
);

select is(
  (select count(*)::int
   from public.case_evidence
   where summary like '课堂练习 3 道题%'),
  1,
  'Quick Capture commits one finalized Evidence'
);

select is(
  (select count(*)::int
   from public.case_actions
   where learning_case_id = (
       select id from public.learning_cases
       where title = '异分母比较步骤不稳定'
     )
     and status = 'pending'
     and is_primary),
  1,
  'Quick Capture creates one pending primary Action'
);

select is(
  (select count(*)::int
   from public.case_events
   where event_type = 'case_created'),
  1,
  'Quick Capture writes one lifecycle event'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.operation_receipts',
    'select'
  ),
  false,
  'clients cannot read operation receipts directly'
);

select is(
  (select status
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  'new',
  'Quick Capture starts in the new state'
);

select is(
  (select version
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  1,
  'Quick Capture starts at Case version one'
);

select lives_ok(
  $$select public.quick_capture_case(
      '71000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1,
      'knowledge',
      '这次重试不应覆盖原记录',
      '这段输入不应写入。',
      timestamptz '2026-09-03 10:00:00+08',
      '这段证据不应写入。',
      '这个 Action 不应写入。',
      timestamptz '2026-09-05 09:00:00+08'
    )$$,
  'repeating Quick Capture with the same operation id is safe'
);

select is(
  (select count(*)::int from public.learning_cases),
  1,
  'Quick Capture retry does not create a duplicate Case'
);

select is(
  (select count(*)::int
   from public.case_events
   where operation_id =
     '71000000-0000-0000-0000-000000000001'),
  1,
  'Quick Capture retry does not duplicate the lifecycle event'
);

select lives_ok(
  $$select public.confirm_case(
      '71000000-0000-0000-0000-000000000002',
      (select id from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      (select version from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      '安排一次针对性练习',
      timestamptz '2026-09-04 09:00:00+08'
    )$$,
  'Teacher A can confirm a Case with minimum Evidence'
);

select is(
  (select status
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  'confirmed',
  'confirm_case moves new to confirmed'
);

select is(
  (select version
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  2,
  'confirm_case increments the Case version once'
);

select is(
  (select count(*)::int
   from public.case_actions
   where learning_case_id = (
       select id from public.learning_cases
       where title = '异分母比较步骤不稳定'
     )
     and status = 'pending'
     and is_primary),
  1,
  'confirmed Case keeps exactly one pending primary Action'
);

select is(
  (select count(*)::int
   from public.case_actions
   where learning_case_id = (
       select id from public.learning_cases
       where title = '异分母比较步骤不稳定'
     )
     and status = 'done'),
  1,
  'confirm_case closes the temporary capture Action'
);

select is(
  (select count(*)::int
   from public.case_events
   where event_type = 'case_confirmed'),
  1,
  'confirm_case writes one lifecycle event'
);

select throws_ok(
  $select public.record_intervention(
      '71000000-0000-0000-0000-00000000000a',
      (select id from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      1,
      '过期版本不应写入',
      null,
      timestamptz '2026-09-03 15:30:00+08',
      '过期版本 Action 不应写入',
      null
    )$,
  'P0001',
  null,
  'a stale Case version is rejected'
);

select is(
  (select count(*)::int
   from public.interventions
   where learning_case_id = (
       select id from public.learning_cases
       where title = '异分母比较步骤不稳定'
     )),
  0,
  'a stale command leaves no Intervention side effect'
);

select lives_ok(
  $$select public.add_case_evidence(
      '71000000-0000-0000-0000-000000000003',
      (select id from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      (select version from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      'quiz',
      '迁移题验证',
      timestamptz '2026-09-03 15:00:00+08',
      '补充验证：两道迁移题中第一道仍然跳过通分。'
    )$$,
  'Teacher A can append Evidence'
);

select is(
  (select count(*)::int
   from public.case_evidence
   where learning_case_id = (
       select id from public.learning_cases
       where title = '异分母比较步骤不稳定'
     )),
  2,
  'Evidence append adds one historical fact'
);

select is(
  (select version
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  2,
  'ordinary Evidence append does not mutate Case version'
);

select lives_ok(
  $$select public.add_case_evidence(
      '71000000-0000-0000-0000-000000000003',
      (select id from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      2,
      'quiz',
      '这条重试不应写入',
      timestamptz '2026-09-03 16:00:00+08',
      '这条重试证据不应写入。'
    )$$,
  'repeating Evidence with the same operation id is safe'
);

select is(
  (select count(*)::int
   from public.case_evidence
   where learning_case_id = (
       select id from public.learning_cases
       where title = '异分母比较步骤不稳定'
     )),
  2,
  'Evidence retry does not duplicate history'
);

select lives_ok(
  $$select public.record_intervention(
      '71000000-0000-0000-0000-000000000004',
      (select id from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      (select version from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      '用数轴演示通分，再让学生先说步骤后计算',
      '先关注过程，不只看答案。',
      timestamptz '2026-09-03 16:30:00+08',
      '再做两道迁移题并核对过程',
      timestamptz '2026-09-05 09:00:00+08'
    )$$,
  'Teacher A can record an Intervention'
);

select is(
  (select status
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  'intervening',
  'record_intervention moves the Case to intervening'
);

select is(
  (select version
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  3,
  'record_intervention increments the Case version once'
);

select is(
  (select count(*)::int
   from public.interventions
   where learning_case_id = (
       select id from public.learning_cases
       where title = '异分母比较步骤不稳定'
     )),
  1,
  'Intervention history is recorded'
);

select is(
  (select count(*)::int
   from public.case_actions
   where learning_case_id = (
       select id from public.learning_cases
       where title = '异分母比较步骤不稳定'
     )
     and status = 'pending'
     and is_primary),
  1,
  'intervention leaves one verification Action'
);

select lives_ok(
  $select public.record_intervention(
      '71000000-0000-0000-0000-000000000004',
      (select id from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      2,
      '这次重试不应新增 Intervention',
      '这段重试不应写入。',
      timestamptz '2026-09-03 17:00:00+08',
      '这条重试 Action 不应写入',
      null
    )$,
  'repeating an Intervention with the same operation id is safe'
);

select is(
  (select count(*)::int
   from public.interventions
   where learning_case_id = (
       select id from public.learning_cases
       where title = '异分母比较步骤不稳定'
     )),
  1,
  'Intervention retry does not duplicate history'
);

select lives_ok(
  $$select public.record_assessment(
      '71000000-0000-0000-0000-000000000005',
      (select id from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      (select version from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      'passed',
      '两道迁移题均完成通分，学生能复述关键步骤。',
      '仍需再观察一次稳定性。',
      timestamptz '2026-09-06 09:00:00+08',
      '再做一道迁移题，观察是否保持稳定',
      timestamptz '2026-09-07 09:00:00+08'
    )$$,
  'Teacher A can record an Assessment'
);

select is(
  (select status
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  'pending_verification',
  'a passed Assessment does not automatically mean stable'
);

select is(
  (select version
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  4,
  'record_assessment increments the Case version once'
);

select is(
  (select count(*)::int
   from public.assessments
   where learning_case_id = (
       select id from public.learning_cases
       where title = '异分母比较步骤不稳定'
     )),
  1,
  'Assessment history is recorded'
);

select is(
  (select count(*)::int
   from public.case_actions
   where learning_case_id = (
       select id from public.learning_cases
       where title = '异分母比较步骤不稳定'
     )
     and status = 'pending'
     and is_primary),
  1,
  'pending verification keeps one next Action'
);

select lives_ok(
  $$select public.stabilize_case(
      '71000000-0000-0000-0000-000000000006',
      (select id from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      (select version from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      timestamptz '2026-09-08 09:00:00+08',
      '观察一周后确认是否保持稳定',
      timestamptz '2026-09-15 09:00:00+08'
    )$$,
  'Teacher A can mark a passed Case stable'
);

select is(
  (select status
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  'stable',
  'stabilize_case moves pending_verification to stable'
);

select is(
  (select stable_at is not null
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  true,
  'stable_at is recorded'
);

select is(
  (select count(*)::int
   from public.case_actions
   where learning_case_id = (
       select id from public.learning_cases
       where title = '异分母比较步骤不稳定'
     )
     and status = 'pending'
     and is_primary),
  1,
  'stable Case keeps a review Action until close'
);

select lives_ok(
  $$select public.close_case(
      '71000000-0000-0000-0000-000000000007',
      (select id from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      (select version from public.learning_cases
       where title = '异分母比较步骤不稳定'),
      timestamptz '2026-09-16 09:00:00+08'
    )$$,
  'the lead teacher can close a stable Case'
);

select is(
  (select status
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  'closed',
  'close_case moves stable to closed'
);

select is(
  (select version
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  6,
  'close_case increments the Case version once'
);

select is(
  (select closed_at is not null
   from public.learning_cases
   where title = '异分母比较步骤不稳定'),
  true,
  'closed_at is recorded'
);

select is(
  (select count(*)::int
   from public.case_actions
   where learning_case_id = (
       select id from public.learning_cases
       where title = '异分母比较步骤不稳定'
     )
     and status = 'pending'
     and is_primary),
  0,
  'closed Case has no pending primary Action'
);

select is(
  (select count(*)::int
   from public.case_events
   where event_type = 'case_closed'),
  1,
  'close_case writes one immutable close event'
);

reset role;

select throws_ok(
  $$update public.case_evidence
    set summary = '静默改写不应成功'
    where title = '异分母比较步骤不稳定'$$,
  'P0001',
  null,
  'finalized Evidence is append-only'
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

select is(
  (select count(*)::int from public.learning_cases),
  0,
  'Teacher B cannot read Teacher A Cases'
);

select throws_ok(
  $$select public.quick_capture_case(
      '71000000-0000-0000-0000-000000000008',
      '67000000-0000-0000-0000-000000000001',
      1,
      'knowledge',
      '跨学生写入不应成功',
      null,
      timestamptz '2026-09-17 09:00:00+08',
      '跨学生证据不应写入。',
      '跨学生 Action 不应写入',
      null
    )$$,
  'P0001',
  null,
  'Teacher B cannot Quick Capture for Student A'
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

select is(
  (select count(*)::int from public.organizations),
  0,
  'a user without membership cannot read organizations'
);

select throws_ok(
  $$select public.quick_capture_case(
      '71000000-0000-0000-0000-000000000009',
      '67000000-0000-0000-0000-000000000001',
      1,
      'knowledge',
      '无机构写入不应成功',
      null,
      timestamptz '2026-09-17 10:00:00+08',
      '无机构证据不应写入。',
      '无机构 Action 不应写入',
      null
    )$$,
  'P0001',
  null,
  'a user without membership cannot create a Case'
);

select throws_ok(
  $$insert into public.learning_cases (
      organization_id,
      student_subject_profile_id,
      owner_membership_id,
      case_type,
      title,
      first_observed_at,
      created_by_app_user_id,
      created_by_membership_id
    ) values (
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      'knowledge',
      '直接写入不应成功',
      timestamptz '2026-09-17 11:00:00+08',
      '10000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001'
    )$$,
  '42501',
  null,
  'authenticated clients cannot directly insert Learning Cases'
);

select * from finish();
rollback;
