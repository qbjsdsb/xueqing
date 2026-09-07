from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    assert count == 1, f"{path}: expected 1 match, found {count}"
    path.write_text(text.replace(old, new, 1))


def insert_before(path: Path, marker: str, addition: str) -> None:
    text = path.read_text()
    count = text.count(marker)
    assert count == 1, f"{path}: expected 1 marker, found {count}"
    path.write_text(text.replace(marker, addition + marker, 1))


migration = Path("supabase/migrations/20260908013000_student_subject_lifecycle.sql")
migration.write_text(r'''-- Complete the per-subject lifecycle for an existing student.
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
''')

sql_test = Path("supabase/tests/student_subject_lifecycle_test.sql")
sql_test.write_text(r'''begin;

select plan(22);

select is(
  to_regprocedure(
    'public.end_organization_student_subject_service(uuid,uuid,uuid,integer)'
  ) is not null,
  true,
  'end student subject service function exists'
);

select is(
  to_regprocedure(
    'public.restore_organization_student_subject_service(uuid,uuid,uuid,integer,uuid,date)'
  ) is not null,
  true,
  'restore student subject service function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.end_organization_student_subject_service(uuid,uuid,uuid,integer)'
    )
  ),
  false,
  'end public function is security-invoker'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.restore_organization_student_subject_service(uuid,uuid,uuid,integer,uuid,date)'
    )
  ),
  false,
  'restore public function is security-invoker'
);

select is(
  has_function_privilege(
    'anon',
    'public.end_organization_student_subject_service(uuid,uuid,uuid,integer)',
    'execute'
  ),
  false,
  'anon cannot end a student subject service'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.end_organization_student_subject_service(uuid,uuid,uuid,integer)',
    'execute'
  ),
  true,
  'authenticated can call the manager-gated end command'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-000000000001',
  true
);
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

select throws_ok(
  $$
    select public.end_organization_student_subject_service(
      '75000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1
    )
  $$,
  'P0001',
  'student_subject_pending_actions',
  'ending refuses to strand a pending teaching action'
);

reset role;

update public.case_actions as action
set status = 'done',
    is_primary = false,
    completed_at = timezone('utc', now()),
    completed_by_membership_id = action.assigned_membership_id,
    updated_at = timezone('utc', now())
from public.learning_cases as learning_case
where learning_case.id = action.learning_case_id
  and learning_case.organization_id = action.organization_id
  and learning_case.student_subject_profile_id =
    '67000000-0000-0000-0000-000000000001'
  and action.status = 'pending';

set local role authenticated;

select throws_ok(
  $$
    select public.end_organization_student_subject_service(
      '75000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1
    )
  $$,
  'P0001',
  'student_subject_open_cases',
  'ending refuses to hide unresolved Learning Cases after actions are clear'
);

reset role;

update public.learning_cases
set status = 'closed',
    stable_at = coalesce(stable_at, timezone('utc', now())),
    closed_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
where student_subject_profile_id = '67000000-0000-0000-0000-000000000001'
  and organization_id = '00000000-0000-0000-0000-000000000001';

set local role authenticated;

select lives_ok(
  $$
    select set_config(
      'xueqing.subject_end_result',
      public.end_organization_student_subject_service(
        '75000000-0000-0000-0000-000000000003',
        '00000000-0000-0000-0000-000000000001',
        '67000000-0000-0000-0000-000000000001',
        1
      )::text,
      true
    )
  $$,
  'manager can end a clean subject service'
);

select is(
  current_setting('xueqing.subject_end_result')::jsonb ->> 'status',
  'inactive',
  'end result reports inactive status'
);

reset role;

select is(
  (
    select status
    from public.student_subject_profiles
    where id = '67000000-0000-0000-0000-000000000001'
  ),
  'inactive',
  'subject profile is preserved and marked inactive'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments
    where student_subject_profile_id = '67000000-0000-0000-0000-000000000001'
      and status = 'active'
  ),
  0,
  'ending removes active teaching responsibility from the subject'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments
    where student_subject_profile_id = '67000000-0000-0000-0000-000000000001'
      and status = 'ended'
  ) > 0,
  true,
  'ended assignments remain as history'
);

set local role authenticated;

select lives_ok(
  $$
    select public.end_organization_student_subject_service(
      '75000000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      1
    )
  $$,
  'same end operation safely replays the committed result'
);

select lives_ok(
  $$
    select set_config(
      'xueqing.subject_restore_result',
      public.restore_organization_student_subject_service(
        '75000000-0000-0000-0000-000000000004',
        '00000000-0000-0000-0000-000000000001',
        '67000000-0000-0000-0000-000000000001',
        2,
        '61000000-0000-0000-0000-000000000001',
        null
      )::text,
      true
    )
  $$,
  'manager can restore the same profile with an eligible lead teacher'
);

select is(
  current_setting('xueqing.subject_restore_result')::jsonb ->> 'status',
  'active',
  'restore result reports active status'
);

reset role;

select is(
  (
    select status
    from public.student_subject_profiles
    where id = '67000000-0000-0000-0000-000000000001'
  ),
  'active',
  'restore reactivates the same profile instead of creating a duplicate'
);

select is(
  (
    select count(*)::int
    from public.student_subject_profiles
    where id = '67000000-0000-0000-0000-000000000001'
  ),
  1,
  'restore keeps one durable subject profile'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments
    where student_subject_profile_id = '67000000-0000-0000-0000-000000000001'
      and status = 'active'
      and assignment_role = 'lead'
  ),
  1,
  'restore creates exactly one current lead assignment'
);

set local role authenticated;

select lives_ok(
  $$
    select public.restore_organization_student_subject_service(
      '75000000-0000-0000-0000-000000000004',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      2,
      '61000000-0000-0000-0000-000000000001',
      null
    )
  $$,
  'same restore operation safely replays the committed result'
);

select is(
  (
    select count(*)::int
    from public.student_teacher_assignments
    where student_subject_profile_id = '67000000-0000-0000-0000-000000000001'
      and status = 'active'
      and assignment_role = 'lead'
  ),
  1,
  'restore retry does not duplicate the lead assignment'
);

select is(
  (
    select (subject_item ->> 'status')
    from public.list_organization_students(
      '00000000-0000-0000-0000-000000000001'
    ) as student_row
    cross join lateral jsonb_array_elements(student_row -> 'subjects') as subject_item
    where student_row ->> 'student_id' = '30000000-0000-0000-0000-000000000001'
      and subject_item ->> 'student_subject_profile_id' =
        '67000000-0000-0000-0000-000000000001'
  ),
  'active',
  'manager roster exposes profile lifecycle status for the subject'
);

select is(
  (
    select (subject_item ->> 'version')::int
    from public.list_organization_students(
      '00000000-0000-0000-0000-000000000001'
    ) as student_row
    cross join lateral jsonb_array_elements(student_row -> 'subjects') as subject_item
    where student_row ->> 'student_id' = '30000000-0000-0000-0000-000000000001'
      and subject_item ->> 'student_subject_profile_id' =
        '67000000-0000-0000-0000-000000000001'
  ),
  3,
  'manager roster exposes the current profile version for stale-write protection'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-000000000002',
  true
);
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
  $$
    select public.end_organization_student_subject_service(
      '75000000-0000-0000-0000-000000000005',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      3
    )
  $$,
  'P0001',
  'organization_manager_required',
  'non-manager cannot end a student subject service'
);

select * from finish();
rollback;
''')

repo = Path("lib/cloud/organization_management_repository.dart")
insert_before(
    repo,
    "class OrganizationStudentRecord {\n",
    r'''class OrganizationStudentSubjectService {
  const OrganizationStudentSubjectService({
    required this.profileId,
    required this.organizationSubjectId,
    required this.subjectName,
    required this.status,
    required this.version,
  });

  final String profileId;
  final String organizationSubjectId;
  final String subjectName;
  final String status;
  final int version;

  bool get isActive => status == 'active';
  bool get isInactive => status == 'inactive';
  bool get isArchived => status == 'archived';

  factory OrganizationStudentSubjectService.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationStudentSubjectService(
      profileId: _requiredString(
        json['student_subject_profile_id'],
        'student_subject_profile_id',
      ),
      organizationSubjectId: _requiredString(
        json['organization_subject_id'],
        'organization_subject_id',
      ),
      subjectName: _stringValue(json['display_name']) ?? '未命名学科',
      status: _stringValue(json['status']) ?? 'unknown',
      version: _intValue(json['version']) ?? 1,
    );
  }
}

''',
)
replace_once(
    repo,
    "    required this.endsOn,\n    required this.subjectNames,\n  });",
    "    required this.endsOn,\n    required this.subjectNames,\n    this.subjectServices = const <OrganizationStudentSubjectService>[],\n  });",
)
replace_once(
    repo,
    "  final DateTime? endsOn;\n  final List<String> subjectNames;\n",
    "  final DateTime? endsOn;\n  final List<String> subjectNames;\n  final List<OrganizationStudentSubjectService> subjectServices;\n",
)
replace_once(
    repo,
    r'''    final rawSubjects = json['subjects'];
    final subjectNames = <String>[];
    if (rawSubjects is List) {
      for (final item in rawSubjects) {
        if (item is Map) {
          final name = _stringValue(item['display_name']);
          if (name != null) {
            subjectNames.add(name);
          }
        }
      }
    }
''',
    r'''    final rawSubjects = json['subjects'];
    final subjectNames = <String>[];
    final subjectServices = <OrganizationStudentSubjectService>[];
    if (rawSubjects is List) {
      for (final item in rawSubjects) {
        if (item is! Map) continue;
        final mapped = Map<String, dynamic>.from(item);
        final name = _stringValue(mapped['display_name']);
        final profileId = _stringValue(mapped['student_subject_profile_id']);
        if (profileId == null) {
          // Backward-compatible with a server that has not deployed the
          // lifecycle read shape yet.
          if (name != null) subjectNames.add(name);
          continue;
        }
        final service = OrganizationStudentSubjectService.fromJson(mapped);
        subjectServices.add(service);
        if (service.isActive) subjectNames.add(service.subjectName);
      }
    }
''',
)
replace_once(
    repo,
    "      subjectNames: List<String>.unmodifiable(subjectNames),\n    );",
    "      subjectNames: List<String>.unmodifiable(subjectNames),\n      subjectServices: List<OrganizationStudentSubjectService>.unmodifiable(\n        subjectServices,\n      ),\n    );",
)
insert_before(
    repo,
    "class OrganizationStudentUpdateResult {\n",
    r'''class OrganizationStudentSubjectLifecycleResult {
  const OrganizationStudentSubjectLifecycleResult({
    required this.operationId,
    required this.organizationId,
    required this.studentId,
    required this.studentName,
    required this.studentSubjectProfileId,
    required this.organizationSubjectId,
    required this.subjectName,
    required this.status,
    required this.profileVersion,
    required this.endedAssignmentCount,
    this.assignmentId,
    this.teacherMembershipId,
    this.teacherDisplayName,
    this.startsOn,
  });

  final String operationId;
  final String organizationId;
  final String studentId;
  final String studentName;
  final String studentSubjectProfileId;
  final String organizationSubjectId;
  final String subjectName;
  final String status;
  final int profileVersion;
  final int endedAssignmentCount;
  final String? assignmentId;
  final String? teacherMembershipId;
  final String? teacherDisplayName;
  final DateTime? startsOn;

  factory OrganizationStudentSubjectLifecycleResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationStudentSubjectLifecycleResult(
      operationId: _requiredString(json['operation_id'], 'operation_id'),
      organizationId: _requiredString(
        json['organization_id'],
        'organization_id',
      ),
      studentId: _requiredString(json['student_id'], 'student_id'),
      studentName: _stringValue(json['student_name']) ?? '未命名学生',
      studentSubjectProfileId: _requiredString(
        json['student_subject_profile_id'],
        'student_subject_profile_id',
      ),
      organizationSubjectId: _requiredString(
        json['organization_subject_id'],
        'organization_subject_id',
      ),
      subjectName: _stringValue(json['subject_name']) ?? '未命名学科',
      status: _stringValue(json['status']) ?? 'unknown',
      profileVersion: _intValue(json['profile_version']) ?? 1,
      endedAssignmentCount: _intValue(json['ended_assignment_count']) ?? 0,
      assignmentId: _stringValue(json['assignment_id']),
      teacherMembershipId: _stringValue(json['teacher_membership_id']),
      teacherDisplayName: _stringValue(json['teacher_display_name']),
      startsOn: _dateTimeValue(json['starts_on']),
    );
  }
}

''',
)
replace_once(
    repo,
    r'''  Future<OrganizationStudentSetupResult> addStudentSubject({
    required String operationId,
    required String organizationId,
    required String studentId,
    required String organizationSubjectId,
    required String teacherMembershipId,
    DateTime? startsOn,
  });

''',
    r'''  Future<OrganizationStudentSetupResult> addStudentSubject({
    required String operationId,
    required String organizationId,
    required String studentId,
    required String organizationSubjectId,
    required String teacherMembershipId,
    DateTime? startsOn,
  });

  Future<OrganizationStudentSubjectLifecycleResult> endStudentSubjectService({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
  });

  Future<OrganizationStudentSubjectLifecycleResult>
  restoreStudentSubjectService({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
    required String teacherMembershipId,
    DateTime? startsOn,
  });

''',
)
insert_before(
    repo,
    "String? organizationStudentSetupErrorMessage(Object error) {\n",
    r'''String? organizationStudentSubjectLifecycleErrorMessage(Object error) {
  final detail = switch (error) {
    AuthException(:final message) => message.trim(),
    PostgrestException(:final message) => message.trim(),
    _ => null,
  };
  if (detail == null) return null;
  return switch (detail.toLowerCase()) {
    'invalid_student_subject_lifecycle_input' => '学科服务状态信息不完整，请刷新后重试。',
    'student_subject_profile_not_found' => '这门学生学科档案已变化，请刷新后重试。',
    'student_subject_profile_archived' => '这门学科档案已经归档，不能直接恢复。',
    'student_subject_service_not_active' => '这门学科当前已经不是进行中状态，请刷新后重试。',
    'student_subject_service_not_inactive' => '这门学科当前不处于可恢复状态，请刷新后重试。',
    'student_subject_pending_actions' => '这门学科还有待执行行动，请先完成、取消或交接行动后再结束学科。',
    'student_subject_open_cases' => '这门学科还有未关闭的学情问题，请先完成验证并关闭 Case 后再结束学科。',
    'student_subject_active_assignment_exists' => '这门学科仍有当前任课关系，请刷新后核对。',
    'student_not_active' => '学生当前不是正常教学状态，恢复学科前请先恢复学生状态。',
    'organization_subject_not_active' => '该机构学科已停用，暂不能恢复学生学科服务。',
    'teacher_membership_not_found' => '所选老师已不在本机构，请刷新后重新选择。',
    'teacher_membership_not_active' => '所选老师当前不是在岗状态，请刷新后重新选择。',
    'teacher_app_user_not_active' => '所选老师账号当前不可用，请刷新后重新选择。',
    'teacher_role_required' => '所选成员还没有老师角色，暂不能负责学生。',
    'teacher_subject_scope_required' => '所选老师没有该学科的有效教学范围，请先配置教学范围。',
    'version_conflict' => '这门学生学科档案刚刚被别人修改，请刷新后重试。',
    'operation_id_reuse_conflict' => '这次操作编号已被用于另一项操作，请重新打开后再试。',
    'operation_incomplete' => '上一次操作还没有完成，请稍后重试。',
    'invalid_live_session' => '登录状态已失效，请重新登录。',
    'organization_not_found' => '机构不存在或已归档，请刷新后重试。',
    'organization_manager_required' => '当前账号没有本机构管理权限。',
    _ => null,
  };
}

''',
)
impl_anchor = r'''  @override
  Future<OrganizationStudentTeacherAssignmentTransferResult>
  transferStudentTeacherAssignment({
'''
insert_before(
    repo,
    impl_anchor,
    r'''  @override
  Future<OrganizationStudentSubjectLifecycleResult> endStudentSubjectService({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentSubjectProfileId.trim().isEmpty ||
        expectedProfileVersion <= 0) {
      throw ArgumentError('Student subject lifecycle identity is invalid.');
    }
    final response = await _call(
      'end_organization_student_subject_service',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_subject_profile_id': studentSubjectProfileId,
        'p_expected_profile_version': expectedProfileVersion,
      },
    );
    return OrganizationStudentSubjectLifecycleResult.fromJson(
      _mapResponse(response),
    );
  }

  @override
  Future<OrganizationStudentSubjectLifecycleResult>
  restoreStudentSubjectService({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
    required String teacherMembershipId,
    DateTime? startsOn,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentSubjectProfileId.trim().isEmpty ||
        expectedProfileVersion <= 0 ||
        teacherMembershipId.trim().isEmpty) {
      throw ArgumentError('Student subject lifecycle identity is invalid.');
    }
    final response = await _call(
      'restore_organization_student_subject_service',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_subject_profile_id': studentSubjectProfileId,
        'p_expected_profile_version': expectedProfileVersion,
        'p_teacher_membership_id': teacherMembershipId,
        'p_starts_on': _dateOnlyValue(startsOn),
      },
    );
    return OrganizationStudentSubjectLifecycleResult.fromJson(
      _mapResponse(response),
    );
  }

''',
)

