-- Complete the per-subject lifecycle for an existing student.
--
-- Ending a subject service preserves the student root, subject profile, closed
-- Learning Cases, evidence and assignment history. It refuses to hide a
-- subject while unresolved Cases or pending Actions still need ownership.
-- Restoring reuses the same subject profile and creates a new lead assignment
-- for a currently eligible teacher instead of creating a duplicate profile.

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

create or replace function private.list_organization_students(
  p_organization_id uuid
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
begin
  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  if p_organization_id is null
    or not (select private.can_manage_organization_v2(p_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  return query
  select jsonb_build_object(
    'student_id', student.id,
    'student_name', student.name,
    'student_code', student.student_code,
    'status', student.status,
    'version', student.version,
    'grade', enrollment.grade,
    'class_name', enrollment.class_name,
    'campus', enrollment.campus,
    'starts_on', enrollment.starts_on,
    'ends_on', enrollment.ends_on,
    'subjects', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'student_subject_profile_id', profile.id,
            'organization_subject_id', organization_subject.id,
            'display_name', organization_subject.display_name,
            'status', profile.status,
            'version', profile.version
          )
          order by
            case profile.status
              when 'active' then 0
              when 'inactive' then 1
              else 2
            end,
            organization_subject.display_name,
            profile.id
        )
        from public.student_subject_profiles as profile
        join public.organization_subjects as organization_subject
          on organization_subject.id = profile.organization_subject_id
         and organization_subject.organization_id = profile.organization_id
        where profile.organization_id = student.organization_id
          and profile.student_id = student.id
      ),
      '[]'::jsonb
    )
  )
  from public.students as student
  join public.organizations as organization
    on organization.id = student.organization_id
   and organization.status = 'active'
  left join lateral (
    select
      candidate.grade,
      candidate.class_name,
      candidate.campus,
      candidate.starts_on,
      candidate.ends_on
    from public.student_enrollments as candidate
    where candidate.organization_id = student.organization_id
      and candidate.student_id = student.id
    order by
      case
        when candidate.starts_on <=
            (now() at time zone organization.time_zone)::date
          and (
            candidate.ends_on is null
            or candidate.ends_on >=
              (now() at time zone organization.time_zone)::date
          ) then 0
        else 1
      end,
      candidate.starts_on desc,
      candidate.id desc
    limit 1
  ) as enrollment on true
  where student.organization_id = p_organization_id
  order by student.name, student.id;
end
$function$;

