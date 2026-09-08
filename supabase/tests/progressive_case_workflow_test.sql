begin;

select plan(41);

select is(
  (
    select count(*)::int
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'end_case_follow_up'
  ),
  1,
  'public end follow-up command exists'
);

select is(
  (
    select count(*)::int
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'record_case_progress'
  ),
  1,
  'public progress command exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'private'
      and pg_proc.proname = 'end_case_follow_up_v2'
  ),
  true,
  'private end follow-up implementation is security definer'
);

select is(
  (
    select prosecdef
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'private'
      and pg_proc.proname = 'record_case_progress_v2'
  ),
  true,
  'private progress implementation is security definer'
);

select is(
  has_function_privilege(
    'anon',
    'public.end_case_follow_up(uuid,uuid,integer,text,text,timestamp with time zone)',
    'execute'
  ),
  false,
  'anonymous clients cannot end follow-up'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.end_case_follow_up(uuid,uuid,integer,text,text,timestamp with time zone)',
    'execute'
  ),
  true,
  'authenticated members can reach the end follow-up boundary'
);

select is(
  has_function_privilege(
    'anon',
    'public.record_case_progress(uuid,uuid,integer,text,text,text,timestamp with time zone,boolean,uuid,integer,text,text,date,text,text)',
    'execute'
  ),
  false,
  'anonymous clients cannot record Case progress'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.record_case_progress(uuid,uuid,integer,text,text,text,timestamp with time zone,boolean,uuid,integer,text,text,date,text,text)',
    'execute'
  ),
  true,
  'authenticated members can reach the Case progress boundary'
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
      '7a000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1,
      'knowledge',
      '渐进式流程直接结束测试',
      '课堂里发现一次偶发错误。',
      timestamptz '2026-09-08 18:20:00+08',
      '课堂里发现一次偶发错误。',
      '补充证据并确认下一步',
      null
    )$$,
  'Teacher A can create a new Case for direct ending'
);

select is(
  (select status from public.learning_cases where title = '渐进式流程直接结束测试'),
  'new',
  'Quick Capture still starts in new state for RC1 compatibility'
);

select is(
  (
    select count(*)::int
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '渐进式流程直接结束测试'
    )
      and status = 'pending'
      and is_primary
  ),
  1,
  'legacy Quick Capture still has its generated primary Action'
);

select lives_ok(
  $$select public.end_case_follow_up(
      '7a000000-0000-0000-0000-000000000002',
      (select id from public.learning_cases where title = '渐进式流程直接结束测试'),
      1,
      'not_issue',
      '后来确认只是偶发现象。',
      timestamptz '2026-09-08 18:25:00+08'
    )$$,
  'a new Case can end immediately without fake stabilization'
);

select is(
  (select status from public.learning_cases where title = '渐进式流程直接结束测试'),
  'closed',
  'direct ending closes the Case'
);

select is(
  (
    select stable_at is null
    from public.learning_cases
    where title = '渐进式流程直接结束测试'
  ),
  true,
  'a not-issue closure does not fabricate stable_at'
);

select is(
  (
    select count(*)::int
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '渐进式流程直接结束测试'
    )
      and status = 'pending'
      and is_primary
  ),
  0,
  'ending follow-up cancels the current pending primary Action'
);

select is(
  (
    select metadata->>'closure_reason'
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases where title = '渐进式流程直接结束测试'
    )
      and event_type = 'case_closed'
    order by occurred_at desc, id desc
    limit 1
  ),
  'not_issue',
  'closure reason is preserved in immutable history'
);

select is(
  (select version from public.learning_cases where title = '渐进式流程直接结束测试'),
  2,
  'direct ending increments Case version exactly once'
);

select lives_ok(
  $$select public.end_case_follow_up(
      '7a000000-0000-0000-0000-000000000002',
      (select id from public.learning_cases where title = '渐进式流程直接结束测试'),
      1,
      'not_issue',
      '后来确认只是偶发现象。',
      timestamptz '2026-09-08 18:25:00+08'
    )$$,
  'retrying the same end operation returns its committed receipt'
);

select is(
  (
    select count(*)::int
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases where title = '渐进式流程直接结束测试'
    )
      and event_type = 'case_closed'
  ),
  1,
  'end retry does not duplicate the close event'
);

select set_config(
  'xueqing.progressive_closed_case_id',
  (select id::text from public.learning_cases where title = '渐进式流程直接结束测试'),
  true
);

select lives_ok(
  $$select public.quick_capture_case(
      '7a000000-0000-0000-0000-000000000003',
      '67000000-0000-0000-0000-000000000001',
      1,
      'knowledge',
      '渐进式记录进展测试',
      '用于验证一次自然记录可以继续、提醒或结束。',
      timestamptz '2026-09-08 18:30:00+08',
      '连续两题出现同类步骤错误。',
      '补充证据并确认下一步',
      null
    )$$,
  'Teacher A can create a Case for progress testing'
);

select lives_ok(
  $$select public.record_case_progress(
      '7a000000-0000-0000-0000-000000000004',
      (select id from public.learning_cases where title = '渐进式记录进展测试'),
      1,
      'intervention',
      '重新讲解步骤，并让学生当堂独立完成两题。',
      null,
      timestamptz '2026-09-08 18:35:00+08',
      true,
      (
        select id from public.case_actions
        where learning_case_id = (
          select id from public.learning_cases where title = '渐进式记录进展测试'
        )
          and status = 'pending'
          and is_primary
      ),
      1,
      'continue',
      null,
      null,
      null,
      null
    )$$,
  'one progress command can complete the current Action and simply continue'
);

