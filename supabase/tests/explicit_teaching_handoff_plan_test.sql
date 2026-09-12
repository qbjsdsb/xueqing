begin;

select plan(28);

select is(
  to_regprocedure(
    'public.preview_organization_student_teacher_handoff(uuid,uuid,uuid)'
  ) is not null,
  true,
  'explicit teaching handoff preview function exists'
);

select is(
  to_regprocedure(
    'public.commit_organization_student_teacher_handoff(uuid,uuid,uuid,integer,uuid,jsonb,jsonb)'
  ) is not null,
  true,
  'explicit teaching handoff commit function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.preview_organization_student_teacher_handoff(uuid,uuid,uuid)'
    )
  ),
  false,
  'handoff preview is a security-invoker wrapper'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.commit_organization_student_teacher_handoff(uuid,uuid,uuid,integer,uuid,jsonb,jsonb)'
    )
  ),
  false,
  'handoff commit is a security-invoker wrapper'
);

select is(
  has_function_privilege(
    'anon',
    'public.preview_organization_student_teacher_handoff(uuid,uuid,uuid)',
    'execute'
  ),
  false,
  'anon cannot preview a teaching handoff'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.preview_organization_student_teacher_handoff(uuid,uuid,uuid)',
    'execute'
  ),
  true,
  'authenticated may call the guarded preview'
);

select is(
  has_function_privilege(
    'anon',
    'public.commit_organization_student_teacher_handoff(uuid,uuid,uuid,integer,uuid,jsonb,jsonb)',
    'execute'
  ),
  false,
  'anon cannot commit a teaching handoff'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.commit_organization_student_teacher_handoff(uuid,uuid,uuid,integer,uuid,jsonb,jsonb)',
    'execute'
  ),
  true,
  'authenticated may call the guarded commit'
);

-- Fictional replacement teacher in the seeded organization.
insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '8d000000-0000-0000-0000-000000000001',
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
  '8d100000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '8d000000-0000-0000-0000-000000000001',
  'teacher'
);

insert into public.membership_subject_scopes (
  id,
  organization_id,
  membership_id,
  organization_subject_id,
  scope_kind,
  status,
  active_from
)
values (
  '8d200000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '8d000000-0000-0000-0000-000000000001',
  '64000000-0000-0000-0000-000000000001',
  'teaching',
  'active',
  '2026-01-01'
);

insert into public.learning_cases (
  id,
  organization_id,
  student_subject_profile_id,
  owner_membership_id,
  case_type,
  title,
  first_observed_at,
  created_by_app_user_id,
  created_by_membership_id
)
values (
  '8d300000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  'knowledge',
  '需要随任课一起交接的问题',
  '2026-09-12T01:00:00Z',
  '10000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);

insert into public.case_actions (
  id,
  organization_id,
  learning_case_id,
  assigned_membership_id,
  action_type,
  title,
  is_primary,
  status
)
values (
  '8d400000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '8d300000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  'verify',
  '下次继续复检',
  true,
  'pending'
);

insert into public.case_events (
  id,
  organization_id,
  learning_case_id,
  event_type,
  actor_app_user_id,
  actor_membership_id,
  metadata
)
values (
  '8d500000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '8d300000-0000-0000-0000-000000000001',
  'case_created',
  '10000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  '{}'::jsonb
);

set local role authenticated;

-- Seed manager session.
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
      'xueqing.explicit_handoff_plan',
      public.preview_organization_student_teacher_handoff(
        '00000000-0000-0000-0000-000000000001',
        '68000000-0000-0000-0000-000000000001',
        '8d000000-0000-0000-0000-000000000001'
      )::text,
      true
    )
  $$,
  'manager can preview the exact responsibility migration plan'
);

select is(
  (current_setting('xueqing.explicit_handoff_plan')::jsonb ->> 'affected_case_count')::int,
  1,
  'preview counts the open Case owned by the source teacher'
);

select is(
  (current_setting('xueqing.explicit_handoff_plan')::jsonb ->> 'affected_action_count')::int,
  1,
  'preview counts the pending Action assigned to the source teacher'
);

select is(
  current_setting('xueqing.explicit_handoff_plan')::jsonb
    #>> '{affected_cases,0,id}',
  '8d300000-0000-0000-0000-000000000001',
  'preview identifies the affected Case'
);

select is(
  current_setting('xueqing.explicit_handoff_plan')::jsonb
    #>> '{affected_actions,0,id}',
  '8d400000-0000-0000-0000-000000000001',
  'preview identifies the affected Action'
);

-- A plain teacher cannot use the organization handoff contract.
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
  $$
    select public.preview_organization_student_teacher_handoff(
      '00000000-0000-0000-0000-000000000001',
      '68000000-0000-0000-0000-000000000001',
      '8d000000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  'organization_manager_required',
  'teacher cannot preview an organization handoff'
);

-- Restore manager session and prove stale plans fail closed.
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

