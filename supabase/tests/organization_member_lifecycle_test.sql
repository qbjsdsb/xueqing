begin;

select plan(35);

select is(
  (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'organization_memberships'
      and column_name = 'version'
  ),
  1,
  'organization memberships have an optimistic version'
);

select is(
  to_regprocedure('public.list_organization_members(uuid)') is not null,
  true,
  'member roster function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure('public.list_organization_members(uuid)')
  ),
  true,
  'member roster function is security definer'
);

select is(
  to_regprocedure(
    'public.update_organization_membership_status(uuid,uuid,uuid,integer,text)'
  ) is not null,
  true,
  'member lifecycle function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.update_organization_membership_status(uuid,uuid,uuid,integer,text)'
    )
  ),
  true,
  'member lifecycle function is security definer'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_organization_members(uuid)',
    'execute'
  ),
  false,
  'anon cannot list organization members'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.list_organization_members(uuid)',
    'execute'
  ),
  true,
  'authenticated can list members through the guarded command'
);

select is(
  has_function_privilege(
    'anon',
    'public.update_organization_membership_status(uuid,uuid,uuid,integer,text)',
    'execute'
  ),
  false,
  'anon cannot update member status'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.update_organization_membership_status(uuid,uuid,uuid,integer,text)',
    'execute'
  ),
  true,
  'authenticated can update members through the guarded command'
);

select is(
  has_table_privilege('authenticated', 'public.organization_memberships', 'update'),
  false,
  'authenticated cannot update memberships directly'
);

select is(
  has_table_privilege('authenticated', 'public.membership_subject_scopes', 'update'),
  false,
  'authenticated cannot update scopes directly'
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
      'xueqing.member_list',
      (
        select coalesce(jsonb_agg(item), '[]'::jsonb)::text
        from public.list_organization_members(
          '00000000-0000-0000-0000-000000000001'
        ) as item
      ),
      true
    )
  $$,
  'an organization manager can load member versions and statuses'
);

select is(
  jsonb_array_length(current_setting('xueqing.member_list')::jsonb),
  2,
  'member roster contains both fictional organization members'
);

select is(
  (
    select (item ->> 'version')::int
    from jsonb_array_elements(current_setting('xueqing.member_list')::jsonb) as item
    where item ->> 'membership_id' =
      '61000000-0000-0000-0000-000000000002'
  ),
  1,
  'member roster exposes the initial optimistic version'
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
    select public.list_organization_members(
      '00000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  null,
  'a teacher cannot list the organization roster'
);

select throws_ok(
  $$
    select public.update_organization_membership_status(
      '75000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000002',
      1,
      'disabled'
    )
  $$,
  'P0001',
  null,
  'a teacher cannot change a member status'
);

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

select throws_ok(
  $$
    select public.update_organization_membership_status(
      '75000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      1,
      null
    )
  $$,
  'P0001',
  null,
  'a null member status is rejected'
);

select throws_ok(
  $$
    select public.update_organization_membership_status(
      '75000000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      1,
      'disabled'
    )
  $$,
  'P0001',
  null,
  'the current manager cannot disable their own membership'
);

select lives_ok(
  $$
    select set_config(
      'xueqing.member_update',
      public.update_organization_membership_status(
        '75000000-0000-0000-0000-000000000004',
        '00000000-0000-0000-0000-000000000001',
        '61000000-0000-0000-0000-000000000002',
        1,
        'disabled'
      )::text,
      true
    )
  $$,
  'a manager can disable a member with a teaching handoff'
);

select is(
  current_setting('xueqing.member_update')::jsonb ->> 'status',
  'disabled',
  'member update returns disabled status'
);

select is(
  (current_setting('xueqing.member_update')::jsonb ->> 'version')::int,
  2,
  'member update increments the membership version'
);

select is(
  (current_setting('xueqing.member_update')::jsonb ->> 'ended_scope_count')::int,
  1,
  'disabling a member ends active subject scopes'
);

select is(
  (current_setting('xueqing.member_update')::jsonb ->> 'ended_assignment_count')::int,
  1,
  'disabling a member ends active student assignments'
);

reset role;

select is(
  (
    select membership.status || '|' || membership.version::text
    from public.organization_memberships as membership
    where membership.id =
      '61000000-0000-0000-0000-000000000002'
  ),
  'disabled|2',
  'membership stores disabled status and new version'
);

select is(
  (
    select count(*)::int
    from public.membership_subject_scopes as scope
    where scope.membership_id =
      '61000000-0000-0000-0000-000000000002'
      and scope.status = 'active'
  ),
  0,
  'disabled members have no active subject scopes'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments as assignment
    where assignment.membership_id =
      '61000000-0000-0000-0000-000000000002'
      and assignment.status = 'active'
  ),
  0,
  'disabled members have no active student assignments'
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
  (
    select count(*)::int
    from public.organizations
    where id = '00000000-0000-0000-0000-000000000002'
  ),
  0,
  'disabled members lose organization business reads immediately'
);

select throws_ok(
  $$
    select public.update_organization_membership_status(
      '75000000-0000-0000-0000-000000000005',
      '00000000-0000-0000-0000-000000000002',
      '61000000-0000-0000-0000-000000000002',
      2,
      'active'
    )
  $$,
  'P0001',
  null,
  'disabled teachers cannot restore themselves'
);

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
    select public.update_organization_membership_status(
      '75000000-0000-0000-0000-000000000004',
      '00000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000002',
      1,
      'active'
    )
  $$,
  'repeating the disable operation returns its committed result'
);

reset role;

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where operation_id =
      '75000000-0000-0000-0000-000000000004'
      and command_type = 'update_organization_membership_status'
      and target_type = 'membership'
      and result ->> 'status' = 'disabled'
      and committed_at is not null
  ),
  1,
  'member retry keeps one committed operation receipt'
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
  $$
    select set_config(
      'xueqing.member_restore',
      public.update_organization_membership_status(
        '75000000-0000-0000-0000-000000000006',
        '00000000-0000-0000-0000-000000000001',
        '61000000-0000-0000-0000-000000000002',
        2,
        'active'
      )::text,
      true
    )
  $$,
  'a manager can restore member access with the next version'
);

select is(
  current_setting('xueqing.member_restore')::jsonb ->> 'status',
  'active',
  'restoring member access returns active status'
);

select is(
  (current_setting('xueqing.member_restore')::jsonb ->> 'version')::int,
  3,
  'restoring member access increments the version again'
);

reset role;

select is(
  (
    select count(*)::int
    from public.membership_subject_scopes as scope
    where scope.membership_id =
      '61000000-0000-0000-0000-000000000002'
      and scope.status = 'active'
  ),
  0,
  'restoring access does not silently restore subject scopes'
);

select throws_ok(
  $$
    select public.update_organization_membership_status(
      '75000000-0000-0000-0000-000000000007',
      '00000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000002',
      2,
      'disabled'
    )
  $$,
  'P0001',
  null,
  'stale membership version is rejected'
);

select * from finish();

rollback;