restore_dialog = Path(
    "lib/features/organization_management/presentation/"
    "organization_student_subject_restore_dialog.dart"
)
restore_dialog.write_text(r'''import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../cloud/organization_management_repository.dart';

class OrganizationStudentSubjectRestoreDialog extends StatefulWidget {
  const OrganizationStudentSubjectRestoreDialog({
    required this.student,
    required this.service,
    required this.teachers,
    super.key,
  });

  final OrganizationStudentRecord student;
  final OrganizationStudentSubjectService service;
  final List<OrganizationSetupTeacher> teachers;

  @override
  State<OrganizationStudentSubjectRestoreDialog> createState() =>
      _OrganizationStudentSubjectRestoreDialogState();
}

class _OrganizationStudentSubjectRestoreDialogState
    extends State<OrganizationStudentSubjectRestoreDialog> {
  late OrganizationSetupTeacher _selectedTeacher;

  @override
  void initState() {
    super.initState();
    assert(widget.teachers.isNotEmpty);
    _selectedTeacher = widget.teachers.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('恢复 ${widget.student.studentName} · ${widget.service.subjectName}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '恢复会继续使用原来的学科档案和全部历史记录，并建立一条新的主负责老师关系。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<OrganizationSetupTeacher>(
              key: const Key('student-subject-restore-teacher'),
              initialValue: _selectedTeacher,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '主负责老师 *'),
              items: [
                for (final teacher in widget.teachers)
                  DropdownMenuItem(
                    value: teacher,
                    child: Text(
                      teacher.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (teacher) {
                if (teacher != null) setState(() => _selectedTeacher = teacher);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '只会列出当前在岗且已配置这门可教学科的老师。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('student-subject-restore-submit'),
          onPressed: () => Navigator.of(context).pop(_selectedTeacher),
          child: const Text('恢复学科'),
        ),
      ],
    );
  }
}
''')

