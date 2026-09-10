-- v0.3.2: allow managers to correct the student profile shown in the roster
-- without coupling that edit to teaching lifecycle transitions.
--
-- The student root version is the optimistic concurrency token for this small
-- aggregate. The selected enrollment follows the same effective/latest rule as
-- list_organization_students, so the row a manager sees is the row being fixed.

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
    'record_case_progress'
  ));

create or replace function private.update_organization_student_profile(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_id uuid,
  p_expected_student_version integer,
  p_name text,
  p_student_code text,
  p_grade text,
  p_class_name text,
  p_campus text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
  v_organization_id uuid;
  v_business_date date;
  v_name text;
  v_student_code text;
  v_grade text;
  v_class_name text;
  v_campus text;
  current_status text;
  current_version integer;
  v_enrollment_id uuid;
  v_enrollment_grade text;
  v_enrollment_class_name text;
  v_enrollment_campus text;
  v_enrollment_starts_on date;
  v_enrollment_ends_on date;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
begin
  v_name := btrim(coalesce(p_name, ''));
  v_student_code := nullif(btrim(coalesce(p_student_code, '')), '');
  v_grade := nullif(btrim(coalesce(p_grade, '')), '');
  v_class_name := nullif(btrim(coalesce(p_class_name, '')), '');
  v_campus := nullif(btrim(coalesce(p_campus, '')), '');

  if p_operation_id is null
    or p_organization_id is null
    or p_student_id is null
    or p_expected_student_version is null
    or p_expected_student_version <= 0
    or char_length(v_name) = 0
    or char_length(v_name) > 120
    or (v_student_code is not null and char_length(v_student_code) > 80)
    or v_grade is null
    or char_length(v_grade) > 120
    or (v_class_name is not null and char_length(v_class_name) > 120)
    or (v_campus is not null and char_length(v_campus) > 120) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_student_profile_update_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
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

  select
    student.status,
    student.version
  into
    current_status,
    current_version
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
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'update_organization_student_profile',
    'student',
    p_student_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  if current_status = 'merged' then
    raise exception using
      errcode = 'P0001',
      message = 'student_merged_immutable';
  end if;

  if current_version <> p_expected_student_version then
    raise exception using
      errcode = 'P0001',
      message = 'version_conflict';
  end if;

  select
    enrollment.id,
    enrollment.grade,
    enrollment.class_name,
    enrollment.campus,
    enrollment.starts_on,
    enrollment.ends_on
  into
    v_enrollment_id,
    v_enrollment_grade,
    v_enrollment_class_name,
    v_enrollment_campus,
    v_enrollment_starts_on,
    v_enrollment_ends_on
  from public.student_enrollments as enrollment
  where enrollment.organization_id = v_organization_id
    and enrollment.student_id = p_student_id
  order by
    case
      when enrollment.starts_on <= v_business_date
        and (enrollment.ends_on is null or enrollment.ends_on >= v_business_date)
        then 0
      else 1
    end,
    enrollment.starts_on desc,
    enrollment.id desc
  limit 1
  for update;

  if v_enrollment_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'student_enrollment_not_found';
  end if;

  update public.students
  set name = v_name,
      student_code = v_student_code,
      version = version + 1,
      updated_at = timezone('utc', now())
  where id = p_student_id
    and organization_id = v_organization_id;

  if v_enrollment_grade is distinct from v_grade
    or v_enrollment_class_name is distinct from v_class_name
    or v_enrollment_campus is distinct from v_campus then
    -- Same-day/future rows are still editable planning/correction rows. Once a
    -- row represents a prior business day, preserve it and append a new slice.
    if v_enrollment_starts_on >= v_business_date then
      update public.student_enrollments
      set grade = v_grade,
          class_name = v_class_name,
          campus = v_campus
      where id = v_enrollment_id
        and organization_id = v_organization_id
        and student_id = p_student_id;
    else
      if v_enrollment_ends_on is null or v_enrollment_ends_on >= v_business_date then
        update public.student_enrollments
        set ends_on = v_business_date - 1
        where id = v_enrollment_id
          and organization_id = v_organization_id
          and student_id = p_student_id;
      end if;

      insert into public.student_enrollments (
        organization_id,
        student_id,
        grade,
        class_name,
        campus,
        starts_on,
        ends_on
      ) values (
        v_organization_id,
        p_student_id,
        v_grade,
        v_class_name,
        v_campus,
        v_business_date,
        case
          when v_enrollment_ends_on is not null
            and v_enrollment_ends_on >= v_business_date
            then v_enrollment_ends_on
          else null
        end
      );
    end if;
  end if;

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', v_organization_id,
    'student_id', p_student_id,
    'student_name', v_name,
    'student_code', v_student_code,
    'grade', v_grade,
    'class_name', v_class_name,
    'campus', v_campus,
    'status', current_status,
    'version', current_version + 1
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

revoke all on function private.update_organization_student_profile(
  uuid, uuid, uuid, integer, text, text, text, text, text
) from public, anon, authenticated, service_role;
grant execute on function private.update_organization_student_profile(
  uuid, uuid, uuid, integer, text, text, text, text, text
) to authenticated, service_role;

create or replace function public.update_organization_student_profile(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_id uuid,
  p_expected_student_version integer,
  p_name text,
  p_student_code text,
  p_grade text,
  p_class_name text,
  p_campus text
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.update_organization_student_profile(
    p_operation_id,
    p_organization_id,
    p_student_id,
    p_expected_student_version,
    p_name,
    p_student_code,
    p_grade,
    p_class_name,
    p_campus
  )
$function$;

revoke all on function public.update_organization_student_profile(
  uuid, uuid, uuid, integer, text, text, text, text, text
) from public, anon, authenticated, service_role;
grant execute on function public.update_organization_student_profile(
  uuid, uuid, uuid, integer, text, text, text, text, text
) to authenticated, service_role;

comment on function public.update_organization_student_profile(
  uuid, uuid, uuid, integer, text, text, text, text, text
) is 'Corrects student identity and the roster-visible enrollment context atomically without changing teaching lifecycle.';
