begin;

select plan(40);

select is(
  (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'membership_subject_scopes'
      and column_name = 'version'
  ),
  1,
  'subject scopes have an optimistic version'
);

select is(
  to_regprocedure('public.list_organization_teacher_subject_scopes(uuid)')
    is not null,
  true,
  'teacher scope roster function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.list_organization_teacher_subject_scopes(uuid)'
    )
  ),
  true,
  'teacher scope roster is security definer'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_organization_teacher_subject_scopes(uuid)',
    'execute'
  ),
  false,
  'anon cannot list teacher scopes'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.list_organization_teacher_subject_scopes(uuid)',
    'execute'
  ),
  true,
  'authenticated can list teacher scopes through the guarded command'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.membership_subject_scopes',
    'update'
  ),
  false,
  'authenticated cannot update scopes directly'
);

select is(
  to_regprocedure(
    'public.update_organization_teacher_subject_scope(uuid,uuid,uuid,uuid,uuid,integer,text)'
  ) is not null,
  true,
  'teacher scope command exists'
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
  $scope_list$
    select set_config(
      'xueqing.member_list',
      (
        select coalesce(jsonb_agg(item), '[]'::jsonb)::text
        from public.list_organization_teacher_subject_scopes(
          '00000000-0000-0000-0000-000000000001'
        ) as item
      ),
      true
    )
  $scope_list$,
  'an organization manager can load teacher scopes'
);

select is(
  jsonb_array_length(current_setting('xueqing.member_list')::jsonb),
  1,
  'teacher scope roster contains the organization scope'
);

select is(
  (
    select (item ->> 'version')::int
    from jsonb_array_elements(current_setting('xueqing.member_list')::jsonb) as item
    limit 1
  ),
  1,
  'teacher scope roster exposes the initial version'
);

select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-000000000003',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '20000000-0000-0000-0000-000000000003',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000003'
  )::text,
  true
);

select throws_ok(
  $scope_teacher$
    select public.list_organization_teacher_subject_scopes(
      '00000000-0000-0000-0000-000000000001'
    )
  $scope_teacher$,
  'P0001',
  null,
  'a teacher cannot list organization teacher scopes'
);

reset role;

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '71000000-0000-0000-0000-000000000001',
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
  '72000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000001',
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
  $scope_add$
    select set_config(
      'xueqing.member_update',
      public.update_organization_teacher_subject_scope(
        '80000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000001',
        '71000000-0000-0000-0000-000000000001',
        '64000000-0000-0000-0000-000000000001',
        null,
        null,
        'active'
      )::text,
      true
    )
  $scope_add$,
  'a manager can add a teacher teaching scope'
);

select is(
  current_setting('xueqing.member_update')::jsonb ->> 'status',
  'active',
  'scope activation returns active status'
);

select is(
  (current_setting('xueqing.member_update')::jsonb ->> 'version')::int,
  1,
  'new scope starts at version one'
);

select is(
  (
    select count(*)::int
    from public.membership_subject_scopes as scope
    where scope.membership_id =
      '71000000-0000-0000-0000-000000000001'
      and scope.status = 'active'
  ),
  1,
  'new teacher has one active scope'
);

select lives_ok(
  $scope_retry$
    select public.update_organization_teacher_subject_scope(
      '80000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '71000000-0000-0000-0000-000000000001',
      '64000000-0000-0000-0000-000000000001',
      null,
      null,
      'active'
    )
  $scope_retry$,
  'repeating scope activation returns the committed result'
);

reset role;

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where organization_id =
      '00000000-0000-0000-0000-000000000001'
      and operation_id =
        '80000000-0000-0000-0000-000000000001'
      and command_type = 'update_organization_teacher_subject_scope'
      and target_type = 'membership_subject_scope'
      and committed_at is not null
  ),
  1,
  'scope activation retry keeps one receipt'
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

select throws_ok(
  $scope_duplicate$
    select public.update_organization_teacher_subject_scope(
      '80000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000001',
      '71000000-0000-0000-0000-000000000001',
      '64000000-0000-0000-0000-000000000001',
      null,
      null,
      'active'
    )
  $scope_duplicate$,
  'P0001',
  null,
  'duplicate active scope is rejected'
);

select throws_ok(
  $scope_cross_org$
    select public.update_organization_teacher_subject_scope(
      '80000000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000002',
      '64000000-0000-0000-0000-000000000001',
      null,
      null,
      'active'
    )
  $scope_cross_org$,
  'P0001',
  null,
  'cross organization membership cannot receive a scope'
);