page = Path(
    "lib/features/organization_management/presentation/organization_management_page.dart"
)
replace_once(
    page,
    "import 'organization_student_subject_setup_dialog.dart';\n",
    "import 'organization_student_subject_restore_dialog.dart';\n"
    "import 'organization_student_subject_setup_dialog.dart';\n",
)
replace_once(
    page,
    "                        onAddStudentSubject: _addStudentSubject,\n",
    "                        onAddStudentSubject: _addStudentSubject,\n"
    "                        onToggleStudentSubjectService:\n"
    "                            _toggleStudentSubjectService,\n",
)

areas = Path(
    "lib/features/organization_management/presentation/organization_management_areas.dart"
)
replace_once(
    areas,
    "    required this.onAddStudentSubject,\n    required this.onInviteMember,\n",
    "    required this.onAddStudentSubject,\n"
    "    required this.onToggleStudentSubjectService,\n"
    "    required this.onInviteMember,\n",
)
replace_once(
    areas,
    "  final Future<void> Function(OrganizationStudentRecord student)\n"
    "  onAddStudentSubject;\n"
    "  final VoidCallback onInviteMember;\n",
    "  final Future<void> Function(OrganizationStudentRecord student)\n"
    "  onAddStudentSubject;\n"
    "  final Future<void> Function(\n"
    "    OrganizationStudentRecord student,\n"
    "    OrganizationStudentSubjectService service,\n"
    "  )\n"
    "  onToggleStudentSubjectService;\n"
    "  final VoidCallback onInviteMember;\n",
)
replace_once(
    areas,
    "                  ...student.subjectNames,\n",
    "                  ...student.subjectNames,\n"
    "                  ...student.subjectServices.map((service) => service.subjectName),\n",
)
replace_once(
    areas,
    "                          onAddSubject: student.isActive && !student.isMerged\n"
    "                              ? () => widget.onAddStudentSubject(student)\n"
    "                              : null,\n"
    "                          onEdit: student.isMerged\n",
    "                          onAddSubject: student.isActive && !student.isMerged\n"
    "                              ? () => widget.onAddStudentSubject(student)\n"
    "                              : null,\n"
    "                          onToggleSubjectService: student.isMerged\n"
    "                              ? null\n"
    "                              : (service) => widget\n"
    "                                  .onToggleStudentSubjectService(\n"
    "                                    student,\n"
    "                                    service,\n"
    "                                  ),\n"
    "                          onEdit: student.isMerged\n",
)

