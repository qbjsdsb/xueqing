begin;

select plan(56);

-- TEST 01
select is(
  to_regprocedure('public.pause_organization_student_teaching(uuid,uuid,uuid,integer)') is not null,
  true,
  'pause student teaching function exists'
);
-- TEST 02
select is(
  to_regprocedure('public.resume_organization_student_teaching(uuid,uuid,uuid,integer)') is not null,
  true,
  'resume student teaching function exists'
);
-- TEST 03
select is(
  (select prosecdef from pg_proc where oid = to_regprocedure('public.pause_organization_student_teaching(uuid,uuid,uuid,integer)')),
  false,
  'pause public function is security-invoker'
);
-- TEST 04
select is(
  (select prosecdef from pg_proc where oid = to_regprocedure('public.resume_organization_student_teaching(uuid,uuid,uuid,integer)')),
  false,
  'resume public function is security-invoker'
);
-- TEST 05
select is(
  has_function_privilege('anon', 'public.pause_organization_student_teaching(uuid,uuid,uuid,integer)', 'execute'),
  false,
  'anon cannot pause student teaching'
);
-- TEST 06
select is(
  has_function_privilege('authenticated', 'public.pause_organization_student_teaching(uuid,uuid,uuid,integer)', 'execute'),
  true,
  'authenticated may call manager-gated pause command'
);
-- TEST 07
select is(
  has_function_privilege('anon', 'public.resume_organization_student_teaching(uuid,uuid,uuid,integer)', 'execute'),
  false,
  'anon cannot resume student teaching'
);
-- TEST 08
select is(
  has_function_privilege('authenticated', 'public.resume_organization_student_teaching(uuid,uuid,uuid,integer)', 'execute'),
  true,
  'authenticated may call manager-gated resume command'
);

reset role;

insert into public.students (
  id, organization_id, name, student_code, status, version
) values (
  '30000000-0000-0000-0000-000000000098',
  '00000000-0000-0000-0000-000000000001',
  '暂停恢复测试学生',
  'PAUSE-098',
  'active',
  1
);

insert into public.student_subject_profiles (
  id, organization_id, student_id, organization_subject_id, status, version
) values (
  '67000000-0000-0000-0000-000000000098',
  '00000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000098',
  '64000000-0000-0000-0000-000000000001',
  'active',
  1
);

insert into public.student_teacher_assignments (
  id, organization_id, student_subject_profile_id, membership_id,
  assignment_role, status, active_from, version
) values (
  '71000000-0000-0000-0000-000000000098',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000098',
  '61000000-0000-0000-0000-000000000001',
  'lead',
  'active',
  '2026-01-01',
  1
);

insert into public.learning_cases (
  id, organization_id, student_subject_profile_id, owner_membership_id,
  case_type, title, priority, status, first_observed_at, version,
  created_by_app_user_id, created_by_membership_id
) values (
  '72000000-0000-0000-0000-000000000098',
  '00000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000098',
  '61000000-0000-0000-0000-000000000001',
  'knowledge',
  '暂停期间仍需保留的问题',
  'normal',
  'confirmed',
  timezone('utc', now()),
  1,
  '10000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001'
);

insert into public.case_actions (
  id, organization_id, learning_case_id, assigned_membership_id,
  action_type, title, is_primary, status, version
) values (
  '73000000-0000-0000-0000-000000000098',
  '00000000-0000-0000-0000-000000000001',
  '72000000-0000-0000-0000-000000000098',
  '61000000-0000-0000-0000-000000000001',
  'verify',
  '恢复后继续验证',
  true,
  'pending',
  1
);

insert into public.students (
  id, organization_id, name, status, version
) values
  (
    '30000000-0000-0000-0000-000000000096',
    '00000000-0000-0000-0000-000000000001',
    '可归档测试学生',
    'inactive',
    1
  ),
  (
    '30000000-0000-0000-0000-000000000095',
    '00000000-0000-0000-0000-000000000001',
    '仍有活跃学科测试学生',
    'inactive',
    1
  );

insert into public.student_subject_profiles (
  id, organization_id, student_id, organization_subject_id, status, version
) values
  (
    '67000000-0000-0000-0000-000000000096',
    '00000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000096',
    '64000000-0000-0000-0000-000000000001',
    'inactive',
    1
  ),
  (
    '67000000-0000-0000-0000-000000000095',
    '00000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000095',
    '64000000-0000-0000-0000-000000000001',
    'active',
    1
  );

insert into public.students (
  id, organization_id, name, status, version, archived_at
) values (
  '30000000-0000-0000-0000-000000000097',
  '00000000-0000-0000-0000-000000000001',
  '已归档测试学生',
  'archived',
  1,
  timezone('utc', now())
);

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

