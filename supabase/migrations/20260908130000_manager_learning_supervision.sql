-- Manager learning supervision boundary.
--
-- Product contract:
--   * org_owner / org_admin can inspect and operate every active learning record
--     in their organization without requiring a student assignment or teaching
--     subject scope.
--   * teacher remains assignment + teaching-scope bound.
--   * manager edits must not silently steal a teacher's Case responsibility:
--     lifecycle events record the real manager actor, while an existing legal
--     Case owner / next-action assignee stays responsible unless the explicit
--     assignment handoff workflow changes responsibility.

create or replace function private.manager_membership_can_supervise_v2(
  target_organization_id uuid,
  target_membership_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.organization_memberships as membership
    join public.membership_roles as membership_role
      on membership_role.membership_id = membership.id
     and membership_role.organization_id = membership.organization_id
     and membership_role.role in ('org_owner', 'org_admin')
    join public.organizations as organization
      on organization.id = membership.organization_id
     and organization.status = 'active'
    where membership.id = target_membership_id
      and membership.organization_id = target_organization_id
      and membership.status = 'active'
  )
$function$;

create or replace function private.legal_case_responsibility_membership_v2(
  target_profile_id uuid,
  target_membership_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.student_subject_profiles as profile
    join public.students as student
      on student.id = profile.student_id
     and student.organization_id = profile.organization_id
     and student.status = 'active'
    join public.organizations as organization
      on organization.id = profile.organization_id
     and organization.status = 'active'
    join public.organization_subjects as organization_subject
      on organization_subject.id = profile.organization_subject_id
     and organization_subject.organization_id = profile.organization_id
     and organization_subject.status = 'active'
    join public.organization_memberships as membership
      on membership.id = target_membership_id
     and membership.organization_id = profile.organization_id
     and membership.status = 'active'
    where profile.id = target_profile_id
      and profile.status = 'active'
      and (
        exists (
          select 1
          from public.membership_roles as manager_role
          where manager_role.membership_id = membership.id
            and manager_role.organization_id = membership.organization_id
            and manager_role.role in ('org_owner', 'org_admin')
        )
        or (
          exists (
            select 1
            from public.membership_roles as teacher_role
            where teacher_role.membership_id = membership.id
              and teacher_role.organization_id = membership.organization_id
              and teacher_role.role = 'teacher'
          )
          and exists (
            select 1
            from public.student_teacher_assignments as assignment
            where assignment.student_subject_profile_id = profile.id
              and assignment.organization_id = profile.organization_id
              and assignment.membership_id = membership.id
              and assignment.status = 'active'
          )
          and exists (
            select 1
            from public.membership_subject_scopes as scope
            where scope.membership_id = membership.id
              and scope.organization_id = membership.organization_id
              and scope.organization_subject_id = profile.organization_subject_id
              and scope.scope_kind = 'teaching'
              and scope.status = 'active'
          )
        )
      )
  )
$function$;

