-- Phase 0B.0-T: make student teacher handoff explicit and atomic.
--
-- This is a fictional/local compatibility migration. It is not a
-- production migration or permission to import real student data.
--
-- A handoff ends one historical assignment and creates the replacement
-- assignment in the same transaction. It never changes Case ownership or
-- pending Action ownership implicitly; those remain separate handoff work.

alter table public.student_teacher_assignments
  add column if not exists version integer not null default 1;

alter table public.student_teacher_assignments
  drop constraint if exists student_teacher_assignments_version_check;

alter table public.student_teacher_assignments
  add constraint student_teacher_assignments_version_check
  check (version > 0);

-- The manager roster is filtered by organization. This index keeps the
-- organization/status lookup bounded as the pilot grows.
create index if not exists student_teacher_assignments_org_status_profile_idx
  on public.student_teacher_assignments (
    organization_id,
    status,
    student_subject_profile_id
  );

create or replace function private.bump_student_teacher_assignment_version_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  new.version := old.version + 1;
  return new;
end
$function$;

drop trigger if exists student_teacher_assignments_version_bump
  on public.student_teacher_assignments;

create trigger student_teacher_assignments_version_bump
before update on public.student_teacher_assignments
for each row
execute function private.bump_student_teacher_assignment_version_v2();

revoke all on function private.bump_student_teacher_assignment_version_v2()
  from public;

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
    'update_organization_student',
    'update_organization_membership_status',
    'update_organization_teacher_subject_scope',
    'transfer_organization_student_teacher_assignment'
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
    'student',
    'membership',
    'membership_subject_scope',
    'student_teacher_assignment'
  ));

create or replace function public.list_organization_student_teacher_assignments(
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
    'assignment_id', assignment.id,
    'organization_id', assignment.organization_id,
    'student_subject_profile_id', profile.id,
    'student_id', student.id,
    'student_name', student.name,
    'organization_subject_id', organization_subject.id,
    'subject_name', organization_subject.display_name,
    'subject_code', subject.code,
    'membership_id', membership.id,
    'teacher_name', coalesce(
      nullif(btrim(app_user.display_name), ''),
      nullif(auth_user.email, ''),
      '未命名老师'
    ),
    'teacher_email', coalesce(auth_user.email, ''),
    'assignment_role', assignment.assignment_role,
    'status', assignment.status,
    'version', assignment.version,
    'active_from', assignment.active_from,
    'active_to', assignment.active_to,
    'ended_at', assignment.ended_at
  )
  from public.student_teacher_assignments as assignment
  join public.student_subject_profiles as profile
    on profile.id = assignment.student_subject_profile_id
   and profile.organization_id = assignment.organization_id
  join public.students as student
    on student.id = profile.student_id
   and student.organization_id = profile.organization_id
  join public.organization_subjects as organization_subject
    on organization_subject.id = profile.organization_subject_id
   and organization_subject.organization_id = profile.organization_id
  join public.subjects as subject
    on subject.id = organization_subject.subject_id
  join public.organization_memberships as membership
    on membership.id = assignment.membership_id
   and membership.organization_id = assignment.organization_id
  join public.app_users as app_user
    on app_user.id = membership.app_user_id
  left join auth.users as auth_user
    on auth_user.id::text = app_user.auth_subject_id
   and app_user.auth_provider = 'supabase'
  where assignment.organization_id = p_organization_id
  order by
    student.name,
    organization_subject.display_name,
    case when assignment.status = 'active' then 0 else 1 end,
    assignment.active_from,
    assignment.id;
end
$function$;

