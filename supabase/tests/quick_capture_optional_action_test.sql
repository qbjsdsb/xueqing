begin;

select plan(15);

select is(
  has_function_privilege(
    'authenticated',
    'private.quick_capture_case_v2(uuid,uuid,integer,text,text,text,timestamptz,text,text,timestamptz,uuid)',
    'execute'
  ),
  false,
  'authenticated clients cannot call the Quick Capture helper directly'
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

select set_config(
  'xueqing.quick_capture_optional_result',
  public.quick_capture_case(
    '7a000000-0000-0000-0000-000000000001',
    '67000000-0000-0000-0000-000000000001',
    1,
    'knowledge',
    '课堂快速记录不强制待办',
    '先保留课堂事实，稍后再决定是否需要提醒。',
    timestamptz '2026-09-08 15:00:00+08',
    '学生今天读题时两次漏看限制词。',
    null,
    null
  )::text,
  true
);

select is(
  current_setting('xueqing.quick_capture_optional_result')::jsonb->>'action_id',
  null,
  'Quick Capture receipt has no Action when the teacher did not request one'
);

select is(
  (
    select count(*)::int
    from public.learning_cases
    where title = '课堂快速记录不强制待办'
  ),
  1,
  'Quick Capture still creates exactly one Case'
);

select is(
  (
    select count(*)::int
    from public.case_evidence
    where learning_case_id = (
      current_setting('xueqing.quick_capture_optional_result')::jsonb
        ->>'case_id'
    )::uuid
  ),
  1,
  'Quick Capture still records the classroom Evidence'
);

select is(
  (
    select count(*)::int
    from public.case_actions
    where learning_case_id = (
      current_setting('xueqing.quick_capture_optional_result')::jsonb
        ->>'case_id'
    )::uuid
  ),
  0,
  'Quick Capture creates no hidden Action by default'
);

select is(
  (
    select status
    from public.learning_cases
    where id = (
      current_setting('xueqing.quick_capture_optional_result')::jsonb
        ->>'case_id'
    )::uuid
  ),
  'new',
  'a captured Case without an Action remains a valid new Case'
);

select is(
  (
    select metadata ? 'action_id'
    from public.case_events
    where learning_case_id = (
      current_setting('xueqing.quick_capture_optional_result')::jsonb
        ->>'case_id'
    )::uuid
      and event_type = 'case_created'
  ),
  false,
  'case_created metadata does not manufacture an Action reference'
);

select is(
  public.quick_capture_case(
    '7a000000-0000-0000-0000-000000000001',
    '67000000-0000-0000-0000-000000000001',
    1,
    'knowledge',
    '这次重试不应写入',
    '这段描述不应写入。',
    timestamptz '2026-09-08 15:05:00+08',
    '这段证据不应写入。',
    null,
    null
  )->>'case_id',
  current_setting('xueqing.quick_capture_optional_result')::jsonb->>'case_id',
  'retrying the optional-Action capture returns the original Case'
);

select is(
  (
    select count(*)::int
    from public.learning_cases
    where title in ('课堂快速记录不强制待办', '这次重试不应写入')
  ),
  1,
  'retrying the same operation does not duplicate the Case'
);

select throws_ok(
  $$select public.quick_capture_case(
      '7a000000-0000-0000-0000-000000000002',
      '67000000-0000-0000-0000-000000000001',
      1,
      'knowledge',
      '无标题却有提醒日期',
      null,
      timestamptz '2026-09-08 15:10:00+08',
      '不允许只有提醒日期。',
      null,
      timestamptz '2026-09-09 09:00:00+08'
    )$$,
  'P0001',
  null,
  'a reminder date without an Action title is rejected'
);

select set_config(
  'xueqing.quick_capture_custom_type_result',
  public.create_organization_case_type(
    '00000000-0000-0000-0000-000000000001',
    '课堂观察专项',
    'habit'
  )::text,
  true
);

select set_config(
  'xueqing.quick_capture_custom_result',
  public.quick_capture_case_with_type(
    '7a000000-0000-0000-0000-000000000003',
    '67000000-0000-0000-0000-000000000001',
    1,
    'habit',
    '课堂观察也不强制待办',
    null,
    timestamptz '2026-09-08 15:20:00+08',
    '学生今天开始主动在题干上做标记。',
    null,
    null,
    (
      current_setting('xueqing.quick_capture_custom_type_result')::jsonb
        ->>'id'
    )::uuid
  )::text,
  true
);

select is(
  current_setting('xueqing.quick_capture_custom_result')::jsonb->>'action_id',
  null,
  'custom-type Quick Capture also allows no Action'
);

select is(
  (
    select organization_case_type_id::text
    from public.learning_cases
    where id = (
      current_setting('xueqing.quick_capture_custom_result')::jsonb
        ->>'case_id'
    )::uuid
  ),
  current_setting('xueqing.quick_capture_custom_type_result')::jsonb->>'id',
  'custom-type Quick Capture keeps the selected taxonomy'
);

select is(
  (
    select count(*)::int
    from public.case_actions
    where learning_case_id = (
      current_setting('xueqing.quick_capture_custom_result')::jsonb
        ->>'case_id'
    )::uuid
  ),
  0,
  'custom-type Quick Capture creates no hidden Action'
);

select set_config(
  'xueqing.quick_capture_legacy_result',
  public.quick_capture_case(
    '7a000000-0000-0000-0000-000000000004',
    '67000000-0000-0000-0000-000000000001',
    1,
    'knowledge',
    '显式提醒仍然兼容',
    null,
    timestamptz '2026-09-08 15:30:00+08',
    '老师明确要求提醒时仍应创建 Action。',
    '下周再抽查一次',
    timestamptz '2026-09-15 09:00:00+08'
  )::text,
  true
);

select isnt(
  current_setting('xueqing.quick_capture_legacy_result')::jsonb->>'action_id',
  null,
  'existing callers can still explicitly create an Action'
);

select is(
  (
    select count(*)::int
    from public.case_actions
    where learning_case_id = (
      current_setting('xueqing.quick_capture_legacy_result')::jsonb
        ->>'case_id'
    )::uuid
      and status = 'pending'
      and is_primary
  ),
  1,
  'an explicit Quick Capture reminder still creates one primary Action'
);

select * from finish();
rollback;