create or replace function private.resolve_case_responsibility_membership_v2(
  target_profile_id uuid,
  current_owner_membership_id uuid,
  actor_membership_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  target_organization_id uuid;
begin
  select profile.organization_id
  into target_organization_id
  from public.student_subject_profiles as profile
  where profile.id = target_profile_id
  limit 1;

  if target_organization_id is null then
    return actor_membership_id;
  end if;

  if (select private.manager_membership_can_supervise_v2(
        target_organization_id,
        actor_membership_id
      ))
    and current_owner_membership_id is not null
    and (select private.legal_case_responsibility_membership_v2(
      target_profile_id,
      current_owner_membership_id
    )) then
    return current_owner_membership_id;
  end if;

  return actor_membership_id;
end
$function$;

revoke all on function private.manager_membership_can_supervise_v2(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.legal_case_responsibility_membership_v2(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.resolve_case_responsibility_membership_v2(
  uuid, uuid, uuid
) from public, anon, authenticated, service_role;

create or replace function private.assert_case_core_invariant_v2(
  target_case_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  case_status text;
  case_organization_id uuid;
  profile_id uuid;
  profile_status text;
  owner_id uuid;
  pending_primary_count integer;
begin
  select
    learning_case.status,
    learning_case.organization_id,
    learning_case.student_subject_profile_id,
    learning_case.owner_membership_id
  into
    case_status,
    case_organization_id,
    profile_id,
    owner_id
  from public.learning_cases as learning_case
  where learning_case.id = target_case_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'case_not_found';
  end if;

  select profile.status
  into profile_status
  from public.student_subject_profiles as profile
  where profile.id = profile_id
    and profile.organization_id = case_organization_id;

  select count(*)::integer
  into pending_primary_count
  from public.case_actions as action
  where action.learning_case_id = target_case_id
    and action.status = 'pending'
    and action.is_primary;

  if case_status in (
    'confirmed',
    'intervening',
    'pending_verification',
    'stable'
  ) and profile_status = 'active' then
    if owner_id is null or pending_primary_count <> 1 then
      raise exception using
        errcode = 'P0001',
        message = 'case_open_invariant';
    end if;

    if not (select private.legal_case_responsibility_membership_v2(
      profile_id,
      owner_id
    )) then
      raise exception using
        errcode = 'P0001',
        message = 'case_owner_not_legal';
    end if;
  elsif case_status = 'closed' and pending_primary_count <> 0 then
    raise exception using
      errcode = 'P0001',
      message = 'closed_case_has_pending_action';
  end if;
end
$function$;

create or replace function private.create_primary_case_action_v2(
  target_organization_id uuid,
  target_case_id uuid,
  assigned_membership_id uuid,
  action_type text,
  action_title text,
  action_due_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  action_id uuid;
  target_profile_id uuid;
  current_owner_membership_id uuid;
  resolved_assigned_membership_id uuid := assigned_membership_id;
begin
  if action_title is null or char_length(btrim(action_title)) = 0 then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_next_action';
  end if;

  select
    learning_case.student_subject_profile_id,
    learning_case.owner_membership_id
  into
    target_profile_id,
    current_owner_membership_id
  from public.learning_cases as learning_case
  where learning_case.id = target_case_id
    and learning_case.organization_id = target_organization_id;

  if target_profile_id is not null then
    resolved_assigned_membership_id := (
      select private.resolve_case_responsibility_membership_v2(
        target_profile_id,
        current_owner_membership_id,
        assigned_membership_id
      )
    );
  end if;

  insert into public.case_actions (
    organization_id,
    learning_case_id,
    assigned_membership_id,
    action_type,
    title,
    due_at,
    is_primary,
    status
  )
  values (
    target_organization_id,
    target_case_id,
    resolved_assigned_membership_id,
    action_type,
    action_title,
    action_due_at,
    true,
    'pending'
  )
  returning id into action_id;

  return action_id;
end
$function$;

-- Keep public signatures stable while correcting the three legacy command bodies
-- that still coupled manager authority to teacher ownership/lead assignment.
do $patch_confirm$
declare
  function_definition text;
  old_fragment text := 'set owner_membership_id = membership_id,';
  new_fragment text := 'set owner_membership_id = private.resolve_case_responsibility_membership_v2(profile_id, owner_membership_id, membership_id),';
begin
  select pg_get_functiondef(
    'private.confirm_case(uuid,uuid,integer,text,timestamptz)'::regprocedure
  ) into function_definition;

  if (length(function_definition) - length(replace(function_definition, old_fragment, '')))
      / length(old_fragment) <> 1 then
    raise exception 'confirm_case ownership patch precondition failed';
  end if;

  execute replace(function_definition, old_fragment, new_fragment);
end
$patch_confirm$;

do $patch_close$
declare
  function_definition text;
  old_fragment text := '  if not exists (';
  new_fragment text := '  if not (select private.can_manage_organization_v2(v_organization_id))\n    and not exists (';
begin
  select pg_get_functiondef(
    'private.close_case(uuid,uuid,integer,timestamptz)'::regprocedure
  ) into function_definition;

  if (length(function_definition) - length(replace(function_definition, old_fragment, '')))
      / length(old_fragment) <> 1 then
    raise exception 'close_case manager override patch precondition failed';
  end if;

  execute replace(function_definition, old_fragment, new_fragment);
end
$patch_close$;

do $patch_reopen$
declare
  function_definition text;
  old_gate_fragment text := '  if not exists (';
  new_gate_fragment text := '  if not (select private.can_manage_organization_v2(v_organization_id))\n    and not exists (';
  old_owner_fragment text := 'owner_membership_id = v_membership_id,';
  new_owner_fragment text := 'owner_membership_id = private.resolve_case_responsibility_membership_v2(v_profile_id, owner_membership_id, v_membership_id),';
begin
  select pg_get_functiondef(
    'private.reopen_case_v2(uuid,uuid,integer,uuid[],jsonb,text,text,date)'::regprocedure
  ) into function_definition;

  if (length(function_definition) - length(replace(function_definition, old_gate_fragment, '')))
      / length(old_gate_fragment) <> 1 then
    raise exception 'reopen_case manager override patch precondition failed';
  end if;
  if (length(function_definition) - length(replace(function_definition, old_owner_fragment, '')))
      / length(old_owner_fragment) <> 1 then
    raise exception 'reopen_case ownership patch precondition failed';
  end if;

  function_definition := replace(
    function_definition,
    old_gate_fragment,
    new_gate_fragment
  );
  function_definition := replace(
    function_definition,
    old_owner_fragment,
    new_owner_fragment
  );
  execute function_definition;
end
$patch_reopen$;

comment on function private.manager_membership_can_supervise_v2(uuid, uuid) is
  'Returns whether a membership is an active owner/admin learning supervisor for an organization.';
comment on function private.legal_case_responsibility_membership_v2(uuid, uuid) is
  'Legal Case responsibility: active owner/admin, or teacher with active assignment and teaching scope.';
comment on function private.resolve_case_responsibility_membership_v2(uuid, uuid, uuid) is
  'Manager edits preserve an existing legal Case owner; ordinary teacher edits keep the acting teacher responsible.';
