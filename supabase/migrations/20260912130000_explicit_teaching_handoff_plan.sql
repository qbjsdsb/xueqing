-- v0.3.8+: explicit, previewed teaching responsibility handoff.
--
-- A Student Teacher Assignment and the current Case/Action responsibility set
-- are separate business facts. When ending the Assignment would orphan current
-- responsibility, managers must preview the exact affected set and explicitly
-- confirm an atomic migration plan. Historical actors are never rewritten.

alter table public.case_events
  drop constraint if exists case_events_event_type_check;

alter table public.case_events
  add constraint case_events_event_type_check
  check (event_type in (
    'case_created',
    'case_confirmed',
    'evidence_recorded',
    'intervention_recorded',
    'assessment_recorded',
    'case_stabilized',
    'case_closed',
    'action_rescheduled',
    'action_completed',
    'case_reopened',
    'case_voided',
    'case_restored',
    'responsibility_handoff'
  ));

create or replace function private.organization_student_teacher_handoff_plan_v2(
  p_organization_id uuid,
  p_assignment_id uuid,
  p_replacement_membership_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_app_user_id uuid;
  v_business_date date;
  v_assignment public.student_teacher_assignments%rowtype;
  v_profile public.student_subject_profiles%rowtype;
  v_source_membership public.organization_memberships%rowtype;
  v_replacement_membership public.organization_memberships%rowtype;
  v_student_name text;
  v_student_status text;
  v_subject_name text;
  v_subject_code text;
  v_organization_subject_status text;
  v_subject_status text;
  v_source_teacher_name text;
  v_replacement_teacher_name text;
  v_replacement_scope_id uuid;
  v_cases jsonb;
  v_actions jsonb;
begin
  if p_organization_id is null
    or p_assignment_id is null
    or p_replacement_membership_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_student_teacher_handoff_input';
  end if;

  v_app_user_id := (select private.current_app_user_id_v2());
  if v_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select (now() at time zone organization.time_zone)::date
  into v_business_date
  from public.organizations as organization
  where organization.id = p_organization_id
    and organization.status = 'active';

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'organization_not_found';
  end if;

  if not (select private.can_manage_organization_v2(p_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  select *
  into v_assignment
  from public.student_teacher_assignments as assignment
  where assignment.id = p_assignment_id
    and assignment.organization_id = p_organization_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'student_teacher_assignment_not_found';
  end if;

  if v_assignment.membership_id = p_replacement_membership_id then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_assignment_same_teacher';
  end if;

  if v_assignment.status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'student_teacher_assignment_not_active';
  end if;

  if v_assignment.active_from > v_business_date
    or (
      v_assignment.active_to is not null
      and v_assignment.active_to < v_business_date
    ) then
    raise exception using
      errcode = 'P0001',
      message = 'student_teacher_assignment_not_current';
  end if;

  select *
  into v_profile
  from public.student_subject_profiles as profile
  where profile.id = v_assignment.student_subject_profile_id
    and profile.organization_id = p_organization_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_profile_not_found';
  end if;

  if v_profile.status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'student_subject_profile_not_active';
  end if;

  select student.name, student.status
  into v_student_name, v_student_status
  from public.students as student
  where student.id = v_profile.student_id
    and student.organization_id = p_organization_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'student_not_found';
  end if;

  if v_student_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'student_not_active';
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
  where organization_subject.id = v_profile.organization_subject_id
    and organization_subject.organization_id = p_organization_id;

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

  select *
  into v_source_membership
  from public.organization_memberships as membership
  where membership.id = v_assignment.membership_id
    and membership.organization_id = p_organization_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'membership_not_found';
  end if;

  select *
  into v_replacement_membership
  from public.organization_memberships as membership
  where membership.id = p_replacement_membership_id
    and membership.organization_id = p_organization_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'replacement_teacher_membership_not_found';
  end if;

  if v_replacement_membership.status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_membership_not_active';
  end if;

  if not exists (
    select 1
    from public.app_users as app_user
    where app_user.id = v_replacement_membership.app_user_id
      and app_user.status = 'active'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_app_user_not_active';
  end if;

  if not exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.organization_id = p_organization_id
      and membership_role.membership_id = p_replacement_membership_id
      and membership_role.role = 'teacher'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_role_required';
  end if;

  select scope.id
  into v_replacement_scope_id
  from public.membership_subject_scopes as scope
  where scope.organization_id = p_organization_id
    and scope.membership_id = p_replacement_membership_id
    and scope.organization_subject_id = v_profile.organization_subject_id
    and scope.scope_kind = 'teaching'
    and scope.status = 'active'
    and scope.active_from <= v_business_date
    and (scope.active_to is null or scope.active_to >= v_business_date)
  order by scope.id
  limit 1;

  if v_replacement_scope_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_subject_scope_required';
  end if;

  if exists (
    select 1
    from public.student_teacher_assignments as assignment
    where assignment.organization_id = p_organization_id
      and assignment.student_subject_profile_id = v_profile.id
      and assignment.membership_id = p_replacement_membership_id
      and assignment.assignment_role = v_assignment.assignment_role
      and assignment.status = 'active'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_assignment_already_active';
  end if;

  select coalesce(
    nullif(btrim(app_user.display_name), ''),
    '未命名老师'
  )
  into v_source_teacher_name
  from public.app_users as app_user
  where app_user.id = v_source_membership.app_user_id;

  select coalesce(
    nullif(btrim(app_user.display_name), ''),
    '未命名老师'
  )
  into v_replacement_teacher_name
  from public.app_users as app_user
  where app_user.id = v_replacement_membership.app_user_id;

  with affected_cases as (
    select
      learning_case.id,
      learning_case.title,
      learning_case.status,
      learning_case.version,
      learning_case.owner_membership_id,
      (learning_case.owner_membership_id = v_assignment.membership_id)
        as moves_owner
    from public.learning_cases as learning_case
    where learning_case.organization_id = p_organization_id
      and learning_case.student_subject_profile_id = v_profile.id
      and learning_case.record_state = 'active'
      and learning_case.status <> 'closed'
      and (
        learning_case.owner_membership_id = v_assignment.membership_id
        or exists (
          select 1
          from public.case_actions as action
          where action.organization_id = p_organization_id
            and action.learning_case_id = learning_case.id
            and action.assigned_membership_id = v_assignment.membership_id
            and action.status = 'pending'
        )
      )
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', affected.id,
        'title', affected.title,
        'status', affected.status,
        'version', affected.version,
        'owner_membership_id', affected.owner_membership_id,
        'moves_owner', affected.moves_owner
      )
      order by affected.id
    ),
    '[]'::jsonb
  )
  into v_cases
  from affected_cases as affected;

  with affected_actions as (
    select
      action.id,
      action.learning_case_id,
      action.title,
      action.version
    from public.case_actions as action
    join public.learning_cases as learning_case
      on learning_case.id = action.learning_case_id
     and learning_case.organization_id = action.organization_id
    where action.organization_id = p_organization_id
      and learning_case.student_subject_profile_id = v_profile.id
      and learning_case.record_state = 'active'
      and learning_case.status <> 'closed'
      and action.assigned_membership_id = v_assignment.membership_id
      and action.status = 'pending'
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', affected.id,
        'case_id', affected.learning_case_id,
        'title', affected.title,
        'version', affected.version
      )
      order by affected.id
    ),
    '[]'::jsonb
  )
  into v_actions
  from affected_actions as affected;

  return jsonb_build_object(
    'organization_id', p_organization_id,
    'business_date', v_business_date,
    'student_subject_profile_id', v_profile.id,
    'student_id', v_profile.student_id,
    'student_name', v_student_name,
    'organization_subject_id', v_profile.organization_subject_id,
    'subject_name', v_subject_name,
    'subject_code', v_subject_code,
    'assignment_id', v_assignment.id,
    'assignment_role', v_assignment.assignment_role,
    'assignment_version', v_assignment.version,
    'source_membership_id', v_assignment.membership_id,
    'source_teacher_name', v_source_teacher_name,
    'replacement_membership_id', p_replacement_membership_id,
    'replacement_teacher_name', v_replacement_teacher_name,
    'replacement_scope_id', v_replacement_scope_id,
    'affected_cases', v_cases,
    'affected_actions', v_actions,
    'affected_case_count', jsonb_array_length(v_cases),
    'affected_action_count', jsonb_array_length(v_actions)
  );
end
$function$;

revoke all on function private.organization_student_teacher_handoff_plan_v2(
  uuid, uuid, uuid
) from public, anon, authenticated, service_role;
grant execute on function private.organization_student_teacher_handoff_plan_v2(
  uuid, uuid, uuid
) to authenticated;

create or replace function public.preview_organization_student_teacher_handoff(
  p_organization_id uuid,
  p_assignment_id uuid,
  p_replacement_membership_id uuid
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select private.organization_student_teacher_handoff_plan_v2(
    p_organization_id,
    p_assignment_id,
    p_replacement_membership_id
  )
$function$;

revoke all on function public.preview_organization_student_teacher_handoff(
  uuid, uuid, uuid
) from public, anon, authenticated, service_role;
grant execute on function public.preview_organization_student_teacher_handoff(
  uuid, uuid, uuid
) to authenticated;

create or replace function private.commit_organization_student_teacher_handoff_v2(
  p_operation_id uuid,
  p_organization_id uuid,
  p_assignment_id uuid,
  p_expected_assignment_version integer,
  p_replacement_membership_id uuid,
  p_expected_cases jsonb,
  p_expected_actions jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_app_user_id uuid;
  v_actor_membership_id uuid;
  v_is_claimed boolean;
  v_existing_result jsonb;
  v_plan jsonb;
  v_source_profile_id uuid;
  v_source_membership_id uuid;
  v_replacement_scope_id uuid;
  v_business_date date;
  v_source_assignment public.student_teacher_assignments%rowtype;
  v_ended_assignment_version integer;
  v_replacement_assignment_id uuid;
  v_replacement_assignment_version integer;
  v_case jsonb;
  v_event_ids jsonb := '[]'::jsonb;
  v_event_id uuid;
  v_command_result jsonb;
begin
  if p_operation_id is null
    or p_organization_id is null
    or p_assignment_id is null
    or p_expected_assignment_version is null
    or p_expected_assignment_version <= 0
    or p_replacement_membership_id is null
    or p_expected_cases is null
    or jsonb_typeof(p_expected_cases) <> 'array'
    or p_expected_actions is null
    or jsonb_typeof(p_expected_actions) <> 'array' then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_student_teacher_handoff_input';
  end if;

  v_app_user_id := (select private.current_app_user_id_v2());
  if v_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  perform 1
  from public.organizations as organization
  where organization.id = p_organization_id
    and organization.status = 'active'
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'organization_not_found';
  end if;

  if not (select private.can_manage_organization_v2(p_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  select claimed, result
  into v_is_claimed, v_existing_result
  from private.claim_case_operation_v2(
    p_organization_id,
    p_operation_id,
    'transfer_organization_student_teacher_assignment',
    'student_teacher_assignment',
    p_assignment_id
  );

  if not v_is_claimed then
    return v_existing_result;
  end if;

  -- First snapshot identifies the rows whose locks must be acquired. A second
  -- snapshot below is authoritative and is compared to the user-confirmed plan.
  v_plan := private.organization_student_teacher_handoff_plan_v2(
    p_organization_id,
    p_assignment_id,
    p_replacement_membership_id
  );

  v_source_profile_id := (v_plan ->> 'student_subject_profile_id')::uuid;
  v_source_membership_id := (v_plan ->> 'source_membership_id')::uuid;
  v_replacement_scope_id := (v_plan ->> 'replacement_scope_id')::uuid;
  v_business_date := (v_plan ->> 'business_date')::date;

  perform 1
  from public.organization_memberships as membership
  where membership.organization_id = p_organization_id
    and membership.id in (
      v_source_membership_id,
      p_replacement_membership_id
    )
  order by membership.id
  for update;

  perform 1
  from public.student_subject_profiles as profile
  where profile.id = v_source_profile_id
    and profile.organization_id = p_organization_id
  for update;

  select *
  into v_source_assignment
  from public.student_teacher_assignments as assignment
  where assignment.id = p_assignment_id
    and assignment.organization_id = p_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_handoff_plan_stale';
  end if;

  perform 1
  from public.membership_subject_scopes as scope
  where scope.id = v_replacement_scope_id
    and scope.organization_id = p_organization_id
  for update;

  perform 1
  from public.learning_cases as learning_case
  where learning_case.organization_id = p_organization_id
    and learning_case.student_subject_profile_id = v_source_profile_id
    and learning_case.record_state = 'active'
    and learning_case.status <> 'closed'
    and (
      learning_case.owner_membership_id = v_source_membership_id
      or exists (
        select 1
        from public.case_actions as action
        where action.organization_id = p_organization_id
          and action.learning_case_id = learning_case.id
          and action.assigned_membership_id = v_source_membership_id
          and action.status = 'pending'
      )
    )
  order by learning_case.id
  for update;

  perform 1
  from public.case_actions as action
  join public.learning_cases as learning_case
    on learning_case.id = action.learning_case_id
   and learning_case.organization_id = action.organization_id
  where action.organization_id = p_organization_id
    and learning_case.student_subject_profile_id = v_source_profile_id
    and learning_case.record_state = 'active'
    and learning_case.status <> 'closed'
    and action.assigned_membership_id = v_source_membership_id
    and action.status = 'pending'
  order by action.id
  for update of action;

  v_plan := private.organization_student_teacher_handoff_plan_v2(
    p_organization_id,
    p_assignment_id,
    p_replacement_membership_id
  );

  if (v_plan ->> 'assignment_version')::integer
      <> p_expected_assignment_version
    or v_plan -> 'affected_cases' <> p_expected_cases
    or v_plan -> 'affected_actions' <> p_expected_actions then
    raise exception using
      errcode = 'P0001',
      message = 'teacher_handoff_plan_stale';
  end if;

  select membership.id
  into v_actor_membership_id
  from public.organization_memberships as membership
  where membership.organization_id = p_organization_id
    and membership.app_user_id = v_app_user_id
    and membership.status = 'active'
  order by membership.id
  limit 1;

  if v_actor_membership_id is null
    or not (select private.manager_membership_can_supervise_v2(
      p_organization_id,
      v_actor_membership_id
    )) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  update public.student_teacher_assignments
  set status = 'ended',
      active_to = greatest(v_source_assignment.active_from, v_business_date),
      ended_at = timezone('utc', now())
  where id = p_assignment_id
    and organization_id = p_organization_id
  returning version into v_ended_assignment_version;

  insert into public.student_teacher_assignments (
    organization_id,
    student_subject_profile_id,
    membership_id,
    assignment_role,
    status,
    active_from
  )
  values (
    p_organization_id,
    v_source_profile_id,
    p_replacement_membership_id,
    v_source_assignment.assignment_role,
    'active',
    v_business_date
  )
  returning id, version
  into v_replacement_assignment_id, v_replacement_assignment_version;

  update public.case_actions as action
  set assigned_membership_id = p_replacement_membership_id,
      version = action.version + 1,
      updated_at = timezone('utc', now())
  where action.id in (
    select (item ->> 'id')::uuid
    from jsonb_array_elements(p_expected_actions) as item
  )
    and action.organization_id = p_organization_id
    and action.assigned_membership_id = v_source_membership_id
    and action.status = 'pending';

  update public.learning_cases as learning_case
  set owner_membership_id = case
        when learning_case.owner_membership_id = v_source_membership_id
          then p_replacement_membership_id
        else learning_case.owner_membership_id
      end,
      version = learning_case.version + 1,
      updated_at = timezone('utc', now())
  where learning_case.id in (
    select (item ->> 'id')::uuid
    from jsonb_array_elements(p_expected_cases) as item
  )
    and learning_case.organization_id = p_organization_id;

  for v_case in
    select value
    from jsonb_array_elements(p_expected_cases)
  loop
    insert into public.case_events (
      organization_id,
      learning_case_id,
      event_type,
      actor_app_user_id,
      actor_membership_id,
      metadata,
      operation_id,
      operation_event_key
    )
    values (
      p_organization_id,
      (v_case ->> 'id')::uuid,
      'responsibility_handoff',
      v_app_user_id,
      v_actor_membership_id,
      jsonb_build_object(
        'previous_membership_id', v_source_membership_id,
        'replacement_membership_id', p_replacement_membership_id,
        'previous_teacher_name', v_plan ->> 'source_teacher_name',
        'replacement_teacher_name', v_plan ->> 'replacement_teacher_name',
        'owner_transferred', coalesce((v_case ->> 'moves_owner')::boolean, false),
        'transferred_action_ids', coalesce((
          select jsonb_agg((action_item ->> 'id')::uuid order by action_item ->> 'id')
          from jsonb_array_elements(p_expected_actions) as action_item
          where action_item ->> 'case_id' = v_case ->> 'id'
        ), '[]'::jsonb)
      ),
      p_operation_id,
      'responsibility_handoff:' || (v_case ->> 'id')
    )
    returning id into v_event_id;

    v_event_ids := v_event_ids || jsonb_build_array(v_event_id);
    perform private.assert_case_core_invariant_v2((v_case ->> 'id')::uuid);
  end loop;

  v_command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', p_organization_id,
    'student_subject_profile_id', v_source_profile_id,
    'student_id', v_plan ->> 'student_id',
    'student_name', v_plan ->> 'student_name',
    'organization_subject_id', v_plan ->> 'organization_subject_id',
    'subject_name', v_plan ->> 'subject_name',
    'subject_code', v_plan ->> 'subject_code',
    'assignment_role', v_source_assignment.assignment_role,
    'previous_assignment_id', p_assignment_id,
    'previous_membership_id', v_source_membership_id,
    'previous_teacher_name', v_plan ->> 'source_teacher_name',
    'previous_teacher_email', '',
    'previous_assignment_version', v_ended_assignment_version,
    'replacement_assignment_id', v_replacement_assignment_id,
    'replacement_membership_id', p_replacement_membership_id,
    'replacement_teacher_name', v_plan ->> 'replacement_teacher_name',
    'replacement_teacher_email', '',
    'replacement_scope_id', v_plan ->> 'replacement_scope_id',
    'replacement_assignment_version', v_replacement_assignment_version,
    'status', 'transferred',
    'active_from', v_business_date,
    'transferred_case_count', jsonb_array_length(p_expected_cases),
    'transferred_action_count', jsonb_array_length(p_expected_actions),
    'handoff_event_ids', v_event_ids
  );

  perform private.finish_case_operation_v2(
    p_organization_id,
    p_operation_id,
    v_command_result
  );

  return v_command_result;
end
$function$;

revoke all on function private.commit_organization_student_teacher_handoff_v2(
  uuid, uuid, uuid, integer, uuid, jsonb, jsonb
) from public, anon, authenticated, service_role;
grant execute on function private.commit_organization_student_teacher_handoff_v2(
  uuid, uuid, uuid, integer, uuid, jsonb, jsonb
) to authenticated;

create or replace function public.commit_organization_student_teacher_handoff(
  p_operation_id uuid,
  p_organization_id uuid,
  p_assignment_id uuid,
  p_expected_assignment_version integer,
  p_replacement_membership_id uuid,
  p_expected_cases jsonb,
  p_expected_actions jsonb
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.commit_organization_student_teacher_handoff_v2(
    p_operation_id,
    p_organization_id,
    p_assignment_id,
    p_expected_assignment_version,
    p_replacement_membership_id,
    p_expected_cases,
    p_expected_actions
  )
$function$;

revoke all on function public.commit_organization_student_teacher_handoff(
  uuid, uuid, uuid, integer, uuid, jsonb, jsonb
) from public, anon, authenticated, service_role;
grant execute on function public.commit_organization_student_teacher_handoff(
  uuid, uuid, uuid, integer, uuid, jsonb, jsonb
) to authenticated;

comment on function public.preview_organization_student_teacher_handoff(
  uuid, uuid, uuid
) is
  'Returns the exact current Assignment + open Case + pending Action responsibility set that an explicit teaching handoff would migrate.';

comment on function public.commit_organization_student_teacher_handoff(
  uuid, uuid, uuid, integer, uuid, jsonb, jsonb
) is
  'Atomically transfers the current Assignment and only the user-confirmed current Case/Action responsibility set; any plan drift fails closed.';
