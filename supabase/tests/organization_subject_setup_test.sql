begin;

select plan(26);

select is(
  to_regprocedure('public.list_organization_subject_catalog(uuid)') is not null,
  true,
  'subject catalog function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.list_organization_subject_catalog(uuid)'
    )
  ),
  true,
  'subject catalog function is security definer'
);

select is(
  to_regprocedure('public.create_organization_subject(uuid,uuid,uuid)') is not null,
  true,
  'organization subject setup function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.create_organization_subject(uuid,uuid,uuid)'
    )
  ),
  true,
  'organization subject setup function is security definer'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_organization_subject_catalog(uuid)',
    'execute'
  ),
  false,
  'anon cannot list the subject catalog'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.list_organization_subject_catalog(uuid)',
    'execute'
  ),
  true,
  'authenticated can list the subject catalog through the guarded command'
);

select is(
  has_function_privilege(
    'anon',
    'public.create_organization_subject(uuid,uuid,uuid)',
    'execute'
  ),
  false,
  'anon cannot create organization subjects'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.create_organization_subject(uuid,uuid,uuid)',
    'execute'
  ),
  true,
  'authenticated can create organization subjects through the guarded command'
);

select is(
  has_table_privilege('authenticated', 'public.subjects', 'insert'),
  false,
  'authenticated cannot insert global subjects directly'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.organization_subjects',
    'insert'
  ),
  false,
  'authenticated cannot insert organization subjects directly'
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
  $$
    select set_config(
      'xueqing.subject_catalog',
      public.list_organization_subject_catalog(
        '00000000-0000-0000-0000-000000000001'
      )::text,
      true
    )
  $$,
  'an organization manager can load the available subject catalog'
);

select is(
  jsonb_array_length(current_setting('xueqing.subject_catalog')::jsonb),
  1,
  'the catalog contains one subject not yet enabled for Organization A'
);

select is(
  current_setting('xueqing.subject_catalog')::jsonb -> 0 ->> 'code',
  'english',
  'the available catalog item has the expected code'
);

select is(
  current_setting('xueqing.subject_catalog')::jsonb -> 0 ->> 'display_name',
  '英语',
  'the available catalog item has the expected display name'
);

select lives_ok(
  $$
    select set_config(
      'xueqing.subject_setup',
      public.create_organization_subject(
        '74000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000001',
        '63000000-0000-0000-0000-000000000002'
      )::text,
      true
    )
  $$,
  'a manager can enable a global subject for the organization'
);

select is(
  current_setting('xueqing.subject_setup')::jsonb ->> 'subject_name',
  '英语',
  'subject setup returns the enabled subject'
);

select isnt(
  current_setting('xueqing.subject_setup')::jsonb ->> 'organization_subject_id',
  null,
  'subject setup returns the organization subject id'
);

select is(
  (
    select organization_subject.display_name
    from public.organization_subjects as organization_subject
    where organization_subject.organization_id =
        '00000000-0000-0000-0000-000000000001'
      and organization_subject.subject_id =
        '63000000-0000-0000-0000-000000000002'
  ),
  '英语',
  'the organization subject stores the global subject name'
);

reset role;

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where organization_id =
        '00000000-0000-0000-0000-000000000001'
      and operation_id =
        '74000000-0000-0000-0000-000000000001'
      and command_type = 'create_organization_subject'
      and target_type = 'organization'
      and result is not null
      and committed_at is not null
  ),
  1,
  'subject setup commits one operation receipt'
);

set local role authenticated;

select lives_ok(
  $$
    select public.create_organization_subject(
      '74000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '63000000-0000-0000-0000-000000000002'
    )
  $$,
  'repeating the same operation id returns the committed result'
);

reset role;

select is(
  (
    select count(*)::int
    from public.organization_subjects as organization_subject
    where organization_subject.organization_id =
        '00000000-0000-0000-0000-000000000001'
      and organization_subject.subject_id =
        '63000000-0000-0000-0000-000000000002'
  ),
  1,
  'retrying subject setup does not create a duplicate organization subject'
);

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where organization_id =
        '00000000-0000-0000-0000-000000000001'
      and operation_id =
        '74000000-0000-0000-0000-000000000001'
  ),
  1,
  'retrying subject setup keeps one operation receipt'
);

set local role authenticated;

select throws_ok(
  $$
    select public.create_organization_subject(
      '74000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000001',
      '63000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  null,
  'a manager cannot enable a subject for another organization'
);

select throws_ok(
  $$
    select public.create_organization_subject(
      '74000000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000001',
      '63000000-0000-0000-0000-000000000002'
    )
  $$,
  'P0001',
  null,
  'a second operation cannot enable an already enabled subject'
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
  $$
    select public.list_organization_subject_catalog(
      '00000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  null,
  'a teacher without management role cannot list the subject catalog'
);

select throws_ok(
  $$
    select public.create_organization_subject(
      '74000000-0000-0000-0000-000000000004',
      '00000000-0000-0000-0000-000000000001',
      '63000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  null,
  'a teacher cannot create an organization subject'
);

select * from finish();

rollback;