rows = Path(
    "lib/features/organization_management/presentation/organization_management_rows.dart"
)
replace_once(
    rows,
    "    required this.onAddSubject,\n    required this.onEdit,\n  });",
    "    required this.onAddSubject,\n"
    "    required this.onToggleSubjectService,\n"
    "    required this.onEdit,\n"
    "  });",
)
replace_once(
    rows,
    "  final VoidCallback? onAddSubject;\n  final VoidCallback? onEdit;\n",
    "  final VoidCallback? onAddSubject;\n"
    "  final Future<void> Function(OrganizationStudentSubjectService service)?\n"
    "  onToggleSubjectService;\n"
    "  final VoidCallback? onEdit;\n",
)
replace_once(
    rows,
    r'''          if (student.subjectNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '学科：${student.subjectNames.join('、')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
''',
    r'''          if (student.subjectServices.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Column(
              children: [
                for (final service in student.subjectServices)
                  _StudentSubjectServiceRow(
                    service: service,
                    busy: busy,
                    onToggle:
                        onToggleSubjectService == null ||
                            service.isArchived ||
                            service.isInactive && !student.isActive
                        ? null
                        : () => onToggleSubjectService!(service),
                  ),
              ],
            ),
          ] else if (student.subjectNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '学科：${student.subjectNames.join('、')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
''',
)
insert_before(
    rows,
    "class _StudentTeacherAssignmentTile extends StatelessWidget {\n",
    r'''class _StudentSubjectServiceRow extends StatelessWidget {
  const _StudentSubjectServiceRow({
    required this.service,
    required this.busy,
    required this.onToggle,
  });

  final OrganizationStudentSubjectService service;
  final bool busy;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              service.subjectName,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _ManagementStatusChip(
            label: _studentSubjectStatusLabel(service.status),
            isPositive: service.isActive,
          ),
          if (onToggle != null) ...[
            const SizedBox(width: AppSpacing.xxs),
            TextButton(
              key: ValueKey<String>(
                service.isActive
                    ? 'student-subject-end-${service.profileId}'
                    : 'student-subject-restore-${service.profileId}',
              ),
              onPressed: busy ? null : onToggle,
              child: Text(service.isActive ? '结束' : '恢复'),
            ),
          ],
        ],
      ),
    );
  }
}

''',
)

