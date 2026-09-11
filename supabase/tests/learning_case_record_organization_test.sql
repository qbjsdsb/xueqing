begin;

select plan(50);

select is(
  has_function_privilege(
    'authenticated',
    'public.void_learning_case(uuid,uuid,integer,text,text)',
    'execute'
  ),
  true,
  'authenticated users can reach the audited void command'
);

select is(
  has_function_privilege(
    'anon',
    'public.void_learning_case(uuid,uuid,integer,text,text)',
    'execute'
  ),
  false,
  'anonymous users cannot void learning records'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.restore_learning_case(uuid,uuid,integer)',
    'execute'
  ),
  true,
  'authenticated users can reach the manager-gated restore command'
);

select is(
  has_function_privilege(
    'anon',
    'public.restore_learning_case(uuid,uuid,integer)',
    'execute'
  ),
  false,
  'anonymous users cannot restore learning records'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.list_voided_learning_cases(uuid)',
    'execute'
  ),
  true,
  'authenticated teaching users can inspect the dedicated voided-record view'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_voided_learning_cases(uuid)',
    'execute'
  ),
  false,
  'anonymous users cannot inspect voided learning records'
);

select is(
  public.xueqing_backend_compatibility()->>'schema_version',
  '20260911193000',
  'backend compatibility advances through the complete v0.3.6 integrity guard'
);

select is(
  (public.xueqing_backend_compatibility()->'capabilities'->>'learning_case_record_organization')::boolean,
  true,
  'compatibility advertises learning-record organization'
);

select is(
  (public.xueqing_backend_compatibility()->'capabilities'->>'selective_learning_record_export')::boolean,
  true,
  'compatibility advertises case-aware selective export'
);

-- Create an isolated pure-teacher fixture in Organization A. Seed Teacher A is
-- intentionally also a manager, so the no-membership fictional user is given
-- only a teacher role here to prove the teacher/manager boundary.
insert into public.organization_memberships (
  id,
  organization_id,
  app_user_id,
  status
) values (
  '61000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000003',
  'active'
);

insert into public.membership_roles (
  id,
  organization_id,
  membership_id,
  role
) values (
  '62000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000003',
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
) values (
  '65000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000003',
  '64000000-0000-0000-0000-000000000001',
  'teaching',
  'active',
  date '2026-01-01'
);

insert into public.students (
  id,
  organization_id,
  name,
  status
) values (
  '30000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '分页边界测试学生',
  'active'
);

insert into public.student_subject_profiles (
  id,
  organization_id,
  student_id,
  organization_subject_id,
  status
) values (
  '67000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000003',
  '64000000-0000-0000-0000-000000000001',
  'active'
);

insert into public.student_teacher_assignments (
  id,
  organization_id,
  student_subject_profile_id,
  membership_id,
  assignment_role,
  status,
  active_from
) values (
  '68000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000003',
  '61000000-0000-0000-0000-000000000003',
  'lead',
  'active',
  date '2026-01-01'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000003', true);
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

select lives_ok(
  $$select public.quick_capture_case(
      '7e000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000003',
      1,
      'knowledge',
      '分页中应跳过的作废学情',
      null,
      timestamptz '2026-09-11 06:00:00+08',
      '这条记录随后会被作废。',
      null,
      null
    )$$,
  'pure teacher can create the first paging Case'
);

select set_config(
  'xueqing.page_void_case_id',
  (select id::text from public.learning_cases where title = '分页中应跳过的作废学情'),
  true
);

select lives_ok(
  $$select public.quick_capture_case(
      '7e000000-0000-0000-0000-000000000002',
      '67000000-0000-0000-0000-000000000003',
      1,
      'knowledge',
      '分页中必须保留的有效学情',
      null,
      timestamptz '2026-09-11 07:00:00+08',
      '即使前一条被作废，这条也必须出现在第一页。',
      null,
      null
    )$$,
  'pure teacher can create the active paging Case'
);

select set_config(
  'xueqing.page_active_case_id',
  (select id::text from public.learning_cases where title = '分页中必须保留的有效学情'),
  true
);

select lives_ok(
  $$select public.void_learning_case(
      '7e000000-0000-0000-0000-000000000003',
      current_setting('xueqing.page_void_case_id')::uuid,
      1,
      'duplicate',
      '分页测试：这条是重复记录'
    )$$,
  'pure teacher can void an assigned learning record'
);

select is(
  (select count(*)::int
   from public.learning_cases
   where id = current_setting('xueqing.page_void_case_id')::uuid),
  0,
  'ordinary RLS reads hide a voided Case even from its assigned teacher'
);

select is(
  (select count(*)::int
   from public.list_voided_learning_cases('67000000-0000-0000-0000-000000000003')
   where case_id = current_setting('xueqing.page_void_case_id')::uuid),
  1,
  'the dedicated audit read still exposes the assigned teacher voided Case'
);

select is(
  (select count(*)::int
   from public.list_student_subject_learning_records_v2_with_attachments(
     '67000000-0000-0000-0000-000000000003', 1, 0
   )),
  1,
  'active-record paging fills the first page after skipping a voided raw row'
);

select is(
  (select issue_title
   from public.list_student_subject_learning_records_v2_with_attachments(
     '67000000-0000-0000-0000-000000000003', 1, 0
   )),
  '分页中必须保留的有效学情',
  'the first active page returns the later valid Case'
);

select is(
  (select learning_case_id::text
   from public.list_student_subject_learning_records_v2_with_attachments(
     '67000000-0000-0000-0000-000000000003', 1, 0
   )),
  current_setting('xueqing.page_active_case_id'),
  'case-aware export preserves the stable Learning Case identity'
);

select is(
  (select count(*)::int
   from public.list_student_subject_learning_records_v2_with_attachments(
     '67000000-0000-0000-0000-000000000003', 1, 1
   )),
  0,
  'active-record offset is measured after voided rows are removed'
);

select is(
  (select issue_title
   from public.list_student_subject_learning_records_with_attachments(
     '67000000-0000-0000-0000-000000000003', 1, 0
   )),
  '分页中必须保留的有效学情',
  'installed v0.3.5 clients also receive correct active-record pagination'
);

-- A stale/revoked session must fail before it can mutate the still-active Case.
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '20000000-0000-0000-0000-000000000003',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-0000000000ff'
  )::text,
  true
);

