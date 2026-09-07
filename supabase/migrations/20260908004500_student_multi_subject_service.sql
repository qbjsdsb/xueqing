-- Add one subject service to an existing student without changing any
-- existing subject profile or teaching relationship.
--
-- The physical model already supports student × subject × teacher relations.
-- This command exposes the missing manager workflow while preserving the
-- existing teaching-scope, role, session, organization and exactly-once gates.

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

create or replace function private.add_organization_student_subject_service(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_id uuid,
  p_organization_subject_id uuid,
  p_teacher_membership_id uuid,
  p_starts_on date
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
  v_business_date date;
  v_starts_on date;
  v_student_name text;
  v_student_status text;
  v_subject_name text;
  v_organization_subject_status text;
  v_subject_status text;
  v_teacher_app_user_id uuid;
  v_teacher_status text;
  v_teacher_display_name text;
  v_scope_id uuid;
  v_profile_id uuid;
  v_assignment_id uuid;
  v_is_claimed boolean;
  v_existing_result jsonb;
  v_command_result jsonb;
begin
  if p_operation_id is null
    or p_organization_id is null
    or p_student_id is null
    or p_organization_subject_id is null
    or p_teacher_membership_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_student_subject_setup_input';
  end if;

  v_app_user_id := (select private.current_app_user_id_v2());
  if v_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select
    organization.id,
    (now() at time zone organization.time_zone)::date
  into
    v_organization_id,
    v_business_date
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

  -- Lock the student root before checking/creating a subject profile. This
  -- serializes concurrent attempts to add the same subject to one student and
  -- lets the existing unique profile invariant remain the final backstop.
  select student.name, student.status
  into v_student_name, v_student_status
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
    'add_organization_student_subject_service',
    'student',
    p_student_id
  );

  if not v_is_claimed then
    return v_existing_result;
  end if;

  if v_student_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'student_not_active';
  end if;

  v_starts_on := coalesce(p_starts_on, v_business_date);

  select
    organization_subject.display_name,
    organization_subject.status,
    subject.status
  into
    v_subject_name,
    v_organization_subject_status,
    v_subject_status
  from public.organization_subjects as organization_subject
  join public.subjects as subject
    on subject.id = organization_subject.subject_id
  where organization_subject.id = p_organization_subject_id
    and organization_subject.organization_id = v_organization_id
  for update of organization_subject;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'organization_subject_not_found';
  end if;

  if v_organization_subject_status <> 'active'
    or v_subject_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'organization_subject_not_active';
  end if;

  select membership.app_user_id, membership.status
  into v_teacher_app_user_id, v_teacher_status
  from public.organization_memberships as membership
  where membership.id = p_teacher_membership_id
    and membership.organization_id = v_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_membership_not_found';
  end if;

  if v_teacher_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_membership_not_active';
  end if;

  if not exists (
    select 1
    from public.app_users as app_user
    where app_user.id = v_teacher_app_user_id
      and app_user.status = 'active'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_app_user_not_active';
  end if;

  if not exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.membership_id = p_teacher_membership_id
      and membership_role.organization_id = v_organization_id
      and membership_role.role = 'teacher'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_role_required';
  end if;

  select coalesce(
    nullif(btrim(app_user.display_name), ''),
    nullif(auth_user.email, ''),
    '未命名老师'
  )
  into v_teacher_display_name
  from public.app_users as app_user
  left join auth.users as auth_user
    on auth_user.id::text = app_user.auth_subject_id
   and app_user.auth_provider = 'supabase'
  where app_user.id = v_teacher_app_user_id;

  select scope.id
  into v_scope_id
  from public.membership_subject_scopes as scope
  where scope.organization_id = v_organization_id
    and scope.membership_id = p_teacher_membership_id
    and scope.organization_subject_id = p_organization_subject_id
    and scope.scope_kind = 'teaching'
    and scope.status = 'active'
    and scope.active_from <= v_starts_on
    and (scope.active_to is null or scope.active_to >= v_starts_on)
  for update;

  if v_scope_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_subject_scope_required';
  end if;

  if exists (
    select 1
    from public.student_subject_profiles as profile
    where profile.organization_id = v_organization_id
      and profile.student_id = p_student_id
      and profile.organization_subject_id = p_organization_subject_id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_profile_already_exists';
  end if;

  v_profile_id := gen_random_uuid();
  v_assignment_id := gen_random_uuid();

  insert into public.student_subject_profiles (
    id,
    organization_id,
    student_id,
    organization_subject_id,
    status
  )
  values (
    v_profile_id,
    v_organization_id,
    p_student_id,
    p_organization_subject_id,
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
  )
  values (
    v_assignment_id,
    v_organization_id,
    v_profile_id,
    p_teacher_membership_id,
    'lead',
    'active',
    v_starts_on
  );

  v_command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', v_organization_id,
    'student_id', p_student_id,
    'student_name', v_student_name,
    'student_subject_profile_id', v_profile_id,
    'organization_subject_id', p_organization_subject_id,
    'subject_name', v_subject_name,
    'teacher_membership_id', p_teacher_membership_id,
    'teacher_display_name', v_teacher_display_name,
    'assignment_id', v_assignment_id,
    'starts_on', v_starts_on
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    v_command_result
  );

  return v_command_result;
end
$function$;

revoke all on function private.add_organization_student_subject_service(
  uuid, uuid, uuid, uuid, uuid, date
) from public, anon, authenticated, service_role;
grant execute on function private.add_organization_student_subject_service(
  uuid, uuid, uuid, uuid, uuid, date
) to service_role, authenticated;

create or replace function public.add_organization_student_subject_service(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_id uuid,
  p_organization_subject_id uuid,
  p_teacher_membership_id uuid,
  p_starts_on date default null
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.add_organization_student_subject_service(
    p_operation_id,
    p_organization_id,
    p_student_id,
    p_organization_subject_id,
    p_teacher_membership_id,
    p_starts_on
  )
$function$;

revoke all on function public.add_organization_student_subject_service(
  uuid, uuid, uuid, uuid, uuid, date
) from public, anon, authenticated, service_role;
grant execute on function public.add_organization_student_subject_service(
  uuid, uuid, uuid, uuid, uuid, date
) to service_role, authenticated;
