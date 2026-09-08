begin;

select plan(25);

-- Fictional manager actors in the seeded organization. Neither manager receives
-- a student assignment or teaching subject scope: organization-level learning
-- supervision must come from org_owner / org_admin, not synthetic assignments.
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
values
  (
    '2f200000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'supervisor.owner@xueqing.test',
    crypt('XueqingDev-Only-123!', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    '', '', '', ''
  ),
  (
    '2f200000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'supervisor.admin@xueqing.test',
    crypt('XueqingDev-Only-123!', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    '', '', '', ''
  ),
  (
    '2f200000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'unassigned.teacher@xueqing.test',
    crypt('XueqingDev-Only-123!', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    '', '', '', ''
  );

insert into auth.sessions (id, user_id, created_at, updated_at)
values
  (
    '2f500000-0000-0000-0000-000000000001',
    '2f200000-0000-0000-0000-000000000001',
    now(), now()
  ),
  (
    '2f500000-0000-0000-0000-000000000002',
    '2f200000-0000-0000-0000-000000000002',
    now(), now()
  ),
  (
    '2f500000-0000-0000-0000-000000000003',
    '2f200000-0000-0000-0000-000000000003',
    now(), now()
  );

insert into public.app_users (
  id,
  auth_provider,
  auth_subject_id,
  display_name,
  status
)
values
  (
    '2f100000-0000-0000-0000-000000000001',
    'supabase',
    '2f200000-0000-0000-0000-000000000001',
    '监督测试负责人',
    'active'
  ),
  (
    '2f100000-0000-0000-0000-000000000002',
    'supabase',
    '2f200000-0000-0000-0000-000000000002',
    '监督测试管理员',
    'active'
  ),
  (
    '2f100000-0000-0000-0000-000000000003',
    'supabase',
    '2f200000-0000-0000-0000-000000000003',
    '未任课测试老师',
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
values
  (
    '2f600000-0000-0000-0000-000000000001',
    '2f100000-0000-0000-0000-000000000001',
    'supabase',
    'http://127.0.0.1:54321/auth/v1',
    '2f200000-0000-0000-0000-000000000001',
    'active'
  ),
  (
    '2f600000-0000-0000-0000-000000000002',
    '2f100000-0000-0000-0000-000000000002',
    'supabase',
    'http://127.0.0.1:54321/auth/v1',
    '2f200000-0000-0000-0000-000000000002',
    'active'
  ),
  (
    '2f600000-0000-0000-0000-000000000003',
    '2f100000-0000-0000-0000-000000000003',
    'supabase',
    'http://127.0.0.1:54321/auth/v1',
    '2f200000-0000-0000-0000-000000000003',
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
    '2f300000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '2f100000-0000-0000-0000-000000000001',
    'active'
  ),
  (
    '2f300000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    '2f100000-0000-0000-0000-000000000002',
    'active'
  ),
  (
    '2f300000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000001',
    '2f100000-0000-0000-0000-000000000003',
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
    '2f300000-0000-0000-0000-000000000001',
    'org_owner'
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    '2f300000-0000-0000-0000-000000000002',
    'org_admin'
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    '2f300000-0000-0000-0000-000000000003',
    'teacher'
  );

select is(
  (
    select count(*)::integer
    from public.student_teacher_assignments
    where membership_id in (
      '2f300000-0000-0000-0000-000000000001',
      '2f300000-0000-0000-0000-000000000002'
    )
  ),
  0,
  'managers do not need synthetic student assignments'
);

select is(
  (
    select count(*)::integer
    from public.membership_subject_scopes
    where membership_id in (
      '2f300000-0000-0000-0000-000000000001',
      '2f300000-0000-0000-0000-000000000002'
    )
  ),
  0,
  'managers do not need synthetic teaching scopes'
);

-- Teacher A creates the learning fact and remains responsible for it.
set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000001', true);
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
  $$select public.quick_capture_case(
      '2f700000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1,
      'knowledge',
      '监督权限回归：分数应用',
      '老师先记录，机构管理者后续监督处理。',
      timestamptz '2026-09-08 08:00:00+08',
      '课堂应用题中两次遗漏单位转换。',
      '补两道同类题并复核单位',
      timestamptz '2026-09-09 09:00:00+08'
    )$$,
  'assigned teacher can create the supervised Case'
);

-- Owner can see and confirm every learning record in the organization without
-- becoming the teacher responsible for that Case.
select set_config('request.jwt.claim.sub', '2f200000-0000-0000-0000-000000000001', true);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '2f200000-0000-0000-0000-000000000001',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '2f500000-0000-0000-0000-000000000001'
  )::text,
  true
);

select is(
  (
    select count(*)::integer
    from public.learning_cases
    where title = '监督权限回归：分数应用'
  ),
  1,
  'owner can read a teacher Case without an assignment'
);

select lives_ok(
  $$select public.confirm_case(
      '2f700000-0000-0000-0000-000000000002',
      (select id from public.learning_cases where title = '监督权限回归：分数应用'),
      (select version from public.learning_cases where title = '监督权限回归：分数应用'),
      '安排一次针对性练习',
      timestamptz '2026-09-09 10:00:00+08'
    )$$,
  'owner can confirm a teacher Case without a lead assignment'
);

select is(
  (
    select owner_membership_id::text
    from public.learning_cases
    where title = '监督权限回归：分数应用'
  ),
  '61000000-0000-0000-0000-000000000001',
  'owner supervision preserves the original teacher Case owner'
);

select is(
  (
    select assigned_membership_id::text
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '监督权限回归：分数应用'
    )
      and status = 'pending'
      and is_primary
  ),
  '61000000-0000-0000-0000-000000000001',
  'owner supervision keeps the next Action assigned to the teacher'
);

