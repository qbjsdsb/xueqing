-- Phase 0B.0-Q: provide a manager-only student roster and a versioned
-- lifecycle command for correcting identity fields or changing visibility.
-- Archive/inactivation keeps all historical Case data; the active-student
-- read boundary from Phase 0B.0-P hides it from teaching reads.
-- This is a fictional/local compatibility migration. It is not a
-- production migration or permission to import real student data.

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
    'create_organization_student',
    'create_organization_subject',
    'update_organization_student'
  ));

alter table public.operation_receipts
  drop constraint if exists operation_receipts_target_type_check;

alter table public.operation_receipts
  add constraint operation_receipts_target_type_check
  check (target_type in (
    'student_subject_profile',
    'learning_case',
    'case_action',
    'organization',
    'student'
  ));

create or replace function public.list_organization_students(
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
            'id', organization_subject.id,
            'display_name', organization_subject.display_name
          )
          order by organization_subject.display_name, organization_subject.id
        )
        from public.student_subject_profiles as profile
        join public.organization_subjects as organization_subject
          on organization_subject.id = profile.organization_subject_id
         and organization_subject.organization_id = profile.organization_id
        where profile.organization_id = student.organization_id
          and profile.student_id = student.id
          and profile.status = 'active'
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

create or replace function public.update_organization_student(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_id uuid,
  p_expected_student_version integer,
  p_name text,
  p_student_code text,
  p_status text
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
  v_name text;
  v_student_code text;
  v_status text;
  current_status text;
  current_version integer;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
begin
  v_name := btrim(coalesce(p_name, ''));
  v_student_code := nullif(btrim(coalesce(p_student_code, '')), '');
  v_status := nullif(btrim(coalesce(p_status, '')), '');

  if p_operation_id is null
    or p_organization_id is null
    or p_student_id is null
    or p_expected_student_version is null
    or p_expected_student_version <= 0
    or char_length(v_name) = 0
    or char_length(v_name) > 120
    or (v_student_code is not null and char_length(v_student_code) > 80)
    or v_status is null
    or v_status not in ('active', 'inactive', 'archived') then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_student_update_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
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
    'update_organization_student',
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

  update public.students
  set name = v_name,
      student_code = v_student_code,
      status = v_status,
      version = version + 1,
      updated_at = timezone('utc', now()),
      archived_at = case
        when v_status = 'archived' then coalesce(
          archived_at,
          timezone('utc', now())
        )
        else null
      end
  where id = p_student_id
    and organization_id = v_organization_id;

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', v_organization_id,
    'student_id', p_student_id,
    'student_name', v_name,
    'student_code', v_student_code,
    'status', v_status,
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

revoke all on function public.list_organization_students(uuid)
  from public;
grant execute on function public.list_organization_students(uuid)
  to authenticated;
revoke execute on function public.list_organization_students(uuid)
  from anon;

revoke all on function public.update_organization_student(
  uuid,
  uuid,
  uuid,
  integer,
  text,
  text,
  text
) from public;
grant execute on function public.update_organization_student(
  uuid,
  uuid,
  uuid,
  integer,
  text,
  text,
  text
) to authenticated;
revoke execute on function public.update_organization_student(
  uuid,
  uuid,
  uuid,
  integer,
  text,
  text,
  text
) from anon;
