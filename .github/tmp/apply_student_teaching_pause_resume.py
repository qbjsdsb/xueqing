from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    assert count == 1, f"{path}: expected 1 match, found {count}"
    path.write_text(text.replace(old, new, 1))


# ---------------------------------------------------------------------------
# Database migration: student-root pause/resume is deliberately different from
# per-subject end/restore. It changes only the student root visibility state.
# ---------------------------------------------------------------------------
migration = r'''-- Separate temporary whole-student teaching pause/resume from ordinary edits.
--
-- A root pause is intentionally reversible and does NOT close Cases, cancel
-- Actions, end subject profiles, or end teacher assignments. Those records are
-- the teaching context that must become visible again when the student resumes.
-- Permanent per-subject termination remains a separate subject lifecycle.

alter table public.operation_receipts
  drop constraint if exists operation_receipts_command_type_check;

alter table public.operation_receipts
  add constraint operation_receipts_command_type_check
  check (command_type in (
    'quick_capture_case',
    'confirm_case',
    'add_case_evidence',
    'record_intervention',
    'record_assessment',
    'stabilize_case',
    'close_case',
    'reschedule_case_action',
    'quick_capture_case_with_type',
    'create_organization_case_type',
    'rename_organization_case_type',
    'archive_organization_case_type',
    'create_organization_subject',
    'create_organization_student',
    'add_organization_student_subject_service',
    'end_organization_student_subject_service',
    'restore_organization_student_subject_service',
    'pause_organization_student_teaching',
    'resume_organization_student_teaching',
    'update_organization_student',
    'transfer_organization_student_teacher_assignment',
    'update_organization_teacher_subject_scope',
    'update_organization_membership_status',
    'create_organization_invitation',
    'approve_organization_invitation',
    'revoke_organization_invitation',
    'reissue_organization_invitation',
    'accept_organization_invitation',
    'prepare_member_credential_reissue',
    'provision_organization_member_from_auth',
    'revoke_member_auth_sessions',
    'complete_member_onboarding',
    'complete_case_action',
    'reopen_case'
  ));

create or replace function private.pause_organization_student_teaching(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_id uuid,
  p_expected_student_version integer
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_app_user_id uuid;
  v_organization_id uuid;
  v_student_name text;
  v_student_code text;
  v_student_status text;
  v_student_version integer;
  v_is_claimed boolean;
  v_existing_result jsonb;
  v_command_result jsonb;
begin
  if p_operation_id is null
    or p_organization_id is null
    or p_student_id is null
    or p_expected_student_version is null
    or p_expected_student_version <= 0 then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_student_teaching_lifecycle_input';
  end if;

  v_app_user_id := (select private.current_app_user_id_v2());
  if v_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select organization.id
  into v_organization_id
  from public.organizations as organization
  where organization.id = p_organization_id
    and organization.status = 'active'
  for update;

  if v_organization_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'organization_not_found';
  end if;

  if not (select private.can_manage_organization_v2(v_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  select student.name, student.student_code, student.status, student.version
  into v_student_name, v_student_code, v_student_status, v_student_version
  from public.students as student
  where student.id = p_student_id
    and student.organization_id = v_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'student_not_found';
  end if;

  select claimed, result
  into v_is_claimed, v_existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'pause_organization_student_teaching',
    'student',
    p_student_id
  );

  if not v_is_claimed then
    return v_existing_result;
  end if;

  if v_student_version <> p_expected_student_version then
    raise exception using
      errcode = 'P0001',
      message = 'version_conflict';
  end if;

  if v_student_status = 'merged' then
    raise exception using
      errcode = 'P0001',
      message = 'student_merged_immutable';
  end if;

  if v_student_status = 'archived' then
    raise exception using
      errcode = 'P0001',
      message = 'student_archived_immutable';
  end if;

  if v_student_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'student_teaching_not_active';
  end if;

  update public.students
  set status = 'inactive',
      version = version + 1,
      archived_at = null,
      updated_at = timezone('utc', now())
  where id = p_student_id
    and organization_id = v_organization_id;

  v_command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', v_organization_id,
    'student_id', p_student_id,
    'student_name', v_student_name,
    'student_code', v_student_code,
    'status', 'inactive',
    'version', v_student_version + 1
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    v_command_result
  );

  return v_command_result;
end
$function$;

revoke all on function private.pause_organization_student_teaching(
  uuid, uuid, uuid, integer
) from public, anon, authenticated, service_role;
grant execute on function private.pause_organization_student_teaching(
  uuid, uuid, uuid, integer
) to service_role, authenticated;

create or replace function public.pause_organization_student_teaching(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_id uuid,
  p_expected_student_version integer
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.pause_organization_student_teaching(
    p_operation_id,
    p_organization_id,
    p_student_id,
    p_expected_student_version
  )
$function$;

revoke all on function public.pause_organization_student_teaching(
  uuid, uuid, uuid, integer
) from public, anon, authenticated, service_role;
grant execute on function public.pause_organization_student_teaching(
  uuid, uuid, uuid, integer
) to service_role, authenticated;

create or replace function private.resume_organization_student_teaching(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_id uuid,
  p_expected_student_version integer
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_app_user_id uuid;
  v_organization_id uuid;
  v_student_name text;
  v_student_code text;
  v_student_status text;
  v_student_version integer;
  v_is_claimed boolean;
  v_existing_result jsonb;
  v_command_result jsonb;
begin
  if p_operation_id is null
    or p_organization_id is null
    or p_student_id is null
    or p_expected_student_version is null
    or p_expected_student_version <= 0 then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_student_teaching_lifecycle_input';
  end if;

  v_app_user_id := (select private.current_app_user_id_v2());
  if v_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select organization.id
  into v_organization_id
  from public.organizations as organization
  where organization.id = p_organization_id
    and organization.status = 'active'
  for update;

  if v_organization_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'organization_not_found';
  end if;

  if not (select private.can_manage_organization_v2(v_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  select student.name, student.student_code, student.status, student.version
  into v_student_name, v_student_code, v_student_status, v_student_version
  from public.students as student
  where student.id = p_student_id
    and student.organization_id = v_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'student_not_found';
  end if;

  select claimed, result
  into v_is_claimed, v_existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'resume_organization_student_teaching',
    'student',
    p_student_id
  );

  if not v_is_claimed then
    return v_existing_result;
  end if;

  if v_student_version <> p_expected_student_version then
    raise exception using
      errcode = 'P0001',
      message = 'version_conflict';
  end if;

  if v_student_status = 'merged' then
    raise exception using
      errcode = 'P0001',
      message = 'student_merged_immutable';
  end if;

  if v_student_status = 'archived' then
    raise exception using
      errcode = 'P0001',
      message = 'student_archived_immutable';
  end if;

  if v_student_status <> 'inactive' then
    raise exception using
      errcode = 'P0001',
      message = 'student_teaching_not_paused';
  end if;

  update public.students
  set status = 'active',
      version = version + 1,
      archived_at = null,
      updated_at = timezone('utc', now())
  where id = p_student_id
    and organization_id = v_organization_id;

  v_command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', v_organization_id,
    'student_id', p_student_id,
    'student_name', v_student_name,
    'student_code', v_student_code,
    'status', 'active',
    'version', v_student_version + 1
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    v_command_result
  );

  return v_command_result;
end
$function$;

revoke all on function private.resume_organization_student_teaching(
  uuid, uuid, uuid, integer
) from public, anon, authenticated, service_role;
grant execute on function private.resume_organization_student_teaching(
  uuid, uuid, uuid, integer
) to service_role, authenticated;

create or replace function public.resume_organization_student_teaching(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_id uuid,
  p_expected_student_version integer
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.resume_organization_student_teaching(
    p_operation_id,
    p_organization_id,
    p_student_id,
    p_expected_student_version
  )
$function$;

revoke all on function public.resume_organization_student_teaching(
  uuid, uuid, uuid, integer
) from public, anon, authenticated, service_role;
grant execute on function public.resume_organization_student_teaching(
  uuid, uuid, uuid, integer
) to service_role, authenticated;
'''
Path('supabase/migrations/20260908023000_student_teaching_pause_resume.sql').write_text(migration)

