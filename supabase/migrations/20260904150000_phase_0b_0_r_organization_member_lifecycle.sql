-- Phase 0B.0-R: manage organization member status with an explicit
-- teaching handoff. Disabling a member ends active scopes and assignments
-- in the same transaction; restoring access never silently restores them.
-- This is a fictional/local compatibility migration. It is not a
-- production migration or permission to import real student data.

alter table public.organization_memberships
  add column if not exists version integer not null default 1;

alter table public.organization_memberships
  drop constraint if exists organization_memberships_version_check;

alter table public.organization_memberships
  add constraint organization_memberships_version_check
  check (version > 0);

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
    'update_organization_membership_status'
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
    'membership'
  ));

create or replace function public.list_organization_members(
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
    'app_user_id', app_user.id,
    'membership_id', membership.id,
    'email', coalesce(auth_user.email, ''),
    'display_name', app_user.display_name,
    'status', membership.status,
    'version', membership.version,
    'onboarding_expires_at', membership.onboarding_expires_at,
    'roles', coalesce(
      (
        select jsonb_agg(
          membership_role.role
          order by membership_role.role
        )
        from public.membership_roles as membership_role
        where membership_role.membership_id = membership.id
          and membership_role.organization_id = membership.organization_id
      ),
      '[]'::jsonb
    )
  )
  from public.organization_memberships as membership
  join public.app_users as app_user
    on app_user.id = membership.app_user_id
  left join auth.users as auth_user
    on auth_user.id::text = app_user.auth_subject_id
   and app_user.auth_provider = 'supabase'
  where membership.organization_id = p_organization_id
  order by app_user.display_name, auth_user.email;
end
$function$;

create or replace function public.update_organization_membership_status(
  p_operation_id uuid,
  p_organization_id uuid,
  p_membership_id uuid,
  p_expected_membership_version integer,
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
  target_membership public.organization_memberships%rowtype;
  current_membership_id uuid;
  target_is_owner boolean;
  caller_is_owner boolean;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
  ended_scope_count integer := 0;
  ended_assignment_count integer := 0;
begin
  v_status := nullif(btrim(coalesce(p_status, '')), '');

  if p_operation_id is null
    or p_organization_id is null
    or p_membership_id is null
    or p_expected_membership_version is null
    or p_expected_membership_version <= 0
    or v_status is null
    or v_status not in ('active', 'disabled') then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_membership_status_input';
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

  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'update_organization_membership_status',
    'membership',
    p_membership_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  if target_membership.version <> p_expected_membership_version then
    raise exception using
      errcode = 'P0001',
      message = 'membership_version_conflict';
  end if;

  if target_membership.app_user_id = app_user_id then
    raise exception using
      errcode = 'P0001',
      message = 'current_membership_immutable';
  end if;

  current_membership_id := (
    select private.current_membership_for_organization_v2(
      v_organization_id
    )
  );
  target_is_owner := exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.membership_id = target_membership.id
      and membership_role.organization_id = v_organization_id
      and membership_role.role = 'org_owner'
  );
  caller_is_owner := exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.membership_id = current_membership_id
      and membership_role.organization_id = v_organization_id
      and membership_role.role = 'org_owner'
  );

  if target_is_owner and not caller_is_owner then
    raise exception using
      errcode = 'P0001',
      message = 'organization_owner_required';
  end if;

  if target_membership.status = v_status then
    raise exception using
      errcode = 'P0001',
      message = 'membership_status_unchanged';
  end if;

  if v_status = 'active' and target_membership.status <> 'disabled' then
    raise exception using
      errcode = 'P0001',
      message = 'membership_status_transition_invalid';
  end if;

  if v_status = 'disabled'
    and target_membership.status not in ('active', 'onboarding') then
    raise exception using
      errcode = 'P0001',
      message = 'membership_status_transition_invalid';
  end if;

  if v_status = 'disabled' and target_is_owner then
    if (
      select count(*)
      from public.organization_memberships as membership
      join public.membership_roles as membership_role
        on membership_role.membership_id = membership.id
       and membership_role.organization_id = membership.organization_id
       and membership_role.role = 'org_owner'
      where membership.organization_id = v_organization_id
        and membership.status = 'active'
    ) <= 1 then
      raise exception using
        errcode = 'P0001',
        message = 'last_owner_immutable';
    end if;
  end if;

  if v_status = 'disabled'
    and (
      exists (
        select 1
        from public.learning_cases as learning_case
        where learning_case.organization_id = v_organization_id
          and learning_case.owner_membership_id = target_membership.id
          and learning_case.status <> 'closed'
      )
      or exists (
        select 1
        from public.case_actions as action
        join public.learning_cases as learning_case
          on learning_case.id = action.learning_case_id
         and learning_case.organization_id = action.organization_id
        where action.organization_id = v_organization_id
          and action.assigned_membership_id = target_membership.id
          and action.status = 'pending'
          and learning_case.status <> 'closed'
      )
    ) then
    raise exception using
      errcode = 'P0001',
      message = 'membership_handoff_required';
  end if;

  if v_status = 'disabled' then
    update public.membership_subject_scopes as scope
    set status = 'ended',
        active_to = greatest(scope.active_from, v_business_date)
    where scope.organization_id = v_organization_id
      and scope.membership_id = target_membership.id
      and scope.status = 'active';
    get diagnostics ended_scope_count = row_count;

    update public.student_teacher_assignments as assignment
    set status = 'ended',
        active_to = greatest(assignment.active_from, v_business_date),
        ended_at = timezone('utc', now())
    where assignment.organization_id = v_organization_id
      and assignment.membership_id = target_membership.id
      and assignment.status = 'active';
    get diagnostics ended_assignment_count = row_count;
  end if;

  update public.organization_memberships as membership
  set status = v_status,
      version = version + 1,
      onboarding_expires_at = case
        when v_status = 'active' then null
        else membership.onboarding_expires_at
      end,
      updated_at = timezone('utc', now())
  where membership.id = target_membership.id
    and membership.organization_id = v_organization_id;

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', v_organization_id,
    'membership_id', target_membership.id,
    'app_user_id', target_membership.app_user_id,
    'status', v_status,
    'version', target_membership.version + 1,
    'ended_scope_count', ended_scope_count,
    'ended_assignment_count', ended_assignment_count
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

revoke all on function public.list_organization_members(uuid)
  from public;
grant execute on function public.list_organization_members(uuid)
  to authenticated;
revoke execute on function public.list_organization_members(uuid)
  from anon;

revoke all on function public.update_organization_membership_status(
  uuid,
  uuid,
  uuid,
  integer,
  text
) from public;
grant execute on function public.update_organization_membership_status(
  uuid,
  uuid,
  uuid,
  integer,
  text
) to authenticated;
revoke execute on function public.update_organization_membership_status(
  uuid,
  uuid,
  uuid,
  integer,
  text
) from anon;