-- TEST 09
select is(
  (select private.can_read_profile_v2('67000000-0000-0000-0000-000000000098')),
  true,
  'current teacher can read the active student before pause'
);
-- TEST 10
select is(
  public.pause_organization_student_teaching(
    '76000000-0000-0000-0000-000000000201',
    '00000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000098',
    1
  ) ->> 'status',
  'inactive',
  'manager can pause an active student'
);

reset role;
-- TEST 11
select is((select status from public.students where id = '30000000-0000-0000-0000-000000000098'), 'inactive', 'pause changes only root visibility state');
-- TEST 12
select is((select version from public.students where id = '30000000-0000-0000-0000-000000000098'), 2, 'pause increments student version exactly once');
-- TEST 13
select is((select archived_at is null from public.students where id = '30000000-0000-0000-0000-000000000098'), true, 'pause is not archive');
-- TEST 14
select is((select status from public.student_subject_profiles where id = '67000000-0000-0000-0000-000000000098'), 'active', 'pause preserves active subject profile');
-- TEST 15
select is((select version from public.student_subject_profiles where id = '67000000-0000-0000-0000-000000000098'), 1, 'pause does not rewrite subject profile version');
-- TEST 16
select is((select status from public.student_teacher_assignments where id = '71000000-0000-0000-0000-000000000098'), 'active', 'pause preserves current teacher assignment');
-- TEST 17
select is((select version from public.student_teacher_assignments where id = '71000000-0000-0000-0000-000000000098'), 1, 'pause does not rewrite assignment version');
-- TEST 18
select is((select status from public.learning_cases where id = '72000000-0000-0000-0000-000000000098'), 'confirmed', 'pause preserves open Learning Case');
-- TEST 19
select is((select version from public.learning_cases where id = '72000000-0000-0000-0000-000000000098'), 1, 'pause does not rewrite Case version');
-- TEST 20
select is((select status from public.case_actions where id = '73000000-0000-0000-0000-000000000098'), 'pending', 'pause preserves pending Action');
-- TEST 21
select is((select version from public.case_actions where id = '73000000-0000-0000-0000-000000000098'), 1, 'pause does not rewrite Action version');

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
-- TEST 22
select is(
  (select private.can_read_profile_v2('67000000-0000-0000-0000-000000000098')),
  false,
  'paused student disappears from teacher read boundary'
);
-- TEST 23
select is(
  public.pause_organization_student_teaching(
    '76000000-0000-0000-0000-000000000201',
    '00000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000098',
    1
  ) ->> 'status',
  'inactive',
  'same pause operation replays committed result'
);

reset role;
-- TEST 24
select is((select version from public.students where id = '30000000-0000-0000-0000-000000000098'), 2, 'pause replay does not increment version again');

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
-- TEST 25
select throws_ok(
  $$select public.pause_organization_student_teaching('76000000-0000-0000-0000-000000000203','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000098',2)$$,
  'P0001', 'student_teaching_not_active', 'a different pause cannot pause an already paused student'
);
-- TEST 26
select throws_ok(
  $$select public.pause_organization_student_teaching('76000000-0000-0000-0000-000000000204','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000098',1)$$,
  'P0001', 'version_conflict', 'stale pause is rejected before overwriting newer state'
);
-- TEST 27
select is(
  public.resume_organization_student_teaching(
    '76000000-0000-0000-0000-000000000202',
    '00000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000098',
    2
  ) ->> 'status',
  'active',
  'manager can resume a paused student'
);

reset role;
-- TEST 28
select is((select status from public.students where id = '30000000-0000-0000-0000-000000000098'), 'active', 'resume restores root teaching visibility');
-- TEST 29
select is((select version from public.students where id = '30000000-0000-0000-0000-000000000098'), 3, 'resume increments student version exactly once');
-- TEST 30
select is((select status from public.student_subject_profiles where id = '67000000-0000-0000-0000-000000000098'), 'active', 'resume reuses original subject profile');
-- TEST 31
select is((select status from public.student_teacher_assignments where id = '71000000-0000-0000-0000-000000000098'), 'active', 'resume reuses original teacher responsibility');
-- TEST 32
select is((select status from public.learning_cases where id = '72000000-0000-0000-0000-000000000098'), 'confirmed', 'resume returns original open Case unchanged');
-- TEST 33
select is((select status from public.case_actions where id = '73000000-0000-0000-0000-000000000098'), 'pending', 'resume returns original pending Action unchanged');

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
-- TEST 34
select is((select private.can_read_profile_v2('67000000-0000-0000-0000-000000000098')), true, 'teacher read boundary returns after resume');
-- TEST 35
select is(
  public.resume_organization_student_teaching(
    '76000000-0000-0000-0000-000000000202',
    '00000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000098',
    2
  ) ->> 'status',
  'active',
  'same resume operation replays committed result'
);

