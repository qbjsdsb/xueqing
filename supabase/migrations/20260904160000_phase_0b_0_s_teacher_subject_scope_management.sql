-- Phase 0B.0-S: manage teacher teaching subject scopes without
-- silently restoring or orphaning student assignments and Case work.
-- This is a fictional/local compatibility migration. It is not a
-- production migration or permission to import real student data.

alter table public.membership_subject_scopes
  add column if not exists version integer not null default 1;

alter table public.membership_subject_scopes
  drop constraint if exists membership_subject_scopes_version_check;

alter table public.membership_subject_scopes
  add constraint membership_subject_scopes_version_check
  check (version > 0);

-- Earlier setup and membership commands already write this table. A single
-- trigger keeps their optimistic token correct after this column is added.
create or replace function private.bump_membership_subject_scope_version_v2()
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

drop trigger if exists membership_subject_scopes_version_bump
  on public.membership_subject_scopes;

create trigger membership_subject_scopes_version_bump
before update on public.membership_subject_scopes
for each row
execute function private.bump_membership_subject_scope_version_v2();

revoke all on function private.bump_membership_subject_scope_version_v2()
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
    'update_organization_teacher_subject_scope'
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
    'membership_subject_scope'
  ));

create or replace function public.list_organization_teacher_subject_scopes(
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
    'scope_id', scope.id,
    'membership_id', scope.membership_id,
    'organization_subject_id', scope.organization_subject_id,
    'teacher_name', coalesce(
      nullif(btrim(app_user.display_name), ''),
      nullif(auth_user.email, ''),
      '未命名老师'
    ),
    'teacher_email', coalesce(auth_user.email, ''),
    'membership_status', membership.status,
    'subject_name', organization_subject.display_name,
    'subject_code', subject.code,
    'scope_kind', scope.scope_kind,
    'status', scope.status,
    'version', scope.version,
    'active_from', scope.active_from,
    'active_to', scope.active_to
  )
  from public.membership_subject_scopes as scope
  join public.organization_memberships as membership
    on membership.id = scope.membership_id
   and membership.organization_id = scope.organization_id
  join public.app_users as app_user
    on app_user.id = membership.app_user_id
  left join auth.users as auth_user
    on auth_user.id::text = app_user.auth_subject_id
   and app_user.auth_provider = 'supabase'
  join public.organization_subjects as organization_subject
    on organization_subject.id = scope.organization_subject_id
   and organization_subject.organization_id = scope.organization_id
  join public.subjects as subject
    on subject.id = organization_subject.subject_id
  where scope.organization_id = p_organization_id
    and scope.scope_kind = 'teaching'
    and exists (
      select 1
      from public.membership_roles as membership_role
      where membership_role.membership_id = membership.id
        and membership_role.organization_id = membership.organization_id
        and membership_role.role = 'teacher'
    )
  order by
    teacher_name,
    subject.code,
    scope.status desc,
    scope.active_from,
    scope.id;
end
$function$;

