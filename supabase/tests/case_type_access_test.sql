begin;

select plan(31);

select is(
  (
    select count(*)::int
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'organization_case_types'
  ),
  1,
  'organization Case type table exists'
);

select is(
  (
    select relrowsecurity
    from pg_class
    join pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'organization_case_types'
  ),
  true,
  'organization Case types have RLS enabled'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.organization_case_types',
    'select'
  ),
  true,
  'authenticated members can read Case types'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.organization_case_types',
    'insert'
  ),
  false,
  'authenticated clients cannot insert Case types directly'
);

select is(
  has_table_privilege(
    'anon',
    'public.organization_case_types',
    'select'
  ),
  false,
  'anon clients cannot read Case types'
);

select is(
  (
    select prosecdef
    from pg_proc
    join pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'create_organization_case_type'
  ),
  true,
  'creating a Case type is a security-definer command'
);

select is(
  (
    select prosecdef
    from pg_proc
    join pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'quick_capture_case_with_type'
  ),
  true,
  'custom Quick Capture is a security-definer command'
);

select is(
  has_function_privilege(
    'anon',
    'public.create_organization_case_type(uuid,text,text)',
    'execute'
  ),
  false,
  'anon cannot create Case types'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.create_organization_case_type(uuid,text,text)',
    'execute'
  ),
  true,
  'authenticated clients can use the guarded create command'
);

select is(
  has_function_privilege(
    'anon',
    'public.quick_capture_case_with_type(uuid,uuid,integer,text,text,text,timestamptz,text,text,timestamptz,uuid)',
    'execute'
  ),
  false,
  'anon cannot use custom Quick Capture'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.quick_capture_case(uuid,uuid,integer,text,text,text,timestamptz,text,text,timestamptz)',
    'execute'
  ),
  true,
  'the original Quick Capture signature remains available'
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
  $$select public.create_organization_case_type(
      '00000000-0000-0000-0000-000000000001',
      '自定义归因',
      'knowledge'
    )$$,
  'an organization admin can create a custom type'
);

select is(
  (
    select count(*)::int
    from public.organization_case_types
    where display_name = '自定义归因'
  ),
  1,
  'the custom type is visible in its own organization'
);

select is(
  (
    select base_case_type
    from public.organization_case_types
    where display_name = '自定义归因'
  ),
  'knowledge',
  'a custom type keeps its stable base classification'
);

select is(
  (
    select status
    from public.organization_case_types
    where display_name = '自定义归因'
  ),
  'active',
  'new custom types are active'
);

select lives_ok(
  $$select public.create_organization_case_type(
      '00000000-0000-0000-0000-000000000001',
      '迁移验证',
      'exam_strategy'
    )$$,
  'an organization admin can create a second custom type'
);

select is(
  (
    select count(*)::int
    from public.organization_case_types
  ),
  2,
  'an organization member cannot see other organizations Case types'
);

select set_config(
  'xueqing.test_case_type_id',
  (
    select id::text
    from public.organization_case_types
    where display_name = '迁移验证'
  ),
  true
);

select lives_ok(
  $$select public.quick_capture_case_with_type(
      '72000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1,
      'exam_strategy',
      '综合题审题分类验证',
      '自定义类型只改变分类，不改变 Case 流程。',
      timestamptz '2026-09-03 09:00:00+08',
      '面对综合题时没有先识别已知条件。',
      '补充一道综合题并核对审题过程',
      timestamptz '2026-09-04 09:00:00+08',
      current_setting('xueqing.test_case_type_id')::uuid
    )$$,
  'an organization admin can create a Case with an active custom type'
);

select is(
  (
    select organization_case_type_id
    from public.learning_cases
    where title = '综合题审题分类验证'
  )::text,
  current_setting('xueqing.test_case_type_id'),
  'the Case stores the custom type reference'
);

select is(
  (
    select case_type_label_snapshot
    from public.learning_cases
    where title = '综合题审题分类验证'
  ),
  '迁移验证',
  'the Case stores the original custom label'
);

select is(
  (
    select metadata ->> 'organization_case_type_id'
    from public.case_events
    where learning_case_id = (
      select id
      from public.learning_cases
      where title = '综合题审题分类验证'
    )
  ),
  current_setting('xueqing.test_case_type_id'),
  'the lifecycle event identifies the custom type'
);

select lives_ok(
  $$select public.rename_organization_case_type(
      current_setting('xueqing.test_case_type_id')::uuid,
      '迁移验证（已更新）',
      1
    )$$,
  'an organization admin can rename an active custom type'
);

select is(
  (
    select display_name
    from public.organization_case_types
    where id = current_setting('xueqing.test_case_type_id')::uuid
  ),
  '迁移验证（已更新）',
  'renaming updates the configurable label'
);

select is(
  (
    select case_type_label_snapshot
    from public.learning_cases
    where title = '综合题审题分类验证'
  ),
  '迁移验证',
  'renaming does not rewrite historical Case labels'
);

select lives_ok(
  $$select public.archive_organization_case_type(
      current_setting('xueqing.test_case_type_id')::uuid,
      2
    )$$,
  'an organization admin can archive a custom type'
);

select is(
  (
    select status
    from public.organization_case_types
    where id = current_setting('xueqing.test_case_type_id')::uuid
  ),
  'archived',
  'archiving removes a type from future use'
);

select throws_ok(
  $$select public.quick_capture_case_with_type(
      '72000000-0000-0000-0000-000000000002',
      '67000000-0000-0000-0000-000000000001',
      1,
      'exam_strategy',
      '归档类型不应创建',
      null,
      timestamptz '2026-09-03 10:00:00+08',
      '归档类型不应写入。',
      '归档类型 Action 不应写入',
      null,
      current_setting('xueqing.test_case_type_id')::uuid
    )$$,
  'P0001',
  null,
  'an archived custom type cannot create a new Case'
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
  (select count(*)::int from public.organization_case_types),
  0,
  'Teacher B cannot read Teacher A Case types'
);

select throws_ok(
  $$select public.create_organization_case_type(
      '00000000-0000-0000-0000-000000000001',
      '跨机构类型',
      'knowledge'
    )$$,
  'P0001',
  null,
  'Teacher B cannot create a type in Teacher A organization'
);

select throws_ok(
  $$select public.rename_organization_case_type(
      current_setting('xueqing.test_case_type_id')::uuid,
      '越权重命名',
      2
    )$$,
  'P0001',
  null,
  'Teacher B cannot rename Teacher A Case types'
);

set local role anon;

select throws_ok(
  $$select * from public.organization_case_types$$,
  '42501',
  null,
  'anon cannot read Case types'
);

reset role;

select * from finish();

rollback;