reset role;

insert into public.student_teacher_assignments (
  id,
  organization_id,
  student_subject_profile_id,
  membership_id,
  assignment_role,
  status,
  active_from
)
values (
  '77000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000001',
  'collaborator',
  'active',
  '2026-01-01'
);

select throws_ok(
  $scope_assignment_guard$
    select public.update_organization_teacher_subject_scope(
      '80000000-0000-0000-0000-000000000004',
      '00000000-0000-0000-0000-000000000001',
      '71000000-0000-0000-0000-000000000001',
      '64000000-0000-0000-0000-000000000001',
      (
        select scope.id
        from public.membership_subject_scopes as scope
        where scope.membership_id =
          '71000000-0000-0000-0000-000000000001'
          and scope.organization_subject_id =
            '64000000-0000-0000-0000-000000000001'
          and scope.status = 'active'
      ),
      1,
      'ended'
    )
  $scope_assignment_guard$,
  'P0001',
  null,
  'scope cannot end while an active student assignment remains'
);

reset role;

select is(
  (
    select count(*)::int
    from public.membership_subject_scopes as scope
    where scope.membership_id =
      '71000000-0000-0000-0000-000000000001'
      and scope.status = 'active'
  ),
  1,
  'assignment handoff refusal leaves scope active'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments as assignment
    where assignment.membership_id =
      '71000000-0000-0000-0000-000000000001'
      and assignment.status = 'active'
  ),
  1,
  'assignment handoff refusal leaves assignment active'
);

delete from public.student_teacher_assignments
where id = '77000000-0000-0000-0000-000000000001';

insert into public.learning_cases (
  id,
  organization_id,
  student_subject_profile_id,
  owner_membership_id,
  case_type,
  title,
  status,
  first_observed_at,
  version,
  created_by_app_user_id,
  created_by_membership_id
)
values (
  '78000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000001',
  'knowledge',
  '待交接的虚构案件',
  'confirmed',
  '2026-09-04T08:00:00Z',
  1,
  '10000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);

set local role authenticated;

select throws_ok(
  $scope_case_guard$
    select public.update_organization_teacher_subject_scope(
      '80000000-0000-0000-0000-000000000005',
      '00000000-0000-0000-0000-000000000001',
      '71000000-0000-0000-0000-000000000001',
      '64000000-0000-0000-0000-000000000001',
      (
        select scope.id
        from public.membership_subject_scopes as scope
        where scope.membership_id =
          '71000000-0000-0000-0000-000000000001'
          and scope.organization_subject_id =
            '64000000-0000-0000-0000-000000000001'
          and scope.status = 'active'
      ),
      1,
      'ended'
    )
  $scope_case_guard$,
  'P0001',
  null,
  'scope cannot end while an open Case remains owned by the teacher'
);

reset role;

select is(
  (
    select count(*)::int
    from public.membership_subject_scopes as scope
    where scope.membership_id =
      '71000000-0000-0000-0000-000000000001'
      and scope.status = 'active'
  ),
  1,
  'Case handoff refusal leaves scope active'
);

delete from public.learning_cases
where id = '78000000-0000-0000-0000-000000000001';

set local role authenticated;

select lives_ok(
  $scope_end$
    select set_config(
      'xueqing.member_update',
      public.update_organization_teacher_subject_scope(
        '80000000-0000-0000-0000-000000000006',
        '00000000-0000-0000-0000-000000000001',
        '71000000-0000-0000-0000-000000000001',
        '64000000-0000-0000-0000-000000000001',
        (
          select scope.id
          from public.membership_subject_scopes as scope
          where scope.membership_id =
            '71000000-0000-0000-0000-000000000001'
            and scope.organization_subject_id =
              '64000000-0000-0000-0000-000000000001'
            and scope.status = 'active'
        ),
        1,
        'ended'
      )::text,
      true
    )
  $scope_end$,
  'a manager can end a teacher subject scope after handoff'
);

select is(
  current_setting('xueqing.member_update')::jsonb ->> 'status',
  'ended',
  'scope ending returns ended status'
);

select is(
  (current_setting('xueqing.member_update')::jsonb ->> 'version')::int,
  2,
  'ending a scope increments its version'
);

reset role;

select is(
  (
    select count(*)::int
    from public.membership_subject_scopes as scope
    where scope.membership_id =
      '71000000-0000-0000-0000-000000000001'
      and scope.status = 'active'
  ),
  0,
  'ended scope is no longer active'
);

set local role authenticated;

select lives_ok(
  $scope_end_retry$
    select public.update_organization_teacher_subject_scope(
      '80000000-0000-0000-0000-000000000006',
      '00000000-0000-0000-0000-000000000001',
      '71000000-0000-0000-0000-000000000001',
      '64000000-0000-0000-0000-000000000001',
      (
        select scope.id
        from public.membership_subject_scopes as scope
        where scope.membership_id =
          '71000000-0000-0000-0000-000000000001'
          and scope.organization_subject_id =
            '64000000-0000-0000-0000-000000000001'
          and scope.status = 'ended'
        order by scope.id
        limit 1
      ),
      1,
      'ended'
    )
  $scope_end_retry$,
  'repeating scope ending returns the committed result'
);

reset role;

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where operation_id =
      '80000000-0000-0000-0000-000000000006'
      and command_type = 'update_organization_teacher_subject_scope'
      and result ->> 'status' = 'ended'
      and committed_at is not null
  ),
  1,
  'scope ending retry keeps one receipt'
);