# ---------------------------------------------------------------------------
# Deterministic pgTAP fixture. Pending Case/Action are deliberately present:
# pause must hide the root from teaching reads without falsifying those facts.
# ---------------------------------------------------------------------------
db_test = r'''begin;

select plan(47);

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

select * from finish();
rollback;
'''
assert db_test.count('-- TEST ') == 47
Path('supabase/tests/student_teaching_pause_resume_test.sql').write_text(db_test)

# ---------------------------------------------------------------------------
# Strengthen the global public/private RPC security contract with the four
# student lifecycle RPCs introduced after the original boundary migration.
# ---------------------------------------------------------------------------
security_test = Path('supabase/tests/public_rpc_security_boundary_test.sql')
replace_once(
    security_test,
    "    ('public.create_organization_subject(uuid, uuid, uuid)'::regprocedure, true),\n",
    "    ('public.create_organization_subject(uuid, uuid, uuid)'::regprocedure, true),\n"
    "    ('public.end_organization_student_subject_service(uuid, uuid, uuid, integer)'::regprocedure, true),\n",
)
replace_once(
    security_test,
    "    ('public.prepare_member_credential_reissue(uuid, uuid, uuid, uuid)'::regprocedure, false),\n",
    "    ('public.pause_organization_student_teaching(uuid, uuid, uuid, integer)'::regprocedure, true),\n"
    "    ('public.prepare_member_credential_reissue(uuid, uuid, uuid, uuid)'::regprocedure, false),\n",
)
replace_once(
    security_test,
    "    ('public.reschedule_case_action(uuid, uuid, uuid, integer, integer, date)'::regprocedure, true),\n",
    "    ('public.reschedule_case_action(uuid, uuid, uuid, integer, integer, date)'::regprocedure, true),\n"
    "    ('public.restore_organization_student_subject_service(uuid, uuid, uuid, integer, uuid, date)'::regprocedure, true),\n"
    "    ('public.resume_organization_student_teaching(uuid, uuid, uuid, integer)'::regprocedure, true),\n",
)
replace_once(security_test, "  (select count(*) from found) = 39\n", "  (select count(*) from found) = 43\n")
replace_once(
    security_test,
    "    ('private.create_organization_subject(uuid, uuid, uuid)'::regprocedure, true),\n",
    "    ('private.create_organization_subject(uuid, uuid, uuid)'::regprocedure, true),\n"
    "    ('private.end_organization_student_subject_service(uuid, uuid, uuid, integer)'::regprocedure, true),\n",
)
replace_once(
    security_test,
    "    ('private.prepare_member_credential_reissue(uuid, uuid, uuid, uuid)'::regprocedure, false),\n",
    "    ('private.pause_organization_student_teaching(uuid, uuid, uuid, integer)'::regprocedure, true),\n"
    "    ('private.prepare_member_credential_reissue(uuid, uuid, uuid, uuid)'::regprocedure, false),\n",
)
replace_once(
    security_test,
    "    ('private.reschedule_case_action(uuid, uuid, uuid, integer, integer, date)'::regprocedure, true),\n",
    "    ('private.reschedule_case_action(uuid, uuid, uuid, integer, integer, date)'::regprocedure, true),\n"
    "    ('private.restore_organization_student_subject_service(uuid, uuid, uuid, integer, uuid, date)'::regprocedure, true),\n"
    "    ('private.resume_organization_student_teaching(uuid, uuid, uuid, integer)'::regprocedure, true),\n",
)
replace_once(security_test, "  (select count(*) from found) = 39\n", "  (select count(*) from found) = 43\n")

