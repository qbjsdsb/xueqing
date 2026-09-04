-- Phase 0B.0-N: atomically initialize a student service profile.
--
-- This is a fictional/development migration. It must be reviewed again
-- before any production deployment or real student data is introduced.
--
-- The command deliberately creates only the minimum pilot slice:
-- student root, enrollment, subject profile, selected teacher subject scope,
-- and a lead teaching assignment. Every write is manager-gated and uses the
-- existing operation receipt protocol for exactly-once retries.

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
    'create_organization_student'
  ));

alter table public.operation_receipts
  drop constraint if exists operation_receipts_target_type_check;

alter table public.operation_receipts
  add constraint operation_receipts_target_type_check
  check (target_type in (
    'student_subject_profile',
    'learning_case',
    'case_action',
    'organization'
  ));

-- These tables are written only by guarded SECURITY DEFINER commands. Keep
-- direct client writes unavailable even if a platform default privilege changes.
revoke insert, update, delete, truncate, references, trigger
  on table public.students,
             public.student_enrollments,
             public.student_subject_profiles,
             public.student_teacher_assignments,
             public.membership_subject_scopes
  from public, anon, authenticated;

create or replace function public.list_organization_setup_options(
  p_organization_id uuid
)
returns jsonb
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

  return (
    select jsonb_build_object(
      'subjects',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', organization_subject.id,
              'display_name', organization_subject.display_name
            )
            order by organization_subject.display_name, organization_subject.id
          )
          from public.organization_subjects as organization_subject
          join public.subjects as subject
            on subject.id = organization_subject.subject_id
           and subject.status = 'active'
          where organization_subject.organization_id = p_organization_id
            and organization_subject.status = 'active'
        ),
        '[]'::jsonb
      ),
      'teachers',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'membership_id', membership.id,
              'display_name', coalesce(
                nullif(btrim(app_user.display_name), ''),
                nullif(auth_user.email, ''),
                '未命名老师'
              ),
              'email', coalesce(auth_user.email, '')
            )
            order by coalesce(
              nullif(btrim(app_user.display_name), ''),
              nullif(auth_user.email, ''),
              '未命名老师'
            ), membership.id
          )
          from public.organization_memberships as membership
          join public.app_users as app_user
            on app_user.id = membership.app_user_id
           and app_user.status = 'active'
          left join auth.users as auth_user
            on auth_user.id::text = app_user.auth_subject_id
           and app_user.auth_provider = 'supabase'
          where membership.organization_id = p_organization_id
            and membership.status = 'active'
            and exists (
              select 1
              from public.membership_roles as membership_role
              where membership_role.membership_id = membership.id
                and membership_role.organization_id = membership.organization_id
                and membership_role.role = 'teacher'
            )
        ),
        '[]'::jsonb
      )
    )
  );
end
$function$;