create or replace function public.update_organization_teacher_subject_scope(
  p_operation_id uuid,
  p_organization_id uuid,
  p_membership_id uuid,
  p_organization_subject_id uuid,
  p_scope_id uuid,
  p_expected_scope_version integer,
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
  v_business_date date;
  v_status text;
  v_subject_id uuid;
  v_scope_id uuid;
  v_scope_version integer;
  operation_target_id uuid;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
  target_membership public.organization_memberships%rowtype;
  target_scope public.membership_subject_scopes%rowtype;
begin
  v_status := nullif(btrim(coalesce(p_status, '')), '');
  operation_target_id := coalesce(
    p_scope_id,
    p_organization_subject_id
  );

  if p_operation_id is null
    or p_organization_id is null
    or p_membership_id is null
    or p_organization_subject_id is null
    or operation_target_id is null
    or v_status is null
    or v_status not in ('active', 'ended')
    or (
      v_status = 'active'
      and (
        p_scope_id is not null
        or p_expected_scope_version is not null
      )
    )
    or (
      v_status = 'ended'
      and (
        p_scope_id is null
        or p_expected_scope_version is null
        or p_expected_scope_version <= 0
      )
    ) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_teacher_subject_scope_input';
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

  select *
  into target_membership
  from public.organization_memberships as membership
  where membership.id = p_membership_id
    and membership.organization_id = v_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'membership_not_found';
  end if;

  if v_status = 'active'
    and target_membership.status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_membership_not_active';
  end if;

  if v_status = 'active'
    and not exists (
      select 1
      from public.membership_roles as membership_role
      where membership_role.membership_id = target_membership.id
        and membership_role.organization_id = v_organization_id
        and membership_role.role = 'teacher'
    ) then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_role_required';
  end if;

  select organization_subject.id, organization_subject.subject_id
  into v_organization_id, v_subject_id
  from public.organization_subjects as organization_subject
  join public.subjects as subject
    on subject.id = organization_subject.subject_id
   and (
     v_status = 'ended'
     or subject.status = 'active'
   )
  where organization_subject.id = p_organization_subject_id
    and organization_subject.organization_id = v_organization_id
    and (
      v_status = 'ended'
      or organization_subject.status = 'active'
    )
  for update of organization_subject;

  if v_subject_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'organization_subject_not_found';
  end if;

  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'update_organization_teacher_subject_scope',
    'membership_subject_scope',
    operation_target_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  if v_status = 'active' then
    select scope.id
    into v_scope_id
    from public.membership_subject_scopes as scope
    where scope.organization_id = v_organization_id
      and scope.membership_id = target_membership.id
      and scope.organization_subject_id = p_organization_subject_id
      and scope.scope_kind = 'teaching'
      and scope.status = 'active'
    for update;

    if v_scope_id is not null then
      raise exception using
        errcode = 'P0001',
        message = 'teacher_subject_scope_already_active';
    end if;

    insert into public.membership_subject_scopes (
      organization_id,
      membership_id,
      organization_subject_id,
      scope_kind,
      status,
      active_from
    )
    values (
      v_organization_id,
      target_membership.id,
      p_organization_subject_id,
      'teaching',
      'active',
      v_business_date
    )
    returning id, version into v_scope_id, v_scope_version;
  else
    select *
    into target_scope
    from public.membership_subject_scopes as scope
    where scope.id = p_scope_id
      and scope.organization_id = v_organization_id
      and scope.membership_id = target_membership.id
      and scope.organization_subject_id = p_organization_subject_id
      and scope.scope_kind = 'teaching'
    for update;

    if not found then
      raise exception using
        errcode = 'P0001',
        message = 'teacher_subject_scope_not_found';
    end if;

    if target_scope.status <> 'active' then
      raise exception using
        errcode = 'P0001',
        message = 'teacher_subject_scope_not_active';
    end if;

    if target_scope.version <> p_expected_scope_version then
      raise exception using
        errcode = 'P0001',
        message = 'teacher_subject_scope_version_conflict';
    end if;

    if exists (
      select 1
      from public.student_teacher_assignments as assignment
      join public.student_subject_profiles as profile
        on profile.id = assignment.student_subject_profile_id
       and profile.organization_id = assignment.organization_id
      where assignment.organization_id = v_organization_id
        and assignment.membership_id = target_membership.id
        and assignment.status = 'active'
        and profile.organization_subject_id = p_organization_subject_id
    )
    or exists (
      select 1
      from public.learning_cases as learning_case
      join public.student_subject_profiles as profile
        on profile.id = learning_case.student_subject_profile_id
       and profile.organization_id = learning_case.organization_id
      where learning_case.organization_id = v_organization_id
        and learning_case.owner_membership_id = target_membership.id
        and learning_case.status <> 'closed'
        and profile.organization_subject_id = p_organization_subject_id
    )
    or exists (
      select 1
      from public.case_actions as action
      join public.learning_cases as learning_case
        on learning_case.id = action.learning_case_id
       and learning_case.organization_id = action.organization_id
      join public.student_subject_profiles as profile
        on profile.id = learning_case.student_subject_profile_id
       and profile.organization_id = learning_case.organization_id
      where action.organization_id = v_organization_id
        and action.assigned_membership_id = target_membership.id
        and action.status = 'pending'
        and learning_case.status <> 'closed'
        and profile.organization_subject_id = p_organization_subject_id
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'teacher_scope_handoff_required';
    end if;

    update public.membership_subject_scopes
    set status = 'ended',
        active_to = greatest(active_from, v_business_date)
    where id = target_scope.id
      and organization_id = v_organization_id;

    v_scope_id := target_scope.id;
    v_scope_version := target_scope.version + 1;
  end if;

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', v_organization_id,
    'membership_id', target_membership.id,
    'organization_subject_id', p_organization_subject_id,
    'scope_id', v_scope_id,
    'status', v_status,
    'version', v_scope_version,
    'active_from', case
      when v_status = 'active' then v_business_date
      else target_scope.active_from
    end,
    'active_to', case
      when v_status = 'active' then null
      else greatest(target_scope.active_from, v_business_date)
    end
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

revoke all on function public.list_organization_teacher_subject_scopes(uuid)
  from public;
grant execute on function public.list_organization_teacher_subject_scopes(uuid)
  to authenticated;
revoke execute on function public.list_organization_teacher_subject_scopes(uuid)
  from anon;

revoke all on function public.update_organization_teacher_subject_scope(
  uuid,
  uuid,
  uuid,
  uuid,
  uuid,
  integer,
  text
) from public;
grant execute on function public.update_organization_teacher_subject_scope(
  uuid,
  uuid,
  uuid,
  uuid,
  uuid,
  integer,
  text
) to authenticated;
revoke execute on function public.update_organization_teacher_subject_scope(
  uuid,
  uuid,
  uuid,
  uuid,
  uuid,
  integer,
  text
) from anon;