# ---------------------------------------------------------------------------
# Repository contract + concrete Supabase implementation.
# ---------------------------------------------------------------------------
repo = Path('lib/cloud/organization_management_repository.dart')
replace_once(
    repo,
    "class OrganizationStudentUpdateResult {\n",
    '''class OrganizationStudentTeachingLifecycleResult {
  const OrganizationStudentTeachingLifecycleResult({
    required this.operationId,
    required this.organizationId,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.status,
    required this.version,
  });

  final String operationId;
  final String organizationId;
  final String studentId;
  final String studentName;
  final String? studentCode;
  final String status;
  final int version;

  factory OrganizationStudentTeachingLifecycleResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationStudentTeachingLifecycleResult(
      operationId: _requiredString(json['operation_id'], 'operation_id'),
      organizationId: _requiredString(
        json['organization_id'],
        'organization_id',
      ),
      studentId: _requiredString(json['student_id'], 'student_id'),
      studentName: _stringValue(json['student_name']) ?? '未命名学生',
      studentCode: _stringValue(json['student_code']),
      status: _stringValue(json['status']) ?? 'unknown',
      version: _intValue(json['version']) ?? 1,
    );
  }
}

class OrganizationStudentUpdateResult {
''',
)
replace_once(
    repo,
    '''  Future<OrganizationStudentTeacherAssignmentTransferResult>
  transferStudentTeacherAssignment({
''',
    '''  Future<OrganizationStudentTeachingLifecycleResult> pauseStudentTeaching({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
  });

  Future<OrganizationStudentTeachingLifecycleResult> resumeStudentTeaching({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
  });

  Future<OrganizationStudentTeacherAssignmentTransferResult>
  transferStudentTeacherAssignment({
''',
)
replace_once(
    repo,
    "String? organizationStudentLifecycleErrorMessage(Object error) {\n",
    '''String? organizationStudentTeachingLifecycleErrorMessage(Object error) {
  final detail = switch (error) {
    AuthException(:final message) => message.trim(),
    PostgrestException(:final message) => message.trim(),
    _ => null,
  };
  if (detail == null) return null;
  return switch (detail.toLowerCase()) {
    'invalid_student_teaching_lifecycle_input' => '学生教学状态信息不完整，请刷新后重试。',
    'organization_not_found' => '机构不存在或已归档，请刷新后重试。',
    'student_not_found' => '学生档案已变化，请刷新后重试。',
    'student_merged_immutable' => '已合并学生不能再修改教学状态。',
    'student_archived_immutable' => '已归档学生不能通过暂停/恢复改变状态。',
    'student_teaching_not_active' => '学生当前已经不是正常教学状态，请刷新后重试。',
    'student_teaching_not_paused' => '学生当前不处于暂停教学状态，请刷新后重试。',
    'version_conflict' => '这位学生刚刚被别人修改，请刷新后重试。',
    'operation_id_reuse_conflict' => '这次操作编号已被用于另一项操作，请重新打开后再试。',
    'operation_incomplete' => '上一次操作还没有完成，请稍后重试。',
    'invalid_live_session' => '登录状态已失效，请重新登录。',
    'organization_manager_required' => '当前账号没有本机构管理权限。',
    _ => null,
  };
}

String? organizationStudentLifecycleErrorMessage(Object error) {
''',
)
replace_once(
    repo,
    '''  @override
  Future<OrganizationStudentTeacherAssignmentTransferResult>
  transferStudentTeacherAssignment({
''',
    '''  @override
  Future<OrganizationStudentTeachingLifecycleResult> pauseStudentTeaching({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentId.trim().isEmpty ||
        expectedStudentVersion <= 0) {
      throw ArgumentError('Student teaching lifecycle identity is invalid.');
    }
    final response = await _call(
      'pause_organization_student_teaching',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_id': studentId,
        'p_expected_student_version': expectedStudentVersion,
      },
    );
    return OrganizationStudentTeachingLifecycleResult.fromJson(
      _mapResponse(response),
    );
  }

  @override
  Future<OrganizationStudentTeachingLifecycleResult> resumeStudentTeaching({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentId.trim().isEmpty ||
        expectedStudentVersion <= 0) {
      throw ArgumentError('Student teaching lifecycle identity is invalid.');
    }
    final response = await _call(
      'resume_organization_student_teaching',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_id': studentId,
        'p_expected_student_version': expectedStudentVersion,
      },
    );
    return OrganizationStudentTeachingLifecycleResult.fromJson(
      _mapResponse(response),
    );
  }

  @override
  Future<OrganizationStudentTeacherAssignmentTransferResult>
  transferStudentTeacherAssignment({
''',
)

