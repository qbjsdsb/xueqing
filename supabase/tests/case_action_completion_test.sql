begin;

select plan(35);

select is(
  (
    select count(*)::int
    from pg_proc
    join pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'complete_case_action'
  ),
  1,
  'complete command exists'
);

select is(
  (
    select count(*)::int
    from pg_proc
    join pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'private'
      and pg_proc.proname = 'complete_case_action_v2'
  ),
  1,
  'privileged completion implementation is kept in private schema'
);

select is(
  (
    select prosecdef
    from pg_proc
    join pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'private'
      and pg_proc.proname = 'complete_case_action_v2'
  ),
  true,
  'private completion implementation is security definer'
);

select is(
  (
    select prosecdef
    from pg_proc
    join pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'complete_case_action'
  ),
  true,
  'complete command is security definer'
);

select is(
  has_function_privilege(
    'anon',
    'public.complete_case_action(uuid,uuid,uuid,integer,integer,text,text,date)',
    'execute'
  ),
  false,
  'anonymous clients cannot execute the complete command'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.complete_case_action(uuid,uuid,uuid,integer,integer,text,text,date)',
    'execute'
  ),
  true,
  'authenticated teachers can execute the complete command'
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
      '73000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1,
      'knowledge',
      'Action 完成闭环测试',
      '用于验证完成行动会原子安排下一行动。',
      timestamptz '2026-09-06 09:00:00+08',
      '观察到需要继续跟进的学习表现。',
      '先整理并确认问题',
      null
    )$$,
  'Teacher A can create the Case used by completion tests'
);

select is(
  (
    select status
    from public.learning_cases
    where title = 'Action 完成闭环测试'
  ),
  'new',
  'Quick Capture starts the completion test Case in new state'
);

select lives_ok(
  $$select public.confirm_case(
      '73000000-0000-0000-0000-000000000002',
      (select id from public.learning_cases where title = 'Action 完成闭环测试'),
      1,
      '确认后继续练习',
      null
    )$$,
  'Teacher A can confirm the Case before completing an Action'
);

select is(
  (
    select status
    from public.learning_cases
    where title = 'Action 完成闭环测试'
  ),
  'confirmed',
  'confirmation puts the Case in an active formal state'
);

select is(
  (
    select version
    from public.learning_cases
    where title = 'Action 完成闭环测试'
  ),
  2,
  'confirmation increments the Case version once'
);

select is(
  (
    select count(*)::int
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and status = 'pending'
      and is_primary
  ),
  1,
  'the confirmed Case has one pending primary Action'
);

select is(
  (
    select version
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and title = '确认后继续练习'
  ),
  1,
  'the Action starts at version one before completion'
);

select lives_ok(
  $$select public.complete_case_action(
      '73000000-0000-0000-0000-000000000003',
      (
        select id
        from public.case_actions
        where learning_case_id = (
          select id from public.learning_cases where title = 'Action 完成闭环测试'
        )
          and title = '确认后继续练习'
      ),
      (select id from public.learning_cases where title = 'Action 完成闭环测试'),
      2,
      1,
      'verify',
      '完成后安排一次验证',
      date '2026-09-10'
    )$$,
  'Teacher A can complete a primary Action and schedule its successor'
);

select is(
  (
    select status
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and title = '确认后继续练习'
  ),
  'done',
  'the completed Action is marked done'
);

select is(
  (
    select is_primary
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and title = '确认后继续练习'
  ),
  false,
  'the completed Action is no longer primary'
);

select is(
  (
    select completed_at is not null
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and title = '确认后继续练习'
  ),
  true,
  'the completed Action records a completion timestamp'
);

select is(
  (
    select completed_by_membership_id
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and title = '确认后继续练习'
  ),
  '61000000-0000-0000-0000-000000000001'::uuid,
  'the completed Action records the current teacher'
);

select is(
  (
    select count(*)::int
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and status = 'pending'
      and is_primary
  ),
  1,
  'completion leaves exactly one pending primary Action'
);

select is(
  (
    select status
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and title = '完成后安排一次验证'
  ),
  'pending',
  'the successor Action remains pending'
);

