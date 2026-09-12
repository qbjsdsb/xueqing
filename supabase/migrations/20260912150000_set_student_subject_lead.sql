-- v0.3.8: repair an active student-subject service that has no Lead.
--
-- This is deliberately different from teaching handoff:
--   * handoff moves current responsibility from an existing Lead to another;
--   * this command establishes a Lead only when there is no active Lead.
--
-- It never rewrites existing Learning Case ownership, Action assignees, or
-- historical events. Those facts need an explicit responsibility operation of
-- their own instead of a hidden side effect.

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
    'update_organization_student_profile',
    'transfer_organization_student_teacher_assignment',
    'set_organization_student_subject_lead',
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
    'reopen_case',
    'end_case_follow_up',
    'record_case_progress',
    'void_learning_case',
    'restore_learning_case'
  ));

create or replace function private.set_organization_student_subject_lead_v2(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_subject_profile_id uuid,
  p_expected_profile_version integer,
  p_teacher_membership_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_app_user_id uuid;
  v_business_date date;
  v_profile public.student_subject_profiles%rowtype;
  v_student public.students%rowtype;
  v_teacher_membership public.organization_memberships%rowtype;
  v_teacher_scope_id uuid;
  v_student_name text;
  v_subject_name text;
  v_subject_code text;
  v_teacher_name text;
  v_teacher_email text;
  v_assignment_id uuid;
  v_assignment_version integer;
  v_is_claimed boolean;
  v_existing_result jsonb;
  v_command_result jsonb;
begin
  if p_operation_id is null
    or p_organization_id is null
    or p_student_subject_profile_id is null
    or p_expected_profile_version is null
    or p_expected_profile_version <= 0
    or p_teacher_membership_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_student_subject_lead_assignment_input';
  end if;

  v_app_user_id := (select private.current_app_user_id_v2());
  if v_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select (now() at time zone organization.time_zone)::date
  into v_business_date
  from public.organizations as organization
  where organization.id = p_organization_id
    and organization.status = 'active'
  for update;

  if v_business_date is null then
    raise exception using
      errcode = 'P0001',
      message = 'organization_not_found';
  end if;

  if not (select private.can_manage_organization_v2(p_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  select profile.*
  into v_profile
  from public.student_subject_profiles as profile
  where profile.id = p_student_subject_profile_id
    and profile.organization_id = p_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_profile_not_found';
  end if;

  if v_profile.version <> p_expected_profile_version then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_profile_version_conflict';
  end if;

  if v_profile.status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_profile_not_active';
  end if;

  select claimed, result
  into v_is_claimed, v_existing_result
  from private.claim_case_operation_v2(
    p_organization_id,
    p_operation_id,
    'set_organization_student_subject_lead',
    'student_subject_profile',
    p_student_subject_profile_id
  );

  if not v_is_claimed then
    if nullif(v_existing_result->>'teacher_membership_id', '')::uuid
      is distinct from p_teacher_membership_id then
      raise exception using
        errcode = 'P0001',
        message = 'operation_id_reuse_conflict';
    end if;
    return v_existing_result;
  end if;

  select student.*
  into v_student
  from public.students as student
  where student.id = v_profile.student_id
    and student.organization_id = p_organization_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'student_not_found';
  end if;

  if v_student.status <> 'active' then
    raise exception using errcode = 'P0001', message = 'student_not_active';
  end if;

  select
    coalesce(nullif(btrim(organization_subject.display_name), ''), subject.name),
    subject.code
  into v_subject_name, v_subject_code
  from public.organization_subjects as organization_subject
  join public.subjects as subject
    on subject.id = organization_subject.subject_id
   and subject.status = 'active'
  where organization_subject.id = v_profile.organization_subject_id
    and organization_subject.organization_id = p_organization_id
    and organization_subject.status = 'active'
  for share of organization_subject, subject;

  if v_subject_name is null then
    raise exception using
      errcode = 'P0001',
      message = 'organization_subject_not_active';
  end if;

  -- Lock any active Lead row before deciding that responsibility is missing.
  perform 1
  from public.student_teacher_assignments as assignment
  where assignment.organization_id = p_organization_id
    and assignment.student_subject_profile_id = p_student_subject_profile_id
    and assignment.assignment_role = 'lead'
    and assignment.status = 'active'
  for update;

  if found then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_lead_already_assigned';
  end if;

  select membership.*
  into v_teacher_membership
  from public.organization_memberships as membership
  where membership.id = p_teacher_membership_id
    and membership.organization_id = p_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_membership_not_found';
  end if;

  if v_teacher_membership.status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_membership_not_active';
  end if;

  if not exists (
    select 1
    from public.app_users as app_user
    where app_user.id = v_teacher_membership.app_user_id
      and app_user.status = 'active'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_app_user_not_active';
  end if;

  if not exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.organization_id = p_organization_id
      and membership_role.membership_id = p_teacher_membership_id
      and membership_role.role = 'teacher'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_role_required';
  end if;

  select scope.id
  into v_teacher_scope_id
  from public.membership_subject_scopes as scope
  where scope.organization_id = p_organization_id
    and scope.membership_id = p_teacher_membership_id
    and scope.organization_subject_id = v_profile.organization_subject_id
    and scope.scope_kind = 'teaching'
    and scope.status = 'active'
    and scope.active_from <= v_business_date
    and (scope.active_to is null or scope.active_to >= v_business_date)
  order by scope.id
  limit 1
  for share;

  if v_teacher_scope_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_subject_scope_required';
  end if;

  select
    coalesce(nullif(btrim(app_user.display_name), ''), '未命名老师'),
    coalesce(nullif(btrim(auth_user.email::text), ''), '')
  into v_teacher_name, v_teacher_email
  from public.app_users as app_user
  left join auth.users as auth_user
    on auth_user.id::text = app_user.auth_subject_id
  where app_user.id = v_teacher_membership.app_user_id;

  v_student_name := coalesce(nullif(btrim(v_student.name), ''), '未命名学生');

  insert into public.student_teacher_assignments (
    organization_id,
    student_subject_profile_id,
    membership_id,
    assignment_role,
    status,
    active_from
  )
  values (
    p_organization_id,
    p_student_subject_profile_id,
    p_teacher_membership_id,
    'lead',
    'active',
    v_business_date
  )
  returning id, version
  into v_assignment_id, v_assignment_version;

  v_command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', p_organization_id,
    'student_id', v_student.id,
    'student_name', v_student_name,
    'student_subject_profile_id', p_student_subject_profile_id,
    'organization_subject_id', v_profile.organization_subject_id,
    'subject_name', v_subject_name,
    'subject_code', v_subject_code,
    'assignment_id', v_assignment_id,
    'assignment_role', 'lead',
    'assignment_status', 'active',
    'assignment_version', v_assignment_version,
    'teacher_membership_id', p_teacher_membership_id,
    'teacher_display_name', v_teacher_name,
    'teacher_email', v_teacher_email,
    'teacher_scope_id', v_teacher_scope_id,
    'active_from', v_business_date
  );

  perform private.finish_case_operation_v2(
    p_organization_id,
    p_operation_id,
    v_command_result
  );

  return v_command_result;
exception
  when unique_violation then
    if exists (
      select 1
      from public.student_teacher_assignments as assignment
      where assignment.organization_id = p_organization_id
        and assignment.student_subject_profile_id = p_student_subject_profile_id
        and assignment.assignment_role = 'lead'
        and assignment.status = 'active'
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'student_subject_lead_already_assigned';
    end if;
    raise;
end
$function$;

revoke all on function private.set_organization_student_subject_lead_v2(
  uuid, uuid, uuid, integer, uuid
) from public, anon, authenticated, service_role;
grant execute on function private.set_organization_student_subject_lead_v2(
  uuid, uuid, uuid, integer, uuid
) to authenticated, service_role;

create or replace function public.set_organization_student_subject_lead(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_subject_profile_id uuid,
  p_expected_profile_version integer,
  p_teacher_membership_id uuid
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.set_organization_student_subject_lead_v2(
    p_operation_id,
    p_organization_id,
    p_student_subject_profile_id,
    p_expected_profile_version,
    p_teacher_membership_id
  )
$function$;

revoke all on function public.set_organization_student_subject_lead(
  uuid, uuid, uuid, integer, uuid
) from public, anon, authenticated, service_role;
grant execute on function public.set_organization_student_subject_lead(
  uuid, uuid, uuid, integer, uuid
) to authenticated, service_role;

comment on function public.set_organization_student_subject_lead(
  uuid, uuid, uuid, integer, uuid
) is
  'Establishes the missing active Lead for an active student-subject service. It never transfers or rewrites existing Case/Action responsibility.';