# Repository-level parser/error copy coverage.
repo_test = Path('test/cloud/organization_management_repository_test.dart')
replace_once(
    repo_test,
    "  test('parses teacher subject scope history and command results', () {\n",
    '''  test('parses and explains student teaching lifecycle results', () {
    final result = OrganizationStudentTeachingLifecycleResult.fromJson({
      'operation_id': 'operation-pause',
      'organization_id': 'org-1',
      'student_id': 'student-1',
      'student_name': '示例学生',
      'student_code': 'S-001',
      'status': 'inactive',
      'version': 4,
    });
    expect(result.status, 'inactive');
    expect(result.version, 4);
    expect(
      organizationStudentTeachingLifecycleErrorMessage(
        const AuthException('student_archived_immutable'),
      ),
      '已归档学生不能通过暂停/恢复改变状态。',
    );
    expect(
      organizationStudentTeachingLifecycleErrorMessage(
        const AuthException('version_conflict'),
      ),
      '这位学生刚刚被别人修改，请刷新后重试。',
    );
  });

  test('parses teacher subject scope history and command results', () {
''',
)

# ---------------------------------------------------------------------------
# Edit dialog becomes identity-only. Lifecycle controls live on the student row.
# ---------------------------------------------------------------------------
Path('lib/features/organization_management/presentation/organization_student_edit_dialog.dart').write_text(r'''import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../cloud/learning_repository.dart';
import '../../../cloud/organization_management_repository.dart';

class OrganizationStudentEditDraft {
  const OrganizationStudentEditDraft({
    required this.operationId,
    required this.studentId,
    required this.expectedStudentVersion,
    required this.name,
    required this.studentCode,
  });

  final String operationId;
  final String studentId;
  final int expectedStudentVersion;
  final String name;
  final String? studentCode;
}

class OrganizationStudentEditDialog extends StatefulWidget {
  const OrganizationStudentEditDialog({
    required this.student,
    required this.onSubmit,
    super.key,
  });

  final OrganizationStudentRecord student;
  final Future<OrganizationStudentUpdateResult> Function(
    OrganizationStudentEditDraft draft,
  )
  onSubmit;

  @override
  State<OrganizationStudentEditDialog> createState() =>
      _OrganizationStudentEditDialogState();
}

class _OrganizationStudentEditDialogState
    extends State<OrganizationStudentEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _studentCodeController;
  final String _operationId = createOperationId();
  bool _busy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.studentName);
    _studentCodeController = TextEditingController(
      text: widget.student.studentCode ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.onSubmit(
        OrganizationStudentEditDraft(
          operationId: _operationId,
          studentId: widget.student.studentId,
          expectedStudentVersion: widget.student.version,
          name: _nameController.text.trim(),
          studentCode: _nullableText(_studentCodeController.text),
        ),
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _describeError(error);
          _busy = false;
        });
      }
    }
  }

  String _describeError(Object error) {
    final message = organizationStudentLifecycleErrorMessage(error);
    if (message != null) return message;
    if (error is AuthException && error.message.trim().isNotEmpty) {
      return '操作未完成：${error.message.trim()}';
    }
    return '保存未完成；表单内容仍保留，可以检查网络后重试。';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('编辑学生'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.58,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '这里只修改姓名和编号。暂停教学、恢复教学与归档属于独立操作，不会在普通编辑中顺带改变。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '学生姓名 *',
                    hintText: '例如：林雨桐',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return '请输入学生姓名。';
                    if (text.length > 120) return '学生姓名不能超过 120 个字符。';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _studentCodeController,
                  maxLength: 80,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '学生编号',
                    hintText: '可选',
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存学生'),
        ),
      ],
    );
  }
}

String? _nullableText(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
''')

