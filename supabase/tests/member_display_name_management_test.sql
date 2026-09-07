begin;

select plan(11);

select is(
  to_regprocedure(
    'public.update_organization_member_display_name(uuid,uuid,text)'
  ) is not null,
  true,
  'member display-name RPC exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.update_organization_member_display_name(uuid,uuid,text)'
    )
  ),
  false,
  'public member display-name RPC is security invoker'
);

select is(
  has_function_privilege(
    'anon',
    'public.update_organization_member_display_name(uuid,uuid,text)',
    'execute'
  ),
  false,
  'anon cannot update member display names'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.update_organization_member_display_name(uuid,uuid,text)',
    'execute'
  ),
  true,
  'authenticated can call the guarded member display-name RPC'
);

reset role;

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '7b000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000003',
  'active'
);

insert into public.membership_roles (
  id,
  organization_id,
  membership_id,
  role
)
values (
  '7b000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  '7b000000-0000-0000-0000-000000000001',
  'teacher'
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
    update public.app_users
    set display_name = '绕过失败'
    where id = '10000000-0000-0000-0000-000000000003'
  $$,
  'direct table update cannot bypass row-level security'
);

select is(
  (
    select listed.member ->> 'display_name'
    from public.list_organization_members(
      '00000000-0000-0000-0000-000000000001'
    ) as listed(member)
    where listed.member ->> 'membership_id' =
      '7b000000-0000-0000-0000-000000000001'
  ),
  '无机构测试用户',
  'direct table update leaves another member name unchanged'
);

select lives_ok(
  $$
    select public.update_organization_member_display_name(
      '00000000-0000-0000-0000-000000000001',
      '7b000000-0000-0000-0000-000000000001',
      '  赵老师  '
    )
  $$,
  'organization owner can update a member display name'
);

select is(
  (
    select listed.member ->> 'display_name'
    from public.list_organization_members(
      '00000000-0000-0000-0000-000000000001'
    ) as listed(member)
    where listed.member ->> 'membership_id' =
      '7b000000-0000-0000-0000-000000000001'
  ),
  '赵老师',
  'member display name is trimmed and visible through the manager read model'
);

select throws_ok(
  $$
    select public.update_organization_member_display_name(
      '00000000-0000-0000-0000-000000000001',
      '7b000000-0000-0000-0000-000000000001',
      '   '
    )
  $$,
  'P0001',
  'invalid_member_display_name',
  'blank display names are rejected'
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
    select public.update_organization_member_display_name(
      '00000000-0000-0000-0000-000000000002',
      '61000000-0000-0000-0000-000000000002',
      '越权改名'
    )
  $$,
  'P0001',
  'organization_manager_required',
  'ordinary teachers cannot update member display names'
);

select is(
  (
    select display_name
    from public.app_users
    where id = '10000000-0000-0000-0000-000000000002'
  ),
  '李老师',
  'rejected update leaves the target name unchanged'
);

select * from finish();
rollback;