create or replace function private.end_organization_student_subject_service(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_subject_profile_id uuid,
  p_expected_profile_version integer
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
  v_student_id uuid;
  v_student_name text;
  v_subject_id uuid;
  v_subject_name text;
  v_profile_status text;
  v_profile_version integer;
  v_ended_assignment_count integer;
  v_is_claimed boolean;
  v_existing_result jsonb;
  v_command_result jsonb;
begin
  if p_operation_id is null
    or p_organization_id is null
    or p_student_subject_profile_id is null
    or p_expected_profile_version is null
    or p_expected_profile_version <= 0 then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_student_subject_lifecycle_input';
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
  into v_organization_id, v_business_date
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

  select
    profile.student_id,
    student.name,
    profile.organization_subject_id,
    organization_subject.display_name,
    profile.status,
    profile.version
  into
    v_student_id,
    v_student_name,
    v_subject_id,
    v_subject_name,
    v_profile_status,
    v_profile_version
  from public.student_subject_profiles as profile
  join public.students as student
    on student.id = profile.student_id
   and student.organization_id = profile.organization_id
  join public.organization_subjects as organization_subject
    on organization_subject.id = profile.organization_subject_id
   and organization_subject.organization_id = profile.organization_id
  where profile.id = p_student_subject_profile_id
    and profile.organization_id = v_organization_id
  for update of profile;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_profile_not_found';
  end if;

  select claimed, result
  into v_is_claimed, v_existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'end_organization_student_subject_service',
    'student_subject_profile',
    p_student_subject_profile_id
  );

  if not v_is_claimed then
    return v_existing_result;
  end if;

  if v_profile_version <> p_expected_profile_version then
    raise exception using
      errcode = 'P0001',
      message = 'version_conflict';
  end if;

  if v_profile_status = 'archived' then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_profile_archived';
  end if;

  if v_profile_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_service_not_active';
  end if;

  if exists (
    select 1
    from public.case_actions as action
    join public.learning_cases as learning_case
      on learning_case.id = action.learning_case_id
     and learning_case.organization_id = action.organization_id
    where learning_case.organization_id = v_organization_id
      and learning_case.student_subject_profile_id = p_student_subject_profile_id
      and action.status = 'pending'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_pending_actions';
  end if;

  if exists (
    select 1
    from public.learning_cases as learning_case
    where learning_case.organization_id = v_organization_id
      and learning_case.student_subject_profile_id = p_student_subject_profile_id
      and learning_case.status <> 'closed'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_open_cases';
  end if;

  update public.student_teacher_assignments as assignment
  set status = 'ended',
      active_to = greatest(assignment.active_from, v_business_date),
      ended_at = timezone('utc', now())
  where assignment.organization_id = v_organization_id
    and assignment.student_subject_profile_id = p_student_subject_profile_id
    and assignment.status = 'active';

  get diagnostics v_ended_assignment_count = row_count;

  update public.student_subject_profiles
  set status = 'inactive',
      version = version + 1,
      updated_at = timezone('utc', now())
  where id = p_student_subject_profile_id
    and organization_id = v_organization_id;

  v_command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', v_organization_id,
    'student_id', v_student_id,
    'student_name', v_student_name,
    'student_subject_profile_id', p_student_subject_profile_id,
    'organization_subject_id', v_subject_id,
    'subject_name', v_subject_name,
    'status', 'inactive',
    'profile_version', v_profile_version + 1,
    'ended_assignment_count', v_ended_assignment_count
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    v_command_result
  );

  return v_command_result;
end
$function$;

revoke all on function private.end_organization_student_subject_service(
  uuid, uuid, uuid, integer
) from public, anon, authenticated, service_role;
grant execute on function private.end_organization_student_subject_service(
  uuid, uuid, uuid, integer
) to service_role, authenticated;

create or replace function public.end_organization_student_subject_service(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_subject_profile_id uuid,
  p_expected_profile_version integer
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.end_organization_student_subject_service(
    p_operation_id,
    p_organization_id,
    p_student_subject_profile_id,
    p_expected_profile_version
  )
$function$;

revoke all on function public.end_organization_student_subject_service(
  uuid, uuid, uuid, integer
) from public, anon, authenticated, service_role;
grant execute on function public.end_organization_student_subject_service(
  uuid, uuid, uuid, integer
) to service_role, authenticated;

create or replace function private.restore_organization_student_subject_service(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_subject_profile_id uuid,
  p_expected_profile_version integer,
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
  v_student_id uuid;
  v_student_name text;
  v_student_status text;
  v_subject_id uuid;
  v_subject_name text;
  v_organization_subject_status text;
  v_global_subject_status text;
  v_profile_status text;
  v_profile_version integer;
  v_teacher_app_user_id uuid;
  v_teacher_membership_status text;
  v_teacher_display_name text;
  v_scope_id uuid;
  v_assignment_id uuid;
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
      message = 'invalid_student_subject_lifecycle_input';
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
  into v_organization_id, v_business_date
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

  select
    profile.student_id,
    student.name,
    student.status,
    profile.organization_subject_id,
    organization_subject.display_name,
    organization_subject.status,
    subject.status,
    profile.status,
    profile.version
  into
    v_student_id,
    v_student_name,
    v_student_status,
    v_subject_id,
    v_subject_name,
    v_organization_subject_status,
    v_global_subject_status,
    v_profile_status,
    v_profile_version
  from public.student_subject_profiles as profile
  join public.students as student
    on student.id = profile.student_id
   and student.organization_id = profile.organization_id
  join public.organization_subjects as organization_subject
    on organization_subject.id = profile.organization_subject_id
   and organization_subject.organization_id = profile.organization_id
  join public.subjects as subject
    on subject.id = organization_subject.subject_id
  where profile.id = p_student_subject_profile_id
    and profile.organization_id = v_organization_id
  for update of profile;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_profile_not_found';
  end if;

  select claimed, result
  into v_is_claimed, v_existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'restore_organization_student_subject_service',
    'student_subject_profile',
    p_student_subject_profile_id
  );

  if not v_is_claimed then
    return v_existing_result;
  end if;

  if v_profile_version <> p_expected_profile_version then
    raise exception using
      errcode = 'P0001',
      message = 'version_conflict';
  end if;

  if v_profile_status = 'archived' then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_profile_archived';
  end if;

  if v_profile_status <> 'inactive' then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_service_not_inactive';
  end if;

  if v_student_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'student_not_active';
  end if;

  if v_organization_subject_status <> 'active'
    or v_global_subject_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'organization_subject_not_active';
  end if;

  if exists (
    select 1
    from public.student_teacher_assignments as assignment
    where assignment.organization_id = v_organization_id
      and assignment.student_subject_profile_id = p_student_subject_profile_id
      and assignment.status = 'active'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_active_assignment_exists';
  end if;

  v_starts_on := coalesce(p_starts_on, v_business_date);

  select membership.app_user_id, membership.status
  into v_teacher_app_user_id, v_teacher_membership_status
  from public.organization_memberships as membership
  where membership.id = p_teacher_membership_id
    and membership.organization_id = v_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_membership_not_found';
  end if;

  if v_teacher_membership_status <> 'active' then
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

  select scope.id
  into v_scope_id
  from public.membership_subject_scopes as scope
  where scope.organization_id = v_organization_id
    and scope.membership_id = p_teacher_membership_id
    and scope.organization_subject_id = v_subject_id
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

  update public.student_subject_profiles
  set status = 'active',
      version = version + 1,
      updated_at = timezone('utc', now())
  where id = p_student_subject_profile_id
    and organization_id = v_organization_id;

  v_assignment_id := gen_random_uuid();
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
    p_student_subject_profile_id,
    p_teacher_membership_id,
    'lead',
    'active',
    v_starts_on
  );

  v_command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', v_organization_id,
    'student_id', v_student_id,
    'student_name', v_student_name,
    'student_subject_profile_id', p_student_subject_profile_id,
    'organization_subject_id', v_subject_id,
    'subject_name', v_subject_name,
    'status', 'active',
    'profile_version', v_profile_version + 1,
    'assignment_id', v_assignment_id,
    'teacher_membership_id', p_teacher_membership_id,
    'teacher_display_name', v_teacher_display_name,
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

revoke all on function private.restore_organization_student_subject_service(
  uuid, uuid, uuid, integer, uuid, date
) from public, anon, authenticated, service_role;
grant execute on function private.restore_organization_student_subject_service(
  uuid, uuid, uuid, integer, uuid, date
) to service_role, authenticated;

create or replace function public.restore_organization_student_subject_service(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_subject_profile_id uuid,
  p_expected_profile_version integer,
  p_teacher_membership_id uuid,
  p_starts_on date default null
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.restore_organization_student_subject_service(
    p_operation_id,
    p_organization_id,
    p_student_subject_profile_id,
    p_expected_profile_version,
    p_teacher_membership_id,
    p_starts_on
  )
$function$;

revoke all on function public.restore_organization_student_subject_service(
  uuid, uuid, uuid, integer, uuid, date
) from public, anon, authenticated, service_role;
grant execute on function public.restore_organization_student_subject_service(
  uuid, uuid, uuid, integer, uuid, date
) to service_role, authenticated;