# Core error routing.
core = Path('lib/features/organization_management/presentation/organization_management_core.dart')
replace_once(
    core,
    '''    final lifecycleError = organizationStudentLifecycleErrorMessage(error);
''',
    '''    final teachingLifecycleError =
        organizationStudentTeachingLifecycleErrorMessage(error);
    if (teachingLifecycleError != null) return teachingLifecycleError;
    final lifecycleError = organizationStudentLifecycleErrorMessage(error);
''',
)

# Page wiring.
page = Path('lib/features/organization_management/presentation/organization_management_page.dart')
replace_once(
    page,
    '''                        onToggleStudentSubjectService:
                            _toggleStudentSubjectService,
''',
    '''                        onToggleStudentSubjectService:
                            _toggleStudentSubjectService,
                        onToggleStudentTeaching: _toggleStudentTeaching,
''',
)

# Management area callback + student row wiring.
areas = Path('lib/features/organization_management/presentation/organization_management_areas.dart')
replace_once(
    areas,
    '''    required this.onToggleStudentSubjectService,
    required this.onInviteMember,
''',
    '''    required this.onToggleStudentSubjectService,
    required this.onToggleStudentTeaching,
    required this.onInviteMember,
''',
)
replace_once(
    areas,
    '''  onToggleStudentSubjectService;
  final VoidCallback onInviteMember;
''',
    '''  onToggleStudentSubjectService;
  final Future<void> Function(OrganizationStudentRecord student)
  onToggleStudentTeaching;
  final VoidCallback onInviteMember;
''',
)
replace_once(
    areas,
    '''                          onEdit: student.isMerged
                              ? null
                              : () => widget.onEditStudent(student),
''',
    '''                          onToggleTeaching:
                              student.isMerged ||
                                  student.status != 'active' &&
                                      student.status != 'inactive'
                              ? null
                              : () => widget.onToggleStudentTeaching(student),
                          onEdit: student.isMerged
                              ? null
                              : () => widget.onEditStudent(student),
''',
)