helpers = Path(
    "lib/features/organization_management/presentation/organization_management_helpers.dart"
)
insert_before(
    helpers,
    "String _membershipStatusLabel(String status) {\n",
    r'''String _studentSubjectStatusLabel(String status) {
  return switch (status) {
    'active' => '进行中',
    'inactive' => '已结束',
    'archived' => '已归档',
    _ => '状态未知',
  };
}

''',
)

actions = Path(
    "lib/features/organization_management/presentation/organization_management_learning_actions.dart"
)
insert_before(
    actions,
    "  Future<void> _transferStudentTeacherAssignment(\n",
    r'''  Future<void> _toggleStudentSubjectService(
    OrganizationStudentRecord student,
    OrganizationStudentSubjectService service,
  ) async {
    if (_busy || service.isArchived) return;

    if (service.isActive) {
      final confirmed = await _confirm(
        title: '结束 ${student.studentName} · ${service.subjectName}？',
        message:
            '历史学情、证据和已结束记录都会保留。系统不会自动关闭问题或行动；如果仍有未关闭 Case 或待执行行动，本次结束会被拒绝并提示先完成闭环。',
        confirmLabel: '确认结束',
      );
      if (!mounted || !confirmed) return;
      await _runMutation(
        () => widget.repository.endStudentSubjectService(
          operationId: createOperationId(),
          organizationId: widget.organizationId,
          studentSubjectProfileId: service.profileId,
          expectedProfileVersion: service.version,
        ),
        '已结束 ${student.studentName} 的 ${service.subjectName} 学科服务。',
      );
      return;
    }

    if (!service.isInactive) return;
    if (!student.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先把学生恢复为正常教学状态，再恢复具体学科。')),
      );
      return;
    }

    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) return;
      final teachers = snapshot.setupOptions.teachersForSubject(
        service.organizationSubjectId,
      );
      if (teachers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前没有在岗且具备该学科有效教学范围的老师。')),
        );
        return;
      }
      final teacher = await showDialog<OrganizationSetupTeacher>(
        context: context,
        builder: (context) => OrganizationStudentSubjectRestoreDialog(
          student: student,
          service: service,
          teachers: teachers,
        ),
      );
      if (!mounted || teacher == null) return;
      await _runMutation(
        () => widget.repository.restoreStudentSubjectService(
          operationId: createOperationId(),
          organizationId: widget.organizationId,
          studentSubjectProfileId: service.profileId,
          expectedProfileVersion: service.version,
          teacherMembershipId: teacher.membershipId,
        ),
        '已恢复 ${student.studentName} 的 ${service.subjectName} · ${teacher.displayName} 负责。',
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    }
  }

''',
)

core = Path(
    "lib/features/organization_management/presentation/organization_management_core.dart"
)
replace_once(
    core,
    "    final setupError = organizationStudentSetupErrorMessage(error);\n"
    "    if (setupError != null) return setupError;\n",
    "    final subjectLifecycleError =\n"
    "        organizationStudentSubjectLifecycleErrorMessage(error);\n"
    "    if (subjectLifecycleError != null) return subjectLifecycleError;\n"
    "    final setupError = organizationStudentSetupErrorMessage(error);\n"
    "    if (setupError != null) return setupError;\n",
)

