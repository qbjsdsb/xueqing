begin;

select plan(6);

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
      '7b000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      (
        select version
        from public.student_subject_profiles
        where id = '67000000-0000-0000-0000-000000000001'
      ),
      'knowledge',
      'New Case 待办完成兼容测试',
      '用于验证历史 new Case 上的待办可以只完成。',
      timestamptz '2026-09-09 09:00:00+08',
      '先记录一个真实学习表现，再设置一个提醒。',
      '只需要完成的历史提醒',
      null
    )$$,
  'Teacher A can create a new Case with a pending reminder'
);

select is(
  (
    select status
    from public.learning_cases
    where title = 'New Case 待办完成兼容测试'
  ),
  'new',
  'the compatibility fixture remains a new Case before completion'
);

select is(
  (
    select count(*)::int
    from public.case_actions
    where learning_case_id = (
      select id
      from public.learning_cases
      where title = 'New Case 待办完成兼容测试'
    )
      and status = 'pending'
      and is_primary
  ),
  1,
  'the new Case starts with one pending primary reminder'
);

select lives_ok(
  $$select public.complete_case_action(
      '7b000000-0000-0000-0000-000000000002',
      (
        select id
        from public.case_actions
        where learning_case_id = (
          select id
          from public.learning_cases
          where title = 'New Case 待办完成兼容测试'
        )
          and status = 'pending'
          and is_primary
      ),
      (
        select id
        from public.learning_cases
        where title = 'New Case 待办完成兼容测试'
      ),
      (
        select version
        from public.learning_cases
        where title = 'New Case 待办完成兼容测试'
      ),
      (
        select version
        from public.case_actions
        where learning_case_id = (
          select id
          from public.learning_cases
          where title = 'New Case 待办完成兼容测试'
        )
          and status = 'pending'
          and is_primary
      ),
      null,
      null,
      null
    )$$,
  'Teacher A can complete a pending reminder while the Case is still new'
);

select is(
  (
    select count(*)::int
    from public.case_actions
    where learning_case_id = (
      select id
      from public.learning_cases
      where title = 'New Case 待办完成兼容测试'
    )
      and status = 'pending'
      and is_primary
  ),
  0,
  'completion-only does not fabricate a successor reminder for a new Case'
);

select is(
  (
    select status
    from public.learning_cases
    where title = 'New Case 待办完成兼容测试'
  ),
  'new',
  'completing a reminder does not pretend the new Case was confirmed'
);

select * from finish();
rollback;