# Student row gets an explicit pause/resume control, separate from Edit.
rows = Path('lib/features/organization_management/presentation/organization_management_rows.dart')
replace_once(
    rows,
    '''    required this.onToggleSubjectService,
    required this.onEdit,
''',
    '''    required this.onToggleSubjectService,
    required this.onToggleTeaching,
    required this.onEdit,
''',
)
replace_once(
    rows,
    '''  onToggleSubjectService;
  final VoidCallback? onEdit;
''',
    '''  onToggleSubjectService;
  final VoidCallback? onToggleTeaching;
  final VoidCallback? onEdit;
''',
)
replace_once(
    rows,
    '''          if (onAddSubject != null || onEdit != null) ...[
''',
    '''          if (onAddSubject != null ||
              onToggleTeaching != null ||
              onEdit != null) ...[
''',
)
replace_once(
    rows,
    '''                if (onEdit != null)
                  TextButton.icon(
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('编辑'),
                  ),
''',
    '''                if (onToggleTeaching != null)
                  TextButton.icon(
                    key: ValueKey<String>(
                      'student-teaching-toggle-${student.studentId}',
                    ),
                    onPressed: busy ? null : onToggleTeaching,
                    icon: Icon(
                      student.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 18,
                    ),
                    label: Text(student.isActive ? '暂停教学' : '恢复教学'),
                  ),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('编辑'),
                  ),
''',
)

# Learning actions: explicit root lifecycle plus identity-only edit compatibility.
actions = Path('lib/features/organization_management/presentation/organization_management_learning_actions.dart')
old_edit = '''  Future<void> _editStudent(OrganizationStudentRecord student) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final result = await showDialog<OrganizationStudentUpdateResult>(
        context: context,
        builder: (context) => OrganizationStudentEditDialog(
          student: student,
          onSubmit: (draft) => widget.repository.updateStudent(
            operationId: draft.operationId,
            organizationId: widget.organizationId,
            studentId: draft.studentId,
            expectedStudentVersion: draft.expectedStudentVersion,
            name: draft.name,
            studentCode: draft.studentCode,
            status: draft.status,
          ),
        ),
      );
      if (!mounted || result == null) return;
      await _refresh();
      if (!mounted) return;
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已更新 ${result.studentName} · ${_studentStatusLabel(result.status)}。',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
'''
new_edit = '''  Future<void> _toggleStudentTeaching(OrganizationStudentRecord student) async {
    if (_busy || student.isMerged) return;
    final pausing = student.isActive;
    if (!pausing && student.status != 'inactive') return;

    final confirmed = await _confirm(
      title: pausing ? '暂停 ${student.studentName} 的教学？' : '恢复 ${student.studentName} 的教学？',
      message: pausing
          ? '暂停后，这位学生会暂时从老师工作台和今日事项中隐藏；学科档案、当前任课、Case、证据和待办都会原样保留，恢复后继续原来的教学上下文。'
          : '恢复后，这位学生会重新出现在有当前任课关系的老师工作台中；原学科、Case、证据和待办继续有效，不会重新建档。',
      confirmLabel: pausing ? '确认暂停' : '确认恢复',
    );
    if (!mounted || !confirmed) return;

    await _runMutation(
      () => pausing
          ? widget.repository.pauseStudentTeaching(
              operationId: createOperationId(),
              organizationId: widget.organizationId,
              studentId: student.studentId,
              expectedStudentVersion: student.version,
            )
          : widget.repository.resumeStudentTeaching(
              operationId: createOperationId(),
              organizationId: widget.organizationId,
              studentId: student.studentId,
              expectedStudentVersion: student.version,
            ),
      pausing
          ? '已暂停 ${student.studentName} 的教学；历史和待跟进内容均已保留。'
          : '已恢复 ${student.studentName} 的教学。',
    );
  }

  Future<void> _editStudent(OrganizationStudentRecord student) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final result = await showDialog<OrganizationStudentUpdateResult>(
        context: context,
        builder: (context) => OrganizationStudentEditDialog(
          student: student,
          onSubmit: (draft) => widget.repository.updateStudent(
            operationId: draft.operationId,
            organizationId: widget.organizationId,
            studentId: draft.studentId,
            expectedStudentVersion: draft.expectedStudentVersion,
            name: draft.name,
            studentCode: draft.studentCode,
            status: student.status,
          ),
        ),
      );
      if (!mounted || result == null) return;
      await _refresh();
      if (!mounted) return;
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已更新 ${result.studentName} 的基本信息。')),
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
'''
replace_once(actions, old_edit, new_edit)