select throws_ok(
  $$select public.void_learning_case(
      '7e000000-0000-0000-0000-000000000004',
      current_setting('xueqing.page_active_case_id')::uuid,
      1,
      'mistake',
      null
    )$$,
  'P0001',
  'invalid_live_session',
  'revoked session cannot void a learning record'
);

-- Cross-organization teacher must not gain access just by knowing a Case id.
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000002', true);
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
  $$select public.void_learning_case(
      '7e000000-0000-0000-0000-000000000005',
      current_setting('xueqing.page_active_case_id')::uuid,
      1,
      'mistake',
      null
    )$$,
  'P0001',
  'invalid_live_session',
  'cross-organization teacher cannot void the Case'
);

-- Return to the pure teacher for the full preservation/restore contract.
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000003', true);
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

select lives_ok(
  $$select public.quick_capture_case(
      '7e000000-0000-0000-0000-000000000006',
      '67000000-0000-0000-0000-000000000003',
      1,
      'habit',
      '作废后历史必须完整保留',
      '用于验证学情有效性和教学生命周期彼此独立。',
      timestamptz '2026-09-11 08:00:00+08',
      '学生课堂中出现一次需要记录的现象。',
      '下次课继续观察',
      timestamptz '2026-09-12 09:00:00+08'
    )$$,
  'pure teacher can create the preservation Case'
);

select set_config(
  'xueqing.void_case_id',
  (select id::text from public.learning_cases where title = '作废后历史必须完整保留'),
  true
);

select lives_ok(
  $$select public.void_learning_case(
      '7e000000-0000-0000-0000-000000000007',
      current_setting('xueqing.void_case_id')::uuid,
      1,
      'wrong_student_subject',
      '录错了学生或学科'
    )$$,
  'assigned teacher can audit-void an erroneous record'
);

reset role;

select is(
  (select record_state from public.learning_cases
   where id = current_setting('xueqing.void_case_id')::uuid),
  'voided',
  'void changes record validity'
);

select is(
  (select status from public.learning_cases
   where id = current_setting('xueqing.void_case_id')::uuid),
  'new',
  'void does not fabricate a teaching lifecycle close'
);

select is(
  (select version from public.learning_cases
   where id = current_setting('xueqing.void_case_id')::uuid),
  2,
  'void advances the optimistic Case version once'
);

select is(
  (select count(*)::int from public.case_evidence
   where learning_case_id = current_setting('xueqing.void_case_id')::uuid),
  1,
  'void preserves historical Evidence'
);

select is(
  (select count(*)::int from public.case_actions
   where learning_case_id = current_setting('xueqing.void_case_id')::uuid
     and status = 'pending'
     and is_primary),
  0,
  'void removes the Case from actionable work'
);

select is(
  (select count(*)::int from public.case_actions
   where learning_case_id = current_setting('xueqing.void_case_id')::uuid
     and status = 'cancelled'),
  1,
  'void audits cancellation of the pending primary Action'
);

select is(
  (select count(*)::int from public.case_events
   where learning_case_id = current_setting('xueqing.void_case_id')::uuid
     and event_type = 'case_voided'),
  1,
  'void writes one explicit case_voided audit event'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000003', true);
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
  $$select public.restore_learning_case(
      '7e000000-0000-0000-0000-000000000008',
      current_setting('xueqing.void_case_id')::uuid,
      2
    )$$,
  'P0001',
  'manager_permission_required',
  'ordinary teacher cannot restore a voided record'
);

-- Seed Teacher A is org admin/owner and exercises the manager recovery path.
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

select is(
  (select count(*)::int
   from public.list_voided_learning_cases('67000000-0000-0000-0000-000000000003')
   where case_id = current_setting('xueqing.void_case_id')::uuid),
  1,
  'manager can inspect the voided record before restoring it'
);