select is(
  (
    select actor_membership_id::text
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases where title = '监督权限回归：分数应用'
    )
      and event_type = 'case_confirmed'
    order by occurred_at desc, id desc
    limit 1
  ),
  '2f300000-0000-0000-0000-000000000001',
  'audit history records the owner as the real confirming actor'
);

-- Admin gets the same organization-wide learning supervision, while ownership
-- and next-action responsibility stay with the teacher.
select set_config('request.jwt.claim.sub', '2f200000-0000-0000-0000-000000000002', true);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '2f200000-0000-0000-0000-000000000002',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '2f500000-0000-0000-0000-000000000002'
  )::text,
  true
);

select is(
  (
    select count(*)::integer
    from public.learning_cases
    where title = '监督权限回归：分数应用'
  ),
  1,
  'admin can read a teacher Case without an assignment'
);

select lives_ok(
  $$select public.record_intervention(
      '2f700000-0000-0000-0000-000000000003',
      (select id from public.learning_cases where title = '监督权限回归：分数应用'),
      (select version from public.learning_cases where title = '监督权限回归：分数应用'),
      '复核单位转换并要求学生口述步骤',
      '管理员监督纠偏，不接管任课责任。',
      timestamptz '2026-09-08 09:00:00+08',
      '再做两道迁移题并核对单位',
      timestamptz '2026-09-09 11:00:00+08'
    )$$,
  'admin can record an Intervention on a teacher Case'
);

select is(
  (
    select owner_membership_id::text
    from public.learning_cases
    where title = '监督权限回归：分数应用'
  ),
  '61000000-0000-0000-0000-000000000001',
  'admin intervention preserves teacher Case ownership'
);

select is(
  (
    select assigned_membership_id::text
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '监督权限回归：分数应用'
    )
      and status = 'pending'
      and is_primary
  ),
  '61000000-0000-0000-0000-000000000001',
  'admin intervention preserves teacher Action responsibility'
);

select is(
  (
    select actor_membership_id::text
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases where title = '监督权限回归：分数应用'
    )
      and event_type = 'intervention_recorded'
    order by occurred_at desc, id desc
    limit 1
  ),
  '2f300000-0000-0000-0000-000000000002',
  'audit history records the admin as the real intervention actor'
);

select lives_ok(
  $$select public.record_assessment(
      '2f700000-0000-0000-0000-000000000004',
      (select id from public.learning_cases where title = '监督权限回归：分数应用'),
      (select version from public.learning_cases where title = '监督权限回归：分数应用'),
      'passed',
      '两道迁移题均正确完成单位转换。',
      '继续观察稳定性。',
      timestamptz '2026-09-08 09:30:00+08',
      '次日再复查一次',
      timestamptz '2026-09-09 12:00:00+08'
    )$$,
  'admin can record an Assessment on a teacher Case'
);

select lives_ok(
  $$select public.stabilize_case(
      '2f700000-0000-0000-0000-000000000005',
      (select id from public.learning_cases where title = '监督权限回归：分数应用'),
      (select version from public.learning_cases where title = '监督权限回归：分数应用'),
      timestamptz '2026-09-08 09:40:00+08',
      '一周后抽查单位转换',
      timestamptz '2026-09-15 09:00:00+08'
    )$$,
  'admin can stabilize a teacher Case'
);