# ---------------------------------------------------------------------------
# Widget fake + regression tests.
# ---------------------------------------------------------------------------
widget_test = Path('test/features/organization_management_test.dart')
replace_once(
    widget_test,
    '''  int studentSubjectRestoreCount = 0;
  OrganizationStudentSetupResult? createdStudent;
''',
    '''  int studentSubjectRestoreCount = 0;
  int studentTeachingPauseCount = 0;
  int studentTeachingResumeCount = 0;
  OrganizationStudentSetupResult? createdStudent;
''',
)
replace_once(
    widget_test,
    '''  OrganizationStudentUpdateResult? updatedStudent;
  OrganizationMemberStatusUpdateResult? updatedMember;
''',
    '''  OrganizationStudentUpdateResult? updatedStudent;
  OrganizationStudentTeachingLifecycleResult? updatedStudentTeaching;
  OrganizationMemberStatusUpdateResult? updatedMember;
''',
)
# Add fake root lifecycle before assignment transfer.
replace_once(
    widget_test,
    '''  @override
  Future<OrganizationStudentTeacherAssignmentTransferResult>
  transferStudentTeacherAssignment({
''',
    '''  @override
  Future<OrganizationStudentTeachingLifecycleResult> pauseStudentTeaching({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
  }) async {
    studentTeachingPauseCount++;
    return _setStudentTeachingStatus(
      operationId: operationId,
      organizationId: organizationId,
      studentId: studentId,
      expectedStudentVersion: expectedStudentVersion,
      status: 'inactive',
    );
  }

  @override
  Future<OrganizationStudentTeachingLifecycleResult> resumeStudentTeaching({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
  }) async {
    studentTeachingResumeCount++;
    return _setStudentTeachingStatus(
      operationId: operationId,
      organizationId: organizationId,
      studentId: studentId,
      expectedStudentVersion: expectedStudentVersion,
      status: 'active',
    );
  }

  OrganizationStudentTeachingLifecycleResult _setStudentTeachingStatus({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String status,
  }) {
    final index = students.indexWhere((student) => student.studentId == studentId);
    if (index < 0) throw StateError('Student not found.');
    final previous = students[index];
    final next = OrganizationStudentRecord(
      studentId: previous.studentId,
      studentName: previous.studentName,
      studentCode: previous.studentCode,
      status: status,
      version: expectedStudentVersion + 1,
      grade: previous.grade,
      className: previous.className,
      campus: previous.campus,
      startsOn: previous.startsOn,
      endsOn: previous.endsOn,
      subjectNames: previous.subjectNames,
      subjectServices: previous.subjectServices,
    );
    students[index] = next;
    updatedStudentTeaching = OrganizationStudentTeachingLifecycleResult(
      operationId: operationId,
      organizationId: organizationId,
      studentId: studentId,
      studentName: next.studentName,
      studentCode: next.studentCode,
      status: status,
      version: next.version,
    );
    return updatedStudentTeaching!;
  }

  @override
  Future<OrganizationStudentTeacherAssignmentTransferResult>
  transferStudentTeacherAssignment({
''',
)
# Helper can build inactive fixture when needed.
replace_once(
    widget_test,
    '''OrganizationStudentRecord _studentRecord({
  String id = 'student-1',
  String name = '原学生',
  String code = 'S-001',
}) {
''',
    '''OrganizationStudentRecord _studentRecord({
  String id = 'student-1',
  String name = '原学生',
  String code = 'S-001',
  String status = 'active',
  int version = 3,
}) {
''',
)
replace_once(
    widget_test,
    '''    status: 'active',
    version: 3,
''',
    '''    status: status,
    version: version,
''',
)
# Existing edit test becomes identity-only and asserts status is unchanged.
replace_once(
    widget_test,
    "  testWidgets('admin can edit a student lifecycle record', (tester) async {\n",
    "  testWidgets('admin edits student identity without changing lifecycle', (tester) async {\n",
)
replace_once(
    widget_test,
    '''    expect(find.text('编辑学生'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '更新学生');
''',
    '''    expect(find.text('编辑学生'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('教学可见状态 *'),
      ),
      findsNothing,
    );
    expect(
      find.text('这里只修改姓名和编号。暂停教学、恢复教学与归档属于独立操作，不会在普通编辑中顺带改变。'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField).first, '更新学生');
''',
)
replace_once(
    widget_test,
    '''    expect(repository.updatedStudent?.studentName, '更新学生');
    expect(repository.updatedStudent?.version, 4);
''',
    '''    expect(repository.updatedStudent?.studentName, '更新学生');
    expect(repository.updatedStudent?.status, 'active');
    expect(repository.updatedStudent?.version, 4);
''',
)
# Add explicit pause/resume widget regression before identity edit test.
marker = "  testWidgets('admin edits student identity without changing lifecycle', (tester) async {\n"
pause_widget_test = r'''  testWidgets(
    'manager pauses and resumes teaching without rewriting subject context',
    (tester) async {
      final repository = _FakeOrganizationManagementRepository(
        members: const [],
        invitations: const [],
        students: [_studentRecord()],
        studentTeacherAssignments: [_studentTeacherAssignment()],
      );
      await _pumpManagement(tester, repository);
      await _selectManagementArea(tester, '学生');

      final pause = find.byKey(
        const ValueKey<String>('student-teaching-toggle-student-1'),
      );
      await tester.ensureVisible(pause);
      expect(find.text('暂停教学'), findsOneWidget);
      await tester.tap(pause);
      await tester.pumpAndSettle();
      expect(find.text('暂停 原学生 的教学？'), findsOneWidget);
      expect(
        find.text(
          '暂停后，这位学生会暂时从老师工作台和今日事项中隐藏；学科档案、当前任课、Case、证据和待办都会原样保留，恢复后继续原来的教学上下文。',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, '确认暂停'));
      await tester.pumpAndSettle();

      expect(repository.studentTeachingPauseCount, 1);
      expect(repository.students.single.status, 'inactive');
      expect(repository.students.single.version, 4);
      expect(repository.students.single.subjectServices.single.status, 'active');
      expect(repository.studentTeacherAssignments.single.status, 'active');
      expect(find.text('暂不教学'), findsOneWidget);

      final resume = find.byKey(
        const ValueKey<String>('student-teaching-toggle-student-1'),
      );
      await tester.ensureVisible(resume);
      expect(find.text('恢复教学'), findsOneWidget);
      await tester.tap(resume);
      await tester.pumpAndSettle();
      expect(find.text('恢复 原学生 的教学？'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '确认恢复'));
      await tester.pumpAndSettle();

      expect(repository.studentTeachingResumeCount, 1);
      expect(repository.students.single.status, 'active');
      expect(repository.students.single.version, 5);
      expect(repository.students.single.subjectServices.single.status, 'active');
      expect(repository.studentTeacherAssignments.single.status, 'active');
      expect(find.text('正常教学'), findsOneWidget);
    },
  );

'''
replace_once(widget_test, marker, pause_widget_test + marker)