set local role authenticated;

select lives_ok(
  $scope_readd$
    select set_config(
      'xueqing.member_restore',
      public.update_organization_teacher_subject_scope(
        '80000000-0000-0000-0000-000000000007',
        '00000000-0000-0000-0000-000000000001',
        '71000000-0000-0000-0000-000000000001',
        '64000000-0000-0000-0000-000000000001',
        null,
        null,
        'active'
      )::text,
      true
    )
  $scope_readd$,
  'a manager can reactivate a scope as a new interval'
);

select is(
  current_setting('xueqing.member_restore')::jsonb ->> 'status',
  'active',
  'scope reactivation returns active status'
);

select is(
  (current_setting('xueqing.member_restore')::jsonb ->> 'version')::int,
  1,
  'reactivated scope starts a new versioned interval'
);

reset role;

select is(
  (
    select count(*)::int
    from public.membership_subject_scopes as scope
    where scope.membership_id =
      '71000000-0000-0000-0000-000000000001'
      and scope.organization_subject_id =
        '64000000-0000-0000-0000-000000000001'
  ),
  2,
  'scope history keeps the ended interval and new active interval'
);

update public.membership_subject_scopes
set active_from = active_from
where id = (
  current_setting('xueqing.member_restore')::jsonb ->> 'scope_id'
)::uuid;

set local role authenticated;

select throws_ok(
  $scope_stale$
    select public.update_organization_teacher_subject_scope(
      '80000000-0000-0000-0000-000000000008',
      '00000000-0000-0000-0000-000000000001',
      '71000000-0000-0000-0000-000000000001',
      '64000000-0000-0000-0000-000000000001',
      (
        current_setting('xueqing.member_restore')::jsonb ->> 'scope_id'
      )::uuid,
      1,
      'ended'
    )
  $scope_stale$,
  'P0001',
  null,
  'stale scope version is rejected'
);

reset role;

select is(
  (
    select scope.status || '|' || scope.version::text
    from public.membership_subject_scopes as scope
    where scope.id = (
      current_setting('xueqing.member_restore')::jsonb ->> 'scope_id'
    )::uuid
  ),
  'active|2',
  'stale scope request leaves the current scope unchanged'
);

set local role authenticated;

select lives_ok(
  $scope_final_end$
    select set_config(
      'xueqing.member_update',
      public.update_organization_teacher_subject_scope(
        '80000000-0000-0000-0000-000000000009',
        '00000000-0000-0000-0000-000000000001',
        '71000000-0000-0000-0000-000000000001',
        '64000000-0000-0000-0000-000000000001',
        (
          current_setting('xueqing.member_restore')::jsonb ->> 'scope_id'
        )::uuid,
        2,
        'ended'
      )::text,
      true
    )
  $scope_final_end$,
  'a manager can end the reactivated scope with the current version'
);

select is(
  current_setting('xueqing.member_update')::jsonb ->> 'status',
  'ended',
  'final scope ending returns ended status'
);

select is(
  (current_setting('xueqing.member_update')::jsonb ->> 'version')::int,
  3,
  'final scope ending increments the version exactly once'
);

reset role;

select is(
  (
    select count(*)::int
    from public.membership_subject_scopes as scope
    where scope.membership_id =
      '71000000-0000-0000-0000-000000000001'
      and scope.status = 'active'
  ),
  0,
  'all test teacher scopes are ended after final handoff'
);

select * from finish();

rollback;
