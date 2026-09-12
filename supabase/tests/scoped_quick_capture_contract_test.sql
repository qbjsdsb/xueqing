begin;

select plan(15);

-- Fictional dual-role actor: organization owner + real teaching collaborator.
insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
values (
  '2f220000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'scoped.capture.owner@xueqing.test',
  crypt('XueqingDev-Only-123!', gen_salt('bf')),
  now(), now(), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  '', '', '', ''
);

insert into auth.sessions (id, user_id, created_at, updated_at)
values (
  '2f520000-0000-0000-0000-000000000001',
  '2f220000-0000-0000-0000-000000000001',
  now(), now()
);

insert into public.app_users (
  id,
  auth_provider,
  auth_subject_id,
  display_name,
  status
)
values (
  '2f120000-0000-0000-0000-000000000001',
  'supabase',
  '2f220000-0000-0000-0000-000000000001',
  '双身份测试负责人',
  'active'
);

insert into public.identity_links (
  id,
  app_user_id,
  provider_key,
  issuer,
  external_subject,
  status
)
values (
  '2f620000-0000-0000-0000-000000000001',
  '2f120000-0000-0000-0000-000000000001',
  'supabase',
  'http://127.0.0.1:54321/auth/v1',
  '2f220000-0000-0000-0000-000000000001',
  'active'
);

insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
)
values (
  '2f320000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '2f120000-0000-0000-0000-000000000001',
  'active'
);

insert into public.membership_roles (
  organization_id,
  membership_id,
  role
)
values
  (
    '00000000-0000-0000-0000-000000000001',
    '2f320000-0000-0000-0000-000000000001',
    'org_owner'
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    '2f320000-0000-0000-0000-000000000001',
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
  '2f650000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '2f320000-0000-0000-0000-000000000001',
  '64000000-0000-0000-0000-000000000001',
  'teaching',
  'active',
  date '2026-01-01'
);

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
  '2f680000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000001',
  '2f320000-0000-0000-0000-000000000001',
  'collaborator',
  'active',
  date '2026-01-01'
);

select is(
  private.membership_has_current_teaching_responsibility_v2(
    '67000000-0000-0000-0000-000000000001',
    '2f320000-0000-0000-0000-000000000001'
  ),
  true,
  'dual-role owner has real Personal teaching responsibility as collaborator'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '2f220000-0000-0000-0000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '2f220000-0000-0000-0000-000000000001',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '2f520000-0000-0000-0000-000000000001'
  )::text,
  true
);

select lives_ok(
  $$select public.quick_capture_case_in_scope(
      '2f720000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      (select version from public.student_subject_profiles where id = '67000000-0000-0000-0000-000000000001'),
      'knowledge',
      'Personal 视角：协作老师本人记录',
      null,
      timestamptz '2026-09-12 16:00:00+08',
      '这是本人任课视角的真实课堂观察。',
      '本人下次课复查',
      timestamptz '2026-09-13 18:00:00+08',
      null,
      'personal',
      '2f320000-0000-0000-0000-000000000001'
    )$$,
  'Personal scoped capture succeeds for a real collaborator assignment'
);

select is(
  (
    select owner_membership_id::text
    from public.learning_cases
    where title = 'Personal 视角：协作老师本人记录'
  ),
  '2f320000-0000-0000-0000-000000000001',
  'Personal scope keeps responsibility with the acting assigned teacher'
);

select is(
  (
    select actor_membership_id::text
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases
      where title = 'Personal 视角：协作老师本人记录'
    )
      and event_type = 'case_created'
  ),
  '2f320000-0000-0000-0000-000000000001',
  'Personal capture audit records the actual actor'
);

select lives_ok(
  $$select public.quick_capture_case_in_scope(
      '2f720000-0000-0000-0000-000000000002',
      '67000000-0000-0000-0000-000000000001',
      (select version from public.student_subject_profiles where id = '67000000-0000-0000-0000-000000000001'),
      'knowledge',
      'Organization 视角：负责人补充观察',
      null,
      timestamptz '2026-09-12 16:10:00+08',
      '同一个人以机构监督视角补充事实。',
      'Lead 下次课复查',
      timestamptz '2026-09-13 19:00:00+08',
      null,
      'organization',
      '61000000-0000-0000-0000-000000000001'
    )$$,
  'Organization scoped capture succeeds for a dual-role manager'
);