reset role;
update public.case_actions
set version = version + 1
where id = '8d400000-0000-0000-0000-000000000001';
set local role authenticated;

select throws_ok(
  $$
    select public.commit_organization_student_teacher_handoff(
      '8d600000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '68000000-0000-0000-0000-000000000001',
      1,
      '8d000000-0000-0000-0000-000000000001',
      current_setting('xueqing.explicit_handoff_plan')::jsonb -> 'affected_cases',
      current_setting('xueqing.explicit_handoff_plan')::jsonb -> 'affected_actions'
    )
  $$,
  'P0001',
  'teacher_handoff_plan_stale',
  'changed Action version makes the confirmed plan stale'
);

reset role;
select is(
  (select status from public.student_teacher_assignments
   where id = '68000000-0000-0000-0000-000000000001'),
  'active',
  'stale plan rolls back and keeps the source Assignment active'
);
select is(
  (select owner_membership_id::text from public.learning_cases
   where id = '8d300000-0000-0000-0000-000000000001'),
  '61000000-0000-0000-0000-000000000001',
  'stale plan does not move Case ownership'
);

set local role authenticated;
select set_config(
  'xueqing.explicit_handoff_plan',
  public.preview_organization_student_teacher_handoff(
    '00000000-0000-0000-0000-000000000001',
    '68000000-0000-0000-0000-000000000001',
    '8d000000-0000-0000-0000-000000000001'
  )::text,
  true
);

select lives_ok(
  $$
    select set_config(
      'xueqing.explicit_handoff_result',
      public.commit_organization_student_teacher_handoff(
        '8d600000-0000-0000-0000-000000000002',
        '00000000-0000-0000-0000-000000000001',
        '68000000-0000-0000-0000-000000000001',
        1,
        '8d000000-0000-0000-0000-000000000001',
        current_setting('xueqing.explicit_handoff_plan')::jsonb -> 'affected_cases',
        current_setting('xueqing.explicit_handoff_plan')::jsonb -> 'affected_actions'
      )::text,
      true
    )
  $$,
  'manager can atomically commit the freshly confirmed plan'
);

-- Exactly-once retry returns the stored successful result even though the old
-- source Assignment is no longer current.
select lives_ok(
  $$
    select public.commit_organization_student_teacher_handoff(
      '8d600000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000001',
      '68000000-0000-0000-0000-000000000001',
      1,
      '8d000000-0000-0000-0000-000000000001',
      current_setting('xueqing.explicit_handoff_plan')::jsonb -> 'affected_cases',
      current_setting('xueqing.explicit_handoff_plan')::jsonb -> 'affected_actions'
    )
  $$,
  'successful handoff is idempotent by operation id'
);

reset role;

select is(
  (select status from public.student_teacher_assignments
   where id = '68000000-0000-0000-0000-000000000001'),
  'ended',
  'commit ends the source Assignment'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments
    where student_subject_profile_id = '67000000-0000-0000-0000-000000000001'
      and membership_id = '8d000000-0000-0000-0000-000000000001'
      and assignment_role = 'lead'
      and status = 'active'
  ),
  1,
  'commit creates one active replacement Assignment with the same role'
);

select is(
  (select owner_membership_id::text from public.learning_cases
   where id = '8d300000-0000-0000-0000-000000000001'),
  '8d000000-0000-0000-0000-000000000001',
  'commit moves current Case ownership to the replacement teacher'
);

select is(
  (select assigned_membership_id::text from public.case_actions
   where id = '8d400000-0000-0000-0000-000000000001'),
  '8d000000-0000-0000-0000-000000000001',
  'commit moves the pending Action assignee to the replacement teacher'
);

select is(
  (
    select count(*)::int
    from public.case_events
    where learning_case_id = '8d300000-0000-0000-0000-000000000001'
      and event_type = 'responsibility_handoff'
      and actor_membership_id <> '8d000000-0000-0000-0000-000000000001'
  ),
  1,
  'handoff writes a manager Actor event without pretending the manager is the new owner'
);

select is(
  (select actor_membership_id::text from public.case_events
   where id = '8d500000-0000-0000-0000-000000000001'),
  '61000000-0000-0000-0000-000000000001',
  'historical event Actor remains unchanged after responsibility handoff'
);

select is(
  (current_setting('xueqing.explicit_handoff_result')::jsonb ->> 'transferred_case_count')::int,
  1,
  'commit result reports transferred Case count'
);

select is(
  (current_setting('xueqing.explicit_handoff_result')::jsonb ->> 'transferred_action_count')::int,
  1,
  'commit result reports transferred Action count'
);

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where operation_id = '8d600000-0000-0000-0000-000000000002'
      and command_type = 'transfer_organization_student_teacher_assignment'
  ),
  1,
  'successful explicit handoff uses the existing assignment-transfer operation identity exactly once'
);

select * from finish();
rollback;
