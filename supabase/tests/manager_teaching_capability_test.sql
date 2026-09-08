begin;

select plan(7);

insert into public.app_users (
  id,
  auth_provider,
  auth_subject_id,
  display_name,
  status
)
values
  (
    '1f100000-0000-0000-0000-000000000001',
    'supabase',
    '1f200000-0000-0000-0000-000000000001',
    '测试管理员教师',
    'active'
  ),
  (
    '1f100000-0000-0000-0000-000000000002',
    'supabase',
    '1f200000-0000-0000-0000-000000000002',
    '测试负责人教师',
    'active'
  );

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values
  (
    '1f300000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '1f100000-0000-0000-0000-000000000001',
    'active'
  ),
  (
    '1f300000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    '1f100000-0000-0000-0000-000000000002',
    'active'
  );

insert into public.membership_roles (
  organization_id,
  membership_id,
  role
)
values (
  '00000000-0000-0000-0000-000000000001',
  '1f300000-0000-0000-0000-000000000001',
  'org_admin'
);

select ok(
  exists (
    select 1
    from public.membership_roles
    where membership_id = '1f300000-0000-0000-0000-000000000001'
      and role = 'org_admin'
  ),
  'admin role remains present'
);

select ok(
  exists (
    select 1
    from public.membership_roles
    where membership_id = '1f300000-0000-0000-0000-000000000001'
      and role = 'teacher'
  ),
  'admin automatically becomes teaching-capable'
);

select is(
  (
    select count(*)::integer
    from public.membership_roles
    where membership_id = '1f300000-0000-0000-0000-000000000001'
      and role = 'teacher'
  ),
  1,
  'admin gets exactly one teacher capability role'
);

insert into public.membership_roles (
  organization_id,
  membership_id,
  role
)
values (
  '00000000-0000-0000-0000-000000000001',
  '1f300000-0000-0000-0000-000000000002',
  'org_owner'
);

select ok(
  exists (
    select 1
    from public.membership_roles
    where membership_id = '1f300000-0000-0000-0000-000000000002'
      and role = 'org_owner'
  ),
  'owner role remains present'
);

select ok(
  exists (
    select 1
    from public.membership_roles
    where membership_id = '1f300000-0000-0000-0000-000000000002'
      and role = 'teacher'
  ),
  'owner automatically becomes teaching-capable'
);

select is(
  (
    select count(*)::integer
    from public.membership_roles
    where membership_id = '1f300000-0000-0000-0000-000000000002'
      and role = 'teacher'
  ),
  1,
  'owner gets exactly one teacher capability role'
);

insert into public.membership_roles (
  organization_id,
  membership_id,
  role
)
values (
  '00000000-0000-0000-0000-000000000001',
  '1f300000-0000-0000-0000-000000000001',
  'org_owner'
);

select is(
  (
    select count(*)::integer
    from public.membership_roles
    where membership_id = '1f300000-0000-0000-0000-000000000001'
      and role = 'teacher'
  ),
  1,
  'adding another manager role does not duplicate teaching capability'
);

select * from finish();
rollback;