select is(
  (
    select owner_membership_id::text
    from public.learning_cases
    where title = 'Organization 视角：负责人补充观察'
  ),
  '61000000-0000-0000-0000-000000000001',
  'Organization scope assigns responsibility to the active Lead, not the dual-role actor'
);

select is(
  (
    select assigned_membership_id::text
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases
      where title = 'Organization 视角：负责人补充观察'
    )
      and status = 'pending'
      and is_primary
  ),
  '61000000-0000-0000-0000-000000000001',
  'Organization scoped next Action is assigned to the active Lead'
);

select is(
  (
    select actor_membership_id::text
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases
      where title = 'Organization 视角：负责人补充观察'
    )
      and event_type = 'case_created'
  ),
  '2f320000-0000-0000-0000-000000000001',
  'Organization capture still audits the manager as the real actor'
);

select throws_ok(
  $$select public.quick_capture_case_in_scope(
      '2f720000-0000-0000-0000-000000000003',
      '67000000-0000-0000-0000-000000000001',
      (select version from public.student_subject_profiles where id = '67000000-0000-0000-0000-000000000001'),
      'knowledge',
      'Organization 视角：过期责任预期',
      null,
      timestamptz '2026-09-12 16:20:00+08',
      '客户端仍错误认为管理者本人负责。',
      null,
      null,
      null,
      'organization',
      '2f320000-0000-0000-0000-000000000001'
    )$$,
  'P0001',
  null,
  'stale Organization responsibility expectation is rejected'
);

select is(
  (
    select count(*)::integer
    from public.learning_cases
    where title = 'Organization 视角：过期责任预期'
  ),
  0,
  'responsibility conflict leaves no Case behind'
);

select throws_ok(
  $$select public.quick_capture_case_in_scope(
      '2f720000-0000-0000-0000-000000000004',
      '67000000-0000-0000-0000-000000000001',
      (select version from public.student_subject_profiles where id = '67000000-0000-0000-0000-000000000001'),
      'knowledge',
      '显式 scope 缺少责任预期',
      null,
      timestamptz '2026-09-12 16:30:00+08',
      '显式写入必须带责任快照。',
      null,
      null,
      null,
      'organization',
      null
    )$$,
  'P0001',
  null,
  'explicit scoped capture requires an observed responsibility membership'
);

reset role;

-- Simulate a completed Lead handoff before submission: the old Lead is still a
-- valid teacher, but there is no current Lead. Organization scope must not fall
-- back to either the manager or an arbitrary collaborator.
update public.student_teacher_assignments
set assignment_role = 'collaborator'
where id = '68000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '2f220000-0000-0000-0000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '2f220000-0000-0000-0000-000000000001',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '2f520000-0000-0000-0000-000000000001'
  )::text,
  true
);

select throws_ok(
  $$select public.quick_capture_case_in_scope(
      '2f720000-0000-0000-0000-000000000005',
      '67000000-0000-0000-0000-000000000001',
      (select version from public.student_subject_profiles where id = '67000000-0000-0000-0000-000000000001'),
      'knowledge',
      'Organization 视角：无 Lead 不应创建',
      null,
      timestamptz '2026-09-12 16:40:00+08',
      '应先修复教学责任。',
      null,
      null,
      null,
      'organization',
      '61000000-0000-0000-0000-000000000001'
    )$$,
  'P0001',
  null,
  'Organization capture is rejected when no active Lead exists'
);

select is(
  (
    select count(*)::integer
    from public.learning_cases
    where title = 'Organization 视角：无 Lead 不应创建'
  ),
  0,
  'no Case is created during a Lead responsibility gap'
);

reset role;

select is(
  public.xueqing_backend_compatibility()->>'schema_version',
  '20260912030000',
  'backend compatibility advertises the scoped Quick Capture schema version'
);

select is(
  public.xueqing_backend_compatibility()
    ->'capabilities'->>'responsibility_safe_quick_capture',
  'true',
  'backend compatibility advertises responsibility-safe Quick Capture capability'
);

select is(
  has_function_privilege(
    'anon',
    'public.quick_capture_case_in_scope(uuid,uuid,integer,text,text,text,timestamptz,text,text,timestamptz,uuid,text,uuid)',
    'execute'
  ),
  false,
  'anonymous callers cannot invoke scoped Quick Capture'
);

select * from finish();
rollback;