create or replace function public.transfer_organization_student_teacher_assignment(
  p_operation_id uuid,
  p_organization_id uuid,
  p_assignment_id uuid,
  p_expected_assignment_version integer,
  p_replacement_membership_id uuid
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
  source_profile_id uuid;
  source_membership_id uuid;
  source_assignment_role text;
  target_assignment public.student_teacher_assignments%rowtype;
  target_profile public.student_subject_profiles%rowtype;
  source_membership public.organization_memberships%rowtype;
  replacement_membership public.organization_memberships%rowtype;
  v_student_name text;
  v_student_status text;
  v_subject_name text;
  v_subject_code text;
  v_organization_subject_status text;
  v_subject_status text;
  v_previous_teacher_name text;
  v_previous_teacher_email text;
  v_replacement_teacher_name text;
  v_replacement_teacher_email text;
  v_replacement_scope_id uuid;
  ended_assignment_version integer;
  replacement_assignment_id uuid;
  replacement_assignment_version integer;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
begin
  if p_operation_id is null
    or p_organization_id is null
    or p_assignment_id is null
    or p_expected_assignment_version is null
    or p_expected_assignment_version <= 0
    or p_replacement_membership_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_student_teacher_assignment_transfer_input';
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
    assignment.student_subject_profile_id,
    assignment.membership_id,
    assignment.assignment_role
  into
    source_profile_id,
    source_membership_id,
    source_assignment_role
  from public.student_teacher_assignments as assignment
  where assignment.id = p_assignment_id
    and assignment.organization_id = v_organization_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'student_teacher_assignment_not_found';
  end if;

  if not exists (
    select 1
    from public.organization_memberships as membership
    where membership.id = source_membership_id
      and membership.organization_id = v_organization_id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'membership_not_found';
  end if;

  if not exists (
    select 1
    from public.organization_memberships as membership
    where membership.id = p_replacement_membership_id
      and membership.organization_id = v_organization_id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'replacement_teacher_membership_not_found';
  end if;

  -- All organization membership locks are acquired in membership-id order.
  -- This keeps a concurrent member disable/handoff from forming a lock cycle.
  perform 1
  from public.organization_memberships as membership
  where membership.organization_id = v_organization_id
    and membership.id in (
      source_membership_id,
      p_replacement_membership_id
    )
  order by membership.id
  for update;

  select *
  into source_membership
  from public.organization_memberships as membership
  where membership.id = source_membership_id
    and membership.organization_id = v_organization_id;

  select *
  into replacement_membership
  from public.organization_memberships as membership
  where membership.id = p_replacement_membership_id
    and membership.organization_id = v_organization_id;

  select *
  into target_profile
  from public.student_subject_profiles as profile
  where profile.id = source_profile_id
    and profile.organization_id = v_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_profile_not_found';
  end if;

  select *
  into target_assignment
  from public.student_teacher_assignments as assignment
  where assignment.id = p_assignment_id
    and assignment.organization_id = v_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'student_teacher_assignment_not_found';
  end if;

  source_assignment_role := target_assignment.assignment_role;

  select
    student.name,
    student.status
  into
    v_student_name,
    v_student_status
  from public.students as student
  where student.id = target_profile.student_id
    and student.organization_id = v_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'student_not_found';
  end if;

  select
    organization_subject.display_name,
    organization_subject.status,
    subject.code,
    subject.status
  into
    v_subject_name,
    v_organization_subject_status,
    v_subject_code,
    v_subject_status
  from public.organization_subjects as organization_subject
  join public.subjects as subject
    on subject.id = organization_subject.subject_id
  where organization_subject.id = target_profile.organization_subject_id
    and organization_subject.organization_id = v_organization_id
  for update of organization_subject;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'organization_subject_not_found';
  end if;

  select coalesce(
    nullif(btrim(previous_app_user.display_name), ''),
    nullif(previous_auth_user.email, ''),
    '未命名老师'
  ), coalesce(previous_auth_user.email, '')
  into v_previous_teacher_name, v_previous_teacher_email
  from public.app_users as previous_app_user
  left join auth.users as previous_auth_user
    on previous_auth_user.id::text = previous_app_user.auth_subject_id
   and previous_app_user.auth_provider = 'supabase'
  where previous_app_user.id = source_membership.app_user_id;

  select coalesce(
    nullif(btrim(replacement_app_user.display_name), ''),
    nullif(replacement_auth_user.email, ''),
    '未命名老师'
  ), coalesce(replacement_auth_user.email, '')
  into v_replacement_teacher_name, v_replacement_teacher_email
  from public.app_users as replacement_app_user
  left join auth.users as replacement_auth_user
    on replacement_auth_user.id::text = replacement_app_user.auth_subject_id
   and replacement_app_user.auth_provider = 'supabase'
  where replacement_app_user.id = replacement_membership.app_user_id;

  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'transfer_organization_student_teacher_assignment',
    'student_teacher_assignment',
    p_assignment_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  if source_membership_id = p_replacement_membership_id then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_assignment_same_teacher';
  end if;

  if target_assignment.version <> p_expected_assignment_version then
    raise exception using
      errcode = 'P0001',
      message = 'student_teacher_assignment_version_conflict';
  end if;

  if target_assignment.status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'student_teacher_assignment_not_active';
  end if;

  if target_assignment.active_from > v_business_date
    or (
      target_assignment.active_to is not null
      and target_assignment.active_to < v_business_date
    ) then
    raise exception using
      errcode = 'P0001',
      message = 'student_teacher_assignment_not_current';
  end if;

  if target_profile.status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_profile_not_active';
  end if;

  if v_student_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'student_not_active';
  end if;

  if v_organization_subject_status <> 'active'
    or v_subject_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'organization_subject_not_active';
  end if;

  if replacement_membership.status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_membership_not_active';
  end if;

  if not exists (
    select 1
    from public.app_users as replacement_app_user
    where replacement_app_user.id = replacement_membership.app_user_id
      and replacement_app_user.status = 'active'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_app_user_not_active';
  end if;

  if not exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.membership_id = replacement_membership.id
      and membership_role.organization_id = v_organization_id
      and membership_role.role = 'teacher'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_role_required';
  end if;

  select scope.id
  into v_replacement_scope_id
  from public.membership_subject_scopes as scope
  where scope.organization_id = v_organization_id
    and scope.membership_id = replacement_membership.id
    and scope.organization_subject_id = target_profile.organization_subject_id
    and scope.scope_kind = 'teaching'
    and scope.status = 'active'
    and scope.active_from <= v_business_date
    and (
      scope.active_to is null
      or scope.active_to >= v_business_date
    )
  for update;

  if v_replacement_scope_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_subject_scope_required';
  end if;

  if exists (
    select 1
    from public.student_teacher_assignments as assignment
    where assignment.organization_id = v_organization_id
      and assignment.student_subject_profile_id = target_profile.id
      and assignment.membership_id = replacement_membership.id
      and assignment.assignment_role = source_assignment_role
      and assignment.status = 'active'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_assignment_already_active';
  end if;

  update public.student_teacher_assignments
  set status = 'ended',
      active_to = greatest(target_assignment.active_from, v_business_date),
      ended_at = timezone('utc', now())
  where id = target_assignment.id
    and organization_id = v_organization_id
  returning version into ended_assignment_version;

  insert into public.student_teacher_assignments (
    organization_id,
    student_subject_profile_id,
    membership_id,
    assignment_role,
    status,
    active_from
  )
  values (
    v_organization_id,
    target_profile.id,
    replacement_membership.id,
    source_assignment_role,
    'active',
    v_business_date
  )
  returning id, version
  into replacement_assignment_id, replacement_assignment_version;

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', v_organization_id,
    'student_subject_profile_id', target_profile.id,
    'student_id', target_profile.student_id,
    'student_name', v_student_name,
    'organization_subject_id', target_profile.organization_subject_id,
    'subject_name', v_subject_name,
    'subject_code', v_subject_code,
    'assignment_role', source_assignment_role,
    'previous_assignment_id', target_assignment.id,
    'previous_membership_id', target_assignment.membership_id,
    'previous_teacher_name', v_previous_teacher_name,
    'previous_teacher_email', v_previous_teacher_email,
    'previous_assignment_version', ended_assignment_version,
    'replacement_assignment_id', replacement_assignment_id,
    'replacement_membership_id', replacement_membership.id,
    'replacement_teacher_name', v_replacement_teacher_name,
    'replacement_teacher_email', v_replacement_teacher_email,
    'replacement_scope_id', v_replacement_scope_id,
    'replacement_assignment_version', replacement_assignment_version,
    'status', 'transferred',
    'active_from', v_business_date
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

revoke all on function public.list_organization_student_teacher_assignments(uuid)
  from public;
grant execute on function public.list_organization_student_teacher_assignments(uuid)
  to authenticated;
revoke execute on function public.list_organization_student_teacher_assignments(uuid)
  from anon;

revoke all on function public.transfer_organization_student_teacher_assignment(
  uuid,
  uuid,
  uuid,
  integer,
  uuid
) from public;
grant execute on function public.transfer_organization_student_teacher_assignment(
  uuid,
  uuid,
  uuid,
  integer,
  uuid
) to authenticated;
revoke execute on function public.transfer_organization_student_teacher_assignment(
  uuid,
  uuid,
  uuid,
  integer,
  uuid
) from anon;
