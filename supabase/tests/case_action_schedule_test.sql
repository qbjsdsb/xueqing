begin;

select plan(28);

select is(
  (
    select count(*)::int
    from pg_proc
    join pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'reschedule_case_action'
  ),
  1,
  'reschedule command exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    join pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'reschedule_case_action'
  ),
  true,
  'reschedule command is security definer'
);

select is(
  has_function_privilege(
    'anon',
    'public.reschedule_case_action(uuid,uuid,uuid,integer,integer,date)',
    'execute'
  ),
  false,
  'anon cannot execute the reschedule command'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.reschedule_case_action(uuid,uuid,uuid,integer,integer,date)',
    'execute'
  ),
  true,
  'authenticated can execute the reschedule command'
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
      '72000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1,
      'knowledge',
      '改期边界测试',
      '用于验证 Action 改期的并发和日期语义。',
      timestamptz '2026-09-04 09:00:00+08',
      '课堂中记录了一个需要继续跟进的学习问题。',
      '安排一次改期后的跟进',
      null
    )$$,
  'Teacher A can create a Case for reschedule tests'
);

select is(
  (
    select count(*)::int
    from public.case_actions
    where learning_case_id = (
      select id
      from public.learning_cases
      where title = '改期边界测试'
    )
      and status = 'pending'
      and is_primary
  ),
  1,
  'the Case starts with one pending primary Action'
);

select is(
  (
    select version
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '改期边界测试'
    )
      and is_primary
  ),
  1,
  'the Action starts at version one'
);

select is(
  (
    select version
    from public.learning_cases
    where title = '改期边界测试'
  ),
  1,
  'the Case starts at version one'
);

select lives_ok(
  $$select public.reschedule_case_action(
      '72000000-0000-0000-0000-000000000002',
      (
        select id
        from public.case_actions
        where learning_case_id = (
          select id from public.learning_cases where title = '改期边界测试'
        )
          and is_primary
      ),
      (
        select id from public.learning_cases where title = '改期边界测试'
      ),
      1,
      1,
      (now() at time zone 'Asia/Shanghai')::date + 2
    )$$,
  'Teacher A can reschedule a pending primary Action'
);

select is(
  (
    select version
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '改期边界测试'
    )
      and is_primary
  ),
  2,
  'rescheduling increments the Action version'
);

select is(
  (
    select version
    from public.learning_cases
    where title = '改期边界测试'
  ),
  2,
  'rescheduling increments the Case version'
);

select is(
  (
    select (due_at at time zone 'Asia/Shanghai')::date
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '改期边界测试'
    )
      and is_primary
  ),
  (now() at time zone 'Asia/Shanghai')::date + 2,
  'rescheduling stores the selected organization business date'
);

select is(
  (
    select count(*)::int
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases where title = '改期边界测试'
    )
      and event_type = 'action_rescheduled'
  ),
  1,
  'rescheduling writes one immutable Action event'
);

select lives_ok(
  $$select public.reschedule_case_action(
      '72000000-0000-0000-0000-000000000002',
      (
        select id
        from public.case_actions
        where learning_case_id = (
          select id from public.learning_cases where title = '改期边界测试'
        )
          and is_primary
      ),
      (
        select id from public.learning_cases where title = '改期边界测试'
      ),
      1,
      1,
      (now() at time zone 'Asia/Shanghai')::date + 3
    )$$,
  'repeating the same operation id returns the committed result'
);

select is(
  (
    select (due_at at time zone 'Asia/Shanghai')::date
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '改期边界测试'
    )
      and is_primary
  ),
  (now() at time zone 'Asia/Shanghai')::date + 2,
  'an idempotent retry does not overwrite the original date'
);

select is(
  (
    select count(*)::int
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases where title = '改期边界测试'
    )
      and event_type = 'action_rescheduled'
  ),
  1,
  'an idempotent retry does not duplicate the Action event'
);

select throws_ok(
  $$select public.reschedule_case_action(
      '72000000-0000-0000-0000-000000000003',
      (
        select id
        from public.case_actions
        where learning_case_id = (
          select id from public.learning_cases where title = '改期边界测试'
        )
          and is_primary
      ),
      (
        select id from public.learning_cases where title = '改期边界测试'
      ),
      2,
      1,
      (now() at time zone 'Asia/Shanghai')::date + 4
    )$$,
  'P0001',
  null,
  'a stale Action version is rejected'
);

select is(
  (
    select version
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '改期边界测试'
    )
      and is_primary
  ),
  2,
  'a stale Action command leaves the Action unchanged'
);

select is(
  (
    select version
    from public.learning_cases
    where title = '改期边界测试'
  ),
  2,
  'a stale Action command leaves the Case unchanged'
);

select lives_ok(
  $$select public.reschedule_case_action(
      '72000000-0000-0000-0000-000000000004',
      (
        select id
        from public.case_actions
        where learning_case_id = (
          select id from public.learning_cases where title = '改期边界测试'
        )
          and is_primary
      ),
      (
        select id from public.learning_cases where title = '改期边界测试'
      ),
      2,
      2,
      null
    )$$,
  'Teacher A can move an Action back to unscheduled'
);

select is(
  (
    select due_at
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '改期边界测试'
    )
      and is_primary
  ),
  null,
  'an unscheduled Action has no due date'
);

select is(
  (
    select version
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '改期边界测试'
    )
      and is_primary
  ),
  3,
  'moving an Action back to unscheduled increments its version'
);

select is(
  (
    select version
    from public.learning_cases
    where title = '改期边界测试'
  ),
  3,
  'moving an Action back to unscheduled increments the Case version'
);

select is(
  (
    select count(*)::int
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases where title = '改期边界测试'
    )
      and event_type = 'action_rescheduled'
  ),
  2,
  'each committed schedule change has one Action event'
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
  $$select public.reschedule_case_action(
      '72000000-0000-0000-0000-000000000005',
      (
        select id
        from public.case_actions
        where learning_case_id = (
          select id from public.learning_cases where title = '改期边界测试'
        )
          and is_primary
      ),
      (
        select id from public.learning_cases where title = '改期边界测试'
      ),
      3,
      3,
      (now() at time zone 'Asia/Shanghai')::date + 5
    )$$,
  'P0001',
  null,
  'Teacher B cannot reschedule Teacher A Action'
);

reset role;
set local role authenticated;

select throws_ok(
  $$update public.case_actions
     set due_at = now()
   where id = (
     select id
     from public.case_actions
     where learning_case_id = (
       select id from public.learning_cases where title = '改期边界测试'
     )
       and is_primary
   )$$,
  '42501',
  null,
  'authenticated clients cannot directly update Actions'
);

select is(
  has_table_privilege('authenticated', 'public.operation_receipts', 'select'),
  false,
  'authenticated clients cannot inspect operation receipts'
);

reset role;
set local role anon;

select throws_ok(
  $$select public.reschedule_case_action(
      '72000000-0000-0000-0000-000000000006',
      '00000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      1,
      1,
      null
    )$$,
  '42501',
  null,
  'anonymous clients cannot execute the reschedule command'
);

select * from finish();
rollback;