select lives_ok(
  $$select public.restore_learning_case(
      '7e000000-0000-0000-0000-000000000009',
      current_setting('xueqing.void_case_id')::uuid,
      2
    )$$,
  'manager can restore the exact original Case'
);

reset role;

select is(
  (select record_state from public.learning_cases
   where id = current_setting('xueqing.void_case_id')::uuid),
  'active',
  'restore makes the original record valid again'
);

select is(
  (select status from public.learning_cases
   where id = current_setting('xueqing.void_case_id')::uuid),
  'new',
  'restore preserves the teaching lifecycle state'
);

select is(
  (select count(*)::int from public.case_actions
   where learning_case_id = current_setting('xueqing.void_case_id')::uuid
     and status = 'pending'
     and is_primary),
  0,
  'restore does not invent a replacement reminder'
);

select is(
  (select count(*)::int from public.case_events
   where learning_case_id = current_setting('xueqing.void_case_id')::uuid
     and event_type = 'case_restored'),
  1,
  'restore writes one explicit case_restored audit event'
);

-- Normal “not an issue” is still a teaching decision, not an invalid record.
set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000003', true);
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

select lives_ok(
  $$select public.quick_capture_case(
      '7e000000-0000-0000-0000-000000000010',
      '67000000-0000-0000-0000-000000000003',
      1,
      'other',
      '正常确认不是问题',
      null,
      timestamptz '2026-09-11 09:00:00+08',
      '观察后确认无需继续跟进。',
      null,
      null
    )$$,
  'create a Case for ordinary not-issue closure'
);

select set_config(
  'xueqing.not_issue_case_id',
  (select id::text from public.learning_cases where title = '正常确认不是问题'),
  true
);

select lives_ok(
  $$select public.end_case_follow_up(
      '7e000000-0000-0000-0000-000000000011',
      current_setting('xueqing.not_issue_case_id')::uuid,
      1,
      'not_issue',
      '经确认只是偶发现象',
      timestamptz '2026-09-11 09:30:00+08'
    )$$,
  'ordinary not-issue closure remains available'
);

reset role;

select is(
  (select record_state from public.learning_cases
   where id = current_setting('xueqing.not_issue_case_id')::uuid),
  'active',
  'ordinary not-issue closure remains a valid historical record'
);

select is(
  (select status from public.learning_cases
   where id = current_setting('xueqing.not_issue_case_id')::uuid),
  'closed',
  'ordinary not-issue closure keeps its teaching lifecycle close'
);

select is(
  (select count(*)::int from public.case_events
   where learning_case_id = current_setting('xueqing.not_issue_case_id')::uuid
     and event_type = 'case_voided'),
  0,
  'ordinary not-issue closure is never misclassified as a void'
);

-- Exact v0.3.5 delete signature is bridged to the new record-validity model.
set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000003', true);
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

select lives_ok(
  $$select public.quick_capture_case(
      '7e000000-0000-0000-0000-000000000012',
      '67000000-0000-0000-0000-000000000003',
      1,
      'other',
      '旧版删除兼容测试',
      null,
      timestamptz '2026-09-11 10:00:00+08',
      '模拟 v0.3.5 已安装客户端。',
      null,
      null
    )$$,
  'create a Case for the v0.3.5 delete compatibility bridge'
);

select set_config(
  'xueqing.legacy_delete_case_id',
  (select id::text from public.learning_cases where title = '旧版删除兼容测试'),
  true
);

select lives_ok(
  $$select public.end_case_follow_up(
      '7e000000-0000-0000-0000-000000000013',
      current_setting('xueqing.legacy_delete_case_id')::uuid,
      1,
      'not_issue',
      '教师删除/作废误建或重复问题',
      timestamptz '2026-09-11 10:30:00+08'
    )$$,
  'exact old delete signature is accepted without breaking the old client call'
);

reset role;

select is(
  (select record_state from public.learning_cases
   where id = current_setting('xueqing.legacy_delete_case_id')::uuid),
  'voided',
  'old delete becomes an audited void'
);

select is(
  (select status from public.learning_cases
   where id = current_setting('xueqing.legacy_delete_case_id')::uuid),
  'new',
  'old delete does not permanently falsify teaching lifecycle history'
);

select is(
  (select closed_at from public.learning_cases
   where id = current_setting('xueqing.legacy_delete_case_id')::uuid),
  null,
  'old delete bridge clears the artificial close timestamp'
);

select is(
  (select void_reason from public.learning_cases
   where id = current_setting('xueqing.legacy_delete_case_id')::uuid),
  'legacy_delete',
  'old delete records an explicit compatibility reason'
);

select is(
  (select count(*)::int from public.case_events
   where learning_case_id = current_setting('xueqing.legacy_delete_case_id')::uuid
     and event_type = 'case_voided'),
  1,
  'old delete creates one case_voided audit event'
);

select is(
  (select count(*)::int from public.case_events
   where learning_case_id = current_setting('xueqing.legacy_delete_case_id')::uuid
     and event_type = 'case_closed'),
  1,
  'old client close event remains preserved for audit traceability'
);

select * from finish();
rollback;