select is(
  (
    select action_type
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and title = '完成后安排一次验证'
  ),
  'verify',
  'the successor keeps the selected semantic Action type'
);

select is(
  (
    select (due_at at time zone 'Asia/Shanghai')::date
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and title = '完成后安排一次验证'
  ),
  date '2026-09-10',
  'the successor stores the requested due date'
);

select is(
  (
    select version
    from public.learning_cases
    where title = 'Action 完成闭环测试'
  ),
  3,
  'completion increments the Case version once'
);

select is(
  (
    select count(*)::int
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and event_type = 'action_completed'
  ),
  1,
  'completion writes one immutable Action event'
);

select lives_ok(
  $$select public.complete_case_action(
      '73000000-0000-0000-0000-000000000003',
      (
        select id
        from public.case_actions
        where learning_case_id = (
          select id from public.learning_cases where title = 'Action 完成闭环测试'
        )
          and title = '确认后继续练习'
      ),
      (select id from public.learning_cases where title = 'Action 完成闭环测试'),
      2,
      1,
      'practice',
      '这次重试不应覆盖下一行动',
      date '2026-09-11'
    )$$,
  'repeating the same operation id returns the committed completion result'
);

select is(
  (
    select title
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and status = 'pending'
      and is_primary
  ),
  '完成后安排一次验证',
  'an idempotent retry does not replace the successor Action'
);

select is(
  (
    select count(*)::int
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and event_type = 'action_completed'
  ),
  1,
  'an idempotent retry does not duplicate the Action event'
);

select throws_ok(
  $$select public.complete_case_action(
      '73000000-0000-0000-0000-000000000004',
      (
        select id
        from public.case_actions
        where learning_case_id = (
          select id from public.learning_cases where title = 'Action 完成闭环测试'
        )
          and title = '确认后继续练习'
      ),
      (select id from public.learning_cases where title = 'Action 完成闭环测试'),
      3,
      1,
      'verify',
      '不应创建',
      null
    )$$,
  'P0001',
  null,
  'a stale completed Action version is rejected'
);

select is(
  (
    select status
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and title = '确认后继续练习'
  ),
  'done',
  'a stale completion attempt leaves the completed Action unchanged'
);

select is(
  (
    select version
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and title = '确认后继续练习'
  ),
  2,
  'a stale completion attempt leaves the Action version unchanged'
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
  $$select public.complete_case_action(
      '73000000-0000-0000-0000-000000000005',
      (
        select id
        from public.case_actions
        where learning_case_id = (
          select id from public.learning_cases where title = 'Action 完成闭环测试'
        )
          and title = '完成后安排一次验证'
      ),
      (select id from public.learning_cases where title = 'Action 完成闭环测试'),
      3,
      1,
      'review',
      '不应跨学生完成',
      null
    )$$,
  'P0001',
  null,
  'a teacher without a legal assignment cannot complete the Action'
);

reset role;

update public.organizations
set time_zone = 'Pacific/Kiritimati'
where id = '7a000000-0000-0000-0000-000000000005';

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
  $$select public.complete_case_action(
      '73000000-0000-0000-0000-000000000006',
      (
        select id
        from public.case_actions
        where learning_case_id = (
          select id from public.learning_cases where title = 'Action 完成闭环测试'
        )
          and title = '完成后安排一次验证'
      ),
      (select id from public.learning_cases where title = 'Action 完成闭环测试'),
      3,
      1,
      'review',
      '高时区下的下一步',
      date '2026-09-10'
    )$$,
  'the organization date is converted server-side for UTC+14'
);

select is(
  (
    select (due_at at time zone 'Pacific/Kiritimati')::date
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = 'Action 完成闭环测试'
    )
      and title = '高时区下的下一步'
  ),
  date '2026-09-10',
  'a selected local date remains the same date in a UTC+14 organization'
);

set local role authenticated;

select throws_ok(
  $$update public.case_actions
     set title = '客户端不能直接修改'
   where id = (
     select id
     from public.case_actions
     where learning_case_id = (
       select id from public.learning_cases where title = 'Action 完成闭环测试'
     )
       and status = 'pending'
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

select * from finish();
rollback;
