-- Separate temporary whole-student teaching pause/resume from ordinary edits.
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