select lives_ok(
  $$select public.close_case(
      '2f700000-0000-0000-0000-000000000006',
      (select id from public.learning_cases where title = '监督权限回归：分数应用'),
      (select version from public.learning_cases where title = '监督权限回归：分数应用'),
      timestamptz '2026-09-08 10:00:00+08'
    )$$,
  'admin can close a teacher Case without a lead assignment'
);

select is(
  (
    select status
    from public.learning_cases
    where title = '监督权限回归：分数应用'
  ),
  'closed',
  'manager close transitions the Case to closed'
);

select lives_ok(
  $$select public.add_case_evidence(
      '2f700000-0000-0000-0000-000000000007',
      (select id from public.learning_cases where title = '监督权限回归：分数应用'),
      (select version from public.learning_cases where title = '监督权限回归：分数应用'),
      'observation',
      '关闭后复发观察',
      timestamptz '2026-09-08 11:00:00+08',
      '新的应用题中再次遗漏单位转换。'
    )$$,
  'admin can append post-close recurrence Evidence'
);

select lives_ok(
  $$select public.reopen_case(
      '2f700000-0000-0000-0000-000000000008',
      (select id from public.learning_cases where title = '监督权限回归：分数应用'),
      (select version from public.learning_cases where title = '监督权限回归：分数应用'),
      array[(
        select id from public.case_evidence
        where learning_case_id = (
          select id from public.learning_cases where title = '监督权限回归：分数应用'
        )
          and title = '关闭后复发观察'
      )]::uuid[],
      jsonb_build_object(
        (
          select id::text from public.case_evidence
          where learning_case_id = (
            select id from public.learning_cases where title = '监督权限回归：分数应用'
          )
            and title = '关闭后复发观察'
        ),
        (
          select version from public.case_evidence
          where learning_case_id = (
            select id from public.learning_cases where title = '监督权限回归：分数应用'
          )
            and title = '关闭后复发观察'
        )
      ),
      'practice',
      '重新安排两道针对性练习',
      date '2026-09-09'
    )$$,
  'admin can reopen a teacher Case without a lead assignment'
);

select is(
  (
    select status
    from public.learning_cases
    where title = '监督权限回归：分数应用'
  ),
  'confirmed',
  'manager reopen returns the Case to confirmed'
);

select is(
  (
    select owner_membership_id::text
    from public.learning_cases
    where title = '监督权限回归：分数应用'
  ),
  '61000000-0000-0000-0000-000000000001',
  'manager reopen preserves the original teacher Case owner'
);

select is(
  (
    select assigned_membership_id::text
    from public.case_actions
    where learning_case_id = (
      select id from public.learning_cases where title = '监督权限回归：分数应用'
    )
      and status = 'pending'
      and is_primary
  ),
  '61000000-0000-0000-0000-000000000001',
  'manager reopen keeps the next Action assigned to the teacher'
);

select is(
  (
    select actor_membership_id::text
    from public.case_events
    where learning_case_id = (
      select id from public.learning_cases where title = '监督权限回归：分数应用'
    )
      and event_type = 'case_reopened'
    order by occurred_at desc, id desc
    limit 1
  ),
  '2f300000-0000-0000-0000-000000000002',
  'audit history records the admin as the real reopen actor'
);

-- A plain teacher in the same organization still needs a real assignment and
-- teaching scope. Manager supervision must not weaken the teacher boundary.
select set_config('request.jwt.claim.sub', '2f200000-0000-0000-000000000003', true);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '2f200000-0000-0000-0000-000000000003',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '2f500000-0000-0000-0000-000000000003'
  )::text,
  true
);

select is(
  (
    select count(*)::integer
    from public.learning_cases
    where title = '监督权限回归：分数应用'
  ),
  0,
  'unassigned teacher still cannot read the supervised Case'
);

select throws_ok(
  $$select public.add_case_evidence(
      '2f700000-0000-0000-0000-000000000009',
      (select id from public.learning_cases where title = '监督权限回归：分数应用'),
      7,
      'observation',
      '不应写入',
      timestamptz '2026-09-08 12:00:00+08',
      '未任课老师不应能补充记录。'
    )$$,
  'P0001',
  null,
  'unassigned teacher still cannot mutate organization learning records'
);

reset role;
select * from finish();
rollback;