select is(
  (select status from public.learning_cases where title = '渐进式记录进展测试'),
  'intervening',
  'an intervention progress update moves the Case into follow-up'
);

select is(
  (select version from public.learning_cases where title = '渐进式记录进展测试'),
  2,
  'one progress update increments the Case version once'
);

select is(
  (
    select count(*)::int
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '渐进式记录进展测试'
    )
      and status = 'pending'
      and is_primary
  ),
  0,
  'continue may intentionally leave an open Case without a forced Action'
);

select is(
  (
    select count(*)::int
    from public.interventions
    where learning_case_id = (
      select id from public.learning_cases where title = '渐进式记录进展测试'
    )
  ),
  1,
  'the natural progress update records the intervention fact'
);

select is(
  (
    select status
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '渐进式记录进展测试'
    )
    order by created_at asc, id asc
    limit 1
  ),
  'done',
  'the current Action is completed in the same progress transaction'
);

select is(
  (
    select count(*)::int
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases where title = '渐进式记录进展测试'
    )
      and event_type = 'action_completed'
  ),
  1,
  'progress keeps an immutable Action completion event'
);

select lives_ok(
  $$select public.record_case_progress(
      '7a000000-0000-0000-0000-000000000005',
      (select id from public.learning_cases where title = '渐进式记录进展测试'),
      2,
      'assessment',
      '能完成大部分步骤，但最后一步仍需要提醒。',
      'partial',
      timestamptz '2026-09-08 18:40:00+08',
      false,
      null,
      null,
      'remind',
      '下次再检查一次',
      date '2026-09-11',
      null,
      null
    )$$,
  'a progress update may schedule a reminder only when the teacher chooses it'
);

select is(
  (select version from public.learning_cases where title = '渐进式记录进展测试'),
  3,
  'reminder progress increments the Case version once'
);

select is(
  (select status from public.learning_cases where title = '渐进式记录进展测试'),
  'intervening',
  'partial verification keeps the Case in follow-up'
);

select is(
  (
    select count(*)::int
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '渐进式记录进展测试'
    )
      and status = 'pending'
      and is_primary
  ),
  1,
  'choosing remind creates exactly one pending primary Action'
);

select is(
  (
    select (due_at at time zone 'Asia/Shanghai')::date
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '渐进式记录进展测试'
    )
      and status = 'pending'
      and is_primary
  ),
  date '2026-09-11',
  'the optional reminder keeps the requested business date'
);

select lives_ok(
  $$select public.record_case_progress(
      '7a000000-0000-0000-0000-000000000006',
      (select id from public.learning_cases where title = '渐进式记录进展测试'),
      3,
      'assessment',
      '本次已经可以独立完成，未再出现同类错误。',
      'passed',
      timestamptz '2026-09-08 18:45:00+08',
      true,
      (
        select id from public.case_actions
        where learning_case_id = (
          select id from public.learning_cases where title = '渐进式记录进展测试'
        )
          and status = 'pending'
          and is_primary
      ),
      1,
      'close',
      null,
      null,
      'resolved',
      '本次验证后结束跟进。'
    )$$,
  'passed verification and end follow-up can be one atomic teacher action'
);

select is(
  (select status from public.learning_cases where title = '渐进式记录进展测试'),
  'closed',
  'the combined progress command closes the Case'
);

select is(
  (
    select stable_at is not null
    from public.learning_cases
    where title = '渐进式记录进展测试'
  ),
  true,
  'resolved + passed records a real stable boundary without an extra user click'
);

select is(
  (
    select count(*)::int
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '渐进式记录进展测试'
    )
      and status = 'pending'
      and is_primary
  ),
  0,
  'ending through progress leaves no pending primary Action'
);

select is(
  (
    select count(*)::int
    from public.assessments
    where learning_case_id = (
      select id from public.learning_cases where title = '渐进式记录进展测试'
    )
  ),
  2,
  'both verification facts remain in history'
);

select is(
  (
    select count(*)::int
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases where title = '渐进式记录进展测试'
    )
      and event_type = 'case_stabilized'
  ),
  1,
  'resolved + passed writes the stable lifecycle event automatically'
);

select is(
  (
    select metadata->>'closure_reason'
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases where title = '渐进式记录进展测试'
    )
      and event_type = 'case_closed'
    order by occurred_at desc, id desc
    limit 1
  ),
  'resolved',
  'combined ending records the chosen closure reason'
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
  format(
    $$select public.end_case_follow_up(
      '7a000000-0000-0000-0000-000000000007',
      %L::uuid,
      2,
      'other',
      null,
      null
    )$$,
    current_setting('xueqing.progressive_closed_case_id')
  ),
  'P0001',
  'teaching_fact_gate',
  'a teacher outside the real teaching relationship still cannot end the Case'
);

select throws_ok(
  format(
    $$select public.record_case_progress(
      '7a000000-0000-0000-0000-000000000008',
      %L::uuid,
      2,
      'observation',
      '越权写入测试',
      null,
      null,
      false,
      null,
      null,
      'continue',
      null,
      null,
      null,
      null
    )$$,
    current_setting('xueqing.progressive_closed_case_id')
  ),
  'P0001',
  'teaching_fact_gate',
  'a teacher outside the real teaching relationship still cannot record progress'
);

select * from finish();
rollback;