# Flutter fake/test updates.
test = Path("test/features/organization_management_test.dart")
replace_once(
    test,
    "  int studentSubjectAddCount = 0;\n",
    "  int studentSubjectAddCount = 0;\n"
    "  int studentSubjectEndCount = 0;\n"
    "  int studentSubjectRestoreCount = 0;\n",
)
insert_before(
    test,
    "  @override\n  Future<OrganizationStudentTeacherAssignmentTransferResult>\n",
    r'''  @override
  Future<OrganizationStudentSubjectLifecycleResult> endStudentSubjectService({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
  }) async {
    studentSubjectEndCount++;
    final studentIndex = students.indexWhere(
      (student) => student.subjectServices.any(
        (service) => service.profileId == studentSubjectProfileId,
      ),
    );
    if (studentIndex < 0) throw StateError('Subject service not found.');
    final previous = students[studentIndex];
    final services = <OrganizationStudentSubjectService>[
      for (final service in previous.subjectServices)
        if (service.profileId == studentSubjectProfileId)
          OrganizationStudentSubjectService(
            profileId: service.profileId,
            organizationSubjectId: service.organizationSubjectId,
            subjectName: service.subjectName,
            status: 'inactive',
            version: expectedProfileVersion + 1,
          )
        else
          service,
    ];
    final target = services.firstWhere(
      (service) => service.profileId == studentSubjectProfileId,
    );
    students[studentIndex] = OrganizationStudentRecord(
      studentId: previous.studentId,
      studentName: previous.studentName,
      studentCode: previous.studentCode,
      status: previous.status,
      version: previous.version,
      grade: previous.grade,
      className: previous.className,
      campus: previous.campus,
      startsOn: previous.startsOn,
      endsOn: previous.endsOn,
      subjectNames: [
        for (final service in services)
          if (service.isActive) service.subjectName,
      ],
      subjectServices: services,
    );
    return OrganizationStudentSubjectLifecycleResult(
      operationId: operationId,
      organizationId: organizationId,
      studentId: previous.studentId,
      studentName: previous.studentName,
      studentSubjectProfileId: target.profileId,
      organizationSubjectId: target.organizationSubjectId,
      subjectName: target.subjectName,
      status: target.status,
      profileVersion: target.version,
      endedAssignmentCount: 1,
    );
  }

  @override
  Future<OrganizationStudentSubjectLifecycleResult>
  restoreStudentSubjectService({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
    required String teacherMembershipId,
    DateTime? startsOn,
  }) async {
    studentSubjectRestoreCount++;
    final studentIndex = students.indexWhere(
      (student) => student.subjectServices.any(
        (service) => service.profileId == studentSubjectProfileId,
      ),
    );
    if (studentIndex < 0) throw StateError('Subject service not found.');
    final previous = students[studentIndex];
    final services = <OrganizationStudentSubjectService>[
      for (final service in previous.subjectServices)
        if (service.profileId == studentSubjectProfileId)
          OrganizationStudentSubjectService(
            profileId: service.profileId,
            organizationSubjectId: service.organizationSubjectId,
            subjectName: service.subjectName,
            status: 'active',
            version: expectedProfileVersion + 1,
          )
        else
          service,
    ];
    final target = services.firstWhere(
      (service) => service.profileId == studentSubjectProfileId,
    );
    students[studentIndex] = OrganizationStudentRecord(
      studentId: previous.studentId,
      studentName: previous.studentName,
      studentCode: previous.studentCode,
      status: previous.status,
      version: previous.version,
      grade: previous.grade,
      className: previous.className,
      campus: previous.campus,
      startsOn: previous.startsOn,
      endsOn: previous.endsOn,
      subjectNames: [
        for (final service in services)
          if (service.isActive) service.subjectName,
      ],
      subjectServices: services,
    );
    final teacher = setupOptions.teachers.firstWhere(
      (item) => item.membershipId == teacherMembershipId,
    );
    studentTeacherAssignments.add(
      OrganizationStudentTeacherAssignment(
        assignmentId: 'assignment-restored-$studentSubjectRestoreCount',
        organizationId: organizationId,
        studentSubjectProfileId: target.profileId,
        studentId: previous.studentId,
        studentName: previous.studentName,
        organizationSubjectId: target.organizationSubjectId,
        subjectName: target.subjectName,
        subjectCode: target.subjectName.toLowerCase(),
        membershipId: teacher.membershipId,
        teacherName: teacher.displayName,
        teacherEmail: teacher.email,
        assignmentRole: 'lead',
        status: 'active',
        version: 1,
        activeFrom: startsOn ?? DateTime(2026, 9, 8),
        activeTo: null,
        endedAt: null,
      ),
    );
    return OrganizationStudentSubjectLifecycleResult(
      operationId: operationId,
      organizationId: organizationId,
      studentId: previous.studentId,
      studentName: previous.studentName,
      studentSubjectProfileId: target.profileId,
      organizationSubjectId: target.organizationSubjectId,
      subjectName: target.subjectName,
      status: target.status,
      profileVersion: target.version,
      endedAssignmentCount: 0,
      assignmentId: 'assignment-restored-$studentSubjectRestoreCount',
      teacherMembershipId: teacher.membershipId,
      teacherDisplayName: teacher.displayName,
      startsOn: startsOn ?? DateTime(2026, 9, 8),
    );
  }

''',
)
replace_once(
    test,
    "    subjectNames: ['数学'],\n  );\n}\n",
    "    subjectNames: ['数学'],\n"
    "    subjectServices: const [\n"
    "      OrganizationStudentSubjectService(\n"
    "        profileId: 'profile-1',\n"
    "        organizationSubjectId: 'subject-1',\n"
    "        subjectName: '数学',\n"
    "        status: 'active',\n"
    "        version: 1,\n"
    "      ),\n"
    "    ],\n"
    "  );\n}\n",
)
# Preserve lifecycle services when the add-subject fake rebuilds the record.
replace_once(
    test,
    "        subjectNames: <String>[\n"
    "          ...previous.subjectNames,\n"
    "          if (!previous.subjectNames.contains(subject.displayName))\n"
    "            subject.displayName,\n"
    "        ],\n"
    "      );\n",
    "        subjectNames: <String>[\n"
    "          ...previous.subjectNames,\n"
    "          if (!previous.subjectNames.contains(subject.displayName))\n"
    "            subject.displayName,\n"
    "        ],\n"
    "        subjectServices: <OrganizationStudentSubjectService>[\n"
    "          ...previous.subjectServices,\n"
    "          OrganizationStudentSubjectService(\n"
    "            profileId: addedStudentSubject!.studentSubjectProfileId,\n"
    "            organizationSubjectId: organizationSubjectId,\n"
    "            subjectName: subject.displayName,\n"
    "            status: 'active',\n"
    "            version: 1,\n"
    "          ),\n"
    "        ],\n"
    "      );\n",
)
# Add focused lifecycle widget tests before the optional-detail test.
insert_before(
    test,
    "  testWidgets('keeps optional student details behind one disclosure', (\n",
    r'''  testWidgets('ends one subject service without removing the student root', (
    tester,
  ) async {
    final student = _studentRecord();
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
      students: [student],
      studentTeacherAssignments: [_studentTeacherAssignment()],
    );
    await _pumpManagement(tester, repository);
    await _selectManagementArea(tester, '学生');

    final endButton = find.byKey(const ValueKey<String>('student-subject-end-profile-1'));
    await tester.ensureVisible(endButton);
    await tester.tap(endButton);
    await tester.pumpAndSettle();

    expect(find.text('结束 原学生 · 数学？'), findsOneWidget);
    await tester.tap(find.text('确认结束'));
    await tester.pumpAndSettle();

    expect(repository.studentSubjectEndCount, 1);
    expect(repository.students.single.studentId, student.studentId);
    expect(repository.students.single.subjectServices.single.status, 'inactive');
    expect(find.text('已结束'), findsOneWidget);
  });

  testWidgets('restores an ended subject by choosing a current eligible teacher', (
    tester,
  ) async {
    final student = OrganizationStudentRecord(
      studentId: 'student-1',
      studentName: '原学生',
      studentCode: 'S-001',
      status: 'active',
      version: 3,
      grade: '初二',
      className: '一班',
      campus: '本部',
      startsOn: DateTime(2026, 9, 1),
      endsOn: null,
      subjectNames: const [],
      subjectServices: const [
        OrganizationStudentSubjectService(
          profileId: 'profile-1',
          organizationSubjectId: 'subject-1',
          subjectName: '数学',
          status: 'inactive',
          version: 2,
        ),
      ],
    );
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
      students: [student],
    );
    await _pumpManagement(tester, repository);
    await _selectManagementArea(tester, '学生');

    final restoreButton = find.byKey(
      const ValueKey<String>('student-subject-restore-profile-1'),
    );
    await tester.ensureVisible(restoreButton);
    await tester.tap(restoreButton);
    await tester.pumpAndSettle();

    expect(find.text('恢复 原学生 · 数学'), findsOneWidget);
    expect(find.text('主负责老师 *'), findsOneWidget);
    await tester.tap(find.byKey(const Key('student-subject-restore-submit')));
    await tester.pumpAndSettle();

    expect(repository.studentSubjectRestoreCount, 1);
    expect(repository.students.single.subjectServices.single.status, 'active');
    expect(repository.studentTeacherAssignments.single.isActive, isTrue);
    expect(find.text('进行中'), findsOneWidget);
  });

''',
)