create or replace function public.create_organization_student(
  p_operation_id uuid,
  p_organization_id uuid,
  p_name text,
  p_student_code text,
  p_grade text,
  p_class_name text,
  p_campus text,
  p_organization_subject_id uuid,
  p_teacher_membership_id uuid,
  p_starts_on date,
  p_positioning text,
  p_strengths text,
  p_cadence_note text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
  current_membership_id uuid;
  v_organization_id uuid;
  v_organization_name text;
  organization_time_zone text;
  v_name text;
  v_student_code text;
  v_grade text;
  v_class_name text;
  v_campus text;
  v_positioning text;
  v_strengths text;
  v_cadence_note text;
  v_starts_on date;
  v_subject_id uuid;
  v_subject_name text;
  v_teacher_membership_id uuid;
  v_teacher_display_name text;
  v_teacher_app_user_id uuid;
  v_scope_id uuid;
  student_id uuid;
  enrollment_id uuid;
  profile_id uuid;
  assignment_id uuid;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
begin
  v_name := btrim(coalesce(p_name, ''));
  v_student_code := nullif(btrim(coalesce(p_student_code, '')), '');
  v_grade := nullif(btrim(coalesce(p_grade, '')), '');
  v_class_name := nullif(btrim(coalesce(p_class_name, '')), '');
  v_campus := nullif(btrim(coalesce(p_campus, '')), '');
  v_positioning := nullif(btrim(coalesce(p_positioning, '')), '');
  v_strengths := nullif(btrim(coalesce(p_strengths, '')), '');
  v_cadence_note := nullif(btrim(coalesce(p_cadence_note, '')), '');

  if p_operation_id is null
    or p_organization_id is null
    or p_organization_subject_id is null
    or p_teacher_membership_id is null
    or char_length(v_name) = 0
    or char_length(v_name) > 120
    or (v_student_code is not null and char_length(v_student_code) > 80)
    or (v_grade is not null and char_length(v_grade) > 120)
    or (v_class_name is not null and char_length(v_class_name) > 120)
    or (v_campus is not null and char_length(v_campus) > 120)
    or (v_positioning is not null and char_length(v_positioning) > 2000)
    or (v_strengths is not null and char_length(v_strengths) > 2000)
    or (v_cadence_note is not null and char_length(v_cadence_note) > 160) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_student_setup_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select organization.id, organization.name, organization.time_zone
  into v_organization_id, v_organization_name, organization_time_zone
  from public.organizations as organization
  where organization.id = p_organization_id
    and organization.status = 'active'
  for update;

  if v_organization_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'organization_not_found';
  end if;

  current_membership_id := (
    select private.current_membership_for_organization_v2(v_organization_id)
  );
  if current_membership_id is null
    or not (select private.can_manage_organization_v2(v_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  select organization_subject.id, organization_subject.display_name
  into v_subject_id, v_subject_name
  from public.organization_subjects as organization_subject
  join public.subjects as subject
    on subject.id = organization_subject.subject_id
   and subject.status = 'active'
  where organization_subject.id = p_organization_subject_id
    and organization_subject.organization_id = v_organization_id
    and organization_subject.status = 'active'
  for update of organization_subject;

  if v_subject_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'organization_subject_not_found';
  end if;

  select membership.id, membership.app_user_id
  into v_teacher_membership_id, v_teacher_app_user_id
  from public.organization_memberships as membership
  where membership.id = p_teacher_membership_id
    and membership.organization_id = v_organization_id
    and membership.status = 'active'
  for update;

  if v_teacher_membership_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_membership_not_found';
  end if;

  if not exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.membership_id = v_teacher_membership_id
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

  v_starts_on := coalesce(
    p_starts_on,
    (now() at time zone organization_time_zone)::date
  );

  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'create_organization_student',
    'organization',
    v_organization_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  student_id := gen_random_uuid();
  enrollment_id := gen_random_uuid();
  profile_id := gen_random_uuid();
  assignment_id := gen_random_uuid();

  insert into public.students (
    id,
    organization_id,
    name,
    student_code,
    status
  )
  values (
    student_id,
    v_organization_id,
    v_name,
    v_student_code,
    'active'
  );

  insert into public.student_enrollments (
    id,
    organization_id,
    student_id,
    grade,
    class_name,
    campus,
    starts_on
  )
  values (
    enrollment_id,
    v_organization_id,
    student_id,
    v_grade,
    v_class_name,
    v_campus,
    v_starts_on
  );

  insert into public.student_subject_profiles (
    id,
    organization_id,
    student_id,
    organization_subject_id,
    status,
    positioning,
    strengths,
    cadence_note
  )
  values (
    profile_id,
    v_organization_id,
    student_id,
    v_subject_id,
    'active',
    v_positioning,
    v_strengths,
    v_cadence_note
  );

  select scope.id
  into v_scope_id
  from public.membership_subject_scopes as scope
  where scope.organization_id = v_organization_id
    and scope.membership_id = v_teacher_membership_id
    and scope.organization_subject_id = v_subject_id
    and scope.scope_kind = 'teaching'
    and scope.status = 'active'
  for update;

  if v_scope_id is null then
    v_scope_id := gen_random_uuid();
    insert into public.membership_subject_scopes (
      id,
      organization_id,
      membership_id,
      organization_subject_id,
      scope_kind,
      status,
      active_from
    )
    values (
      v_scope_id,
      v_organization_id,
      v_teacher_membership_id,
      v_subject_id,
      'teaching',
      'active',
      v_starts_on
    );
  else
    update public.membership_subject_scopes
    set active_from = least(active_from, v_starts_on),
        active_to = case
          when active_to is null or active_to >= v_starts_on then active_to
          else null
        end
    where id = v_scope_id;
  end if;

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
    assignment_id,
    v_organization_id,
    profile_id,
    v_teacher_membership_id,
    'lead',
    'active',
    v_starts_on
  );

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', v_organization_id,
    'organization_name', v_organization_name,
    'student_id', student_id,
    'student_name', v_name,
    'enrollment_id', enrollment_id,
    'student_subject_profile_id', profile_id,
    'organization_subject_id', v_subject_id,
    'subject_name', v_subject_name,
    'teacher_membership_id', v_teacher_membership_id,
    'teacher_display_name', v_teacher_display_name,
    'assignment_id', assignment_id,
    'starts_on', v_starts_on
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

revoke all on function public.list_organization_setup_options(uuid) from public;
grant execute on function public.list_organization_setup_options(uuid) to authenticated;
revoke execute on function public.list_organization_setup_options(uuid) from anon;

revoke all on function public.create_organization_student(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  uuid,
  uuid,
  date,
  text,
  text,
  text
) from public;
grant execute on function public.create_organization_student(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  uuid,
  uuid,
  date,
  text,
  text,
  text
) to authenticated;
revoke execute on function public.create_organization_student(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  uuid,
  uuid,
  date,
  text,
  text,
  text
) from anon;
