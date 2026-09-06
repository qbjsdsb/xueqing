begin;

select plan(17);

select is(
  (
    select count(*)::int
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'organization_memberships'
      and column_name in (
        'onboarding_started_at',
        'onboarding_completed_at',
        'onboarding_required'
      )
  ),
  3,
  'membership lifecycle has the onboarding timestamps and guard flag'
);

select is(
  (
    select count(*)::int
    from pg_trigger
    where tgname = 'organization_memberships_onboarding_guard'
      and tgrelid = 'public.organization_memberships'::regclass
      and not tgisinternal
  ),
  1,
  'membership status changes are protected by the onboarding trigger'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure('public.get_my_membership_state()')
  ),
  false,
  'account state lookup is security-invoker wrapper'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure('public.complete_member_onboarding()')
  ),
  false,
  'onboarding completion is security-invoker wrapper'
);

select is(
  has_function_privilege(
    'anon',
    'public.get_my_membership_state()',
    'execute'
  ),
  false,
  'anon cannot read account lifecycle state'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.get_my_membership_state()',
    'execute'
  ),
  true,
  'authenticated users can read their own account lifecycle state'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.complete_member_onboarding()',
    'execute'
  ),
  true,
  'authenticated users can request their own onboarding completion'
);

select is(
  has_function_privilege(
    'anon',
    'public.provision_organization_member_from_auth(uuid,uuid,text,uuid,uuid,text)',
    'execute'
  ),
  false,
  'anon cannot call the service-only provisioning transaction'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.provision_organization_member_from_auth(uuid,uuid,text,uuid,uuid,text)',
    'execute'
  ),
  false,
  'authenticated clients cannot call the service-only provisioning transaction'
);

select is(
  has_function_privilege(
    'anon',
    'public.prepare_member_credential_reissue(uuid,uuid,uuid,uuid)',
    'execute'
  ),
  false,
  'anon cannot prepare a credential reissue'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.prepare_member_credential_reissue(uuid,uuid,uuid,uuid)',
    'execute'
  ),
  false,
  'authenticated clients cannot prepare a credential reissue'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.reissue_organization_invitation(uuid)',
    'execute'
  ),
  true,
  'managers can use the guarded invitation reissue command'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.organization_memberships',
    'update'
  ),
  false,
  'authenticated clients cannot update onboarding state directly'
);

reset role;

insert into public.app_users (
  id,
  auth_provider,
  auth_subject_id,
  display_name,
  status
)
values (
  '10000000-0000-0000-0000-000000000004',
  'supabase',
  '20000000-0000-0000-0000-000000000004',
  '待接管测试用户',
  'active'
);

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status,
  onboarding_started_at,
  onboarding_expires_at,
  onboarding_required
)
values (
  '61000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000004',
  'onboarding',
  now() - interval '1 minute',
  now() + interval '7 days',
  true
);

insert into public.membership_roles (
  id,
  organization_id,
  membership_id,
  role
)
values (
  '62000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000004',
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
    'email', 'teacher.a@xueqing.test',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000001'
  )::text,
  true
);

select throws_ok(
  $$
    select public.update_organization_membership_status(
      '75000000-0000-0000-0000-000000000010',
      '00000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000004',
      1,
      'active'
    )
  $$,
  'P0001',
  null,
  'the existing member status command cannot activate onboarding directly'
);

reset role;

select is(
  (
    select status
    from public.organization_memberships
    where id = '61000000-0000-0000-0000-000000000004'
  ),
  'onboarding',
  'a rejected onboarding bypass leaves the member pending'
);

select is(
  (
    select onboarding_required
    from public.organization_memberships
    where id = '61000000-0000-0000-0000-000000000004'
  ),
  true,
  'a rejected onboarding bypass leaves the lifecycle guard enabled'
);

select is(
  (
    select count(*)::int
    from public.organization_invitations
    where status = 'accepted'
      and accepted_by_app_user_id = '10000000-0000-0000-0000-000000000004'
  ),
  0,
  'the onboarding guard test does not fabricate an accepted invitation'
);

select * from finish();

rollback;