reset role;
-- TEST 36
select is((select version from public.students where id = '30000000-0000-0000-0000-000000000098'), 3, 'resume replay does not increment version again');

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
-- TEST 37
select throws_ok(
  $$select public.resume_organization_student_teaching('76000000-0000-0000-0000-000000000205','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000098',3)$$,
  'P0001', 'student_teaching_not_paused', 'a different resume cannot resume an already active student'
);

reset role;
set local role authenticated;
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
-- TEST 38
select throws_ok(
  $$select public.pause_organization_student_teaching('76000000-0000-0000-0000-000000000206','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000098',3)$$,
  'P0001', 'organization_manager_required', 'member from another organization cannot pause this student'
);

reset role;
-- TEST 39
select is((select status from public.students where id = '30000000-0000-0000-0000-000000000098'), 'active', 'unauthorized pause leaves root unchanged');

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
-- TEST 40
select throws_ok(
  $$select public.pause_organization_student_teaching('76000000-0000-0000-0000-000000000207','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000097',1)$$,
  'P0001', 'student_archived_immutable', 'archive is not silently treated as temporary pause'
);
-- TEST 41
select throws_ok(
  $$select public.resume_organization_student_teaching('76000000-0000-0000-0000-000000000208','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000097',1)$$,
  'P0001', 'student_archived_immutable', 'archived student cannot be restored through temporary resume'
);

reset role;
-- TEST 42
select is((select version from public.students where id = '30000000-0000-0000-0000-000000000097'), 1, 'rejected archive transitions do not change version');
-- TEST 43
select is((select count(*)::int from public.operation_receipts where target_id = '30000000-0000-0000-0000-000000000098' and command_type in ('pause_organization_student_teaching','resume_organization_student_teaching')), 2, 'only successful pause and resume operations commit receipts');
-- TEST 44
select is((select count(*)::int from public.student_subject_profiles where student_id = '30000000-0000-0000-0000-000000000098'), 1, 'pause and resume never duplicate subject profiles');
-- TEST 45
select is((select count(*)::int from public.student_teacher_assignments where student_subject_profile_id = '67000000-0000-0000-0000-000000000098'), 1, 'pause and resume never duplicate teacher assignments');
-- TEST 46
select is((select count(*)::int from public.learning_cases where student_subject_profile_id = '67000000-0000-0000-0000-000000000098'), 1, 'pause and resume never duplicate Cases');
-- TEST 47
select is((select count(*)::int from public.case_actions where learning_case_id = '72000000-0000-0000-0000-000000000098'), 1, 'pause and resume never duplicate Actions');

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
-- TEST 48
select throws_ok(
  $$select public.update_organization_student('76000000-0000-0000-0000-000000000209','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000098',3,'暂停恢复测试学生','PAUSE-098','archived')$$,
  'P0001', 'student_archive_requires_paused', 'active student cannot skip temporary pause and jump directly to archive'
);
-- TEST 49
select throws_ok(
  $$select public.update_organization_student('76000000-0000-0000-0000-000000000210','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000095',1,'仍有活跃学科测试学生',null,'archived')$$,
  'P0001', 'student_archive_active_subjects', 'paused student with an active subject cannot be misclassified as archived'
);
-- TEST 50
select is(
  public.update_organization_student(
    '76000000-0000-0000-0000-000000000211',
    '00000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000096',
    1,
    '可归档测试学生',
    null,
    'archived'
  ) ->> 'status',
  'archived',
  'paused student whose subject services have ended can be archived'
);

reset role;
-- TEST 51
select is((select status from public.students where id = '30000000-0000-0000-0000-000000000096'), 'archived', 'archive persists root archive state');
-- TEST 52
select is((select archived_at is not null from public.students where id = '30000000-0000-0000-0000-000000000096'), true, 'archive records archive timestamp');

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
-- TEST 53
select throws_ok(
  $$select public.update_organization_student('76000000-0000-0000-0000-000000000212','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000096',2,'可归档测试学生',null,'active')$$,
  'P0001', 'student_unarchive_requires_inactive', 'archived student cannot jump directly back into teaching'
);
-- TEST 54
select is(
  public.update_organization_student(
    '76000000-0000-0000-0000-000000000213',
    '00000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000096',
    2,
    '可归档测试学生',
    null,
    'inactive'
  ) ->> 'status',
  'inactive',
  'explicit unarchive returns student to paused state'
);

reset role;
-- TEST 55
select is((select version from public.students where id = '30000000-0000-0000-0000-000000000096'), 3, 'archive and unarchive each increment root version once');
-- TEST 56
select is((select archived_at is null from public.students where id = '30000000-0000-0000-0000-000000000096'), true, 'unarchive clears archive timestamp without restoring teaching');

select * from finish();
rollback;
