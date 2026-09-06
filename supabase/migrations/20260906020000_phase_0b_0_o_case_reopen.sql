-- Phase 0B.0-O: server-authoritative reopening of a closed Learning Case.
-- A closed Case can reopen only from new, finalized Evidence observed after
-- the latest committed close boundary. This is still fictional/dev data only.

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
    'case_reopened'
  ));

alter table public.case_actions
  drop constraint if exists case_actions_review_due_check;

alter table public.case_actions
  add constraint case_actions_review_due_check
  check (action_type <> 'review' or due_at is not null);

create or replace function private.add_case_evidence(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_source_type text,
  p_title text,
  p_observed_at timestamptz,
  p_summary text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  close_occurred_at timestamptz;
  app_user_id uuid;
  organization_id uuid;
  profile_id uuid;
  membership_id uuid;
  case_status text;
  case_version integer;
  evidence_id uuid;
  event_id uuid;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
begin
  if p_operation_id is null or p_case_id is null
    or p_expected_case_version is null or p_expected_case_version <= 0
    or p_source_type is null or p_title is null
    or char_length(btrim(p_title)) = 0
    or p_observed_at is null or p_summary is null
    or char_length(btrim(p_summary)) = 0 then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select learning_case.organization_id, learning_case.student_subject_profile_id
  into organization_id, profile_id
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id;

  if organization_id is null then
    raise exception using errcode = 'P0001', message = 'case_not_found';
  end if;

  perform 1
  from public.student_subject_profiles as profile
  where profile.id = profile_id
  for update;

  membership_id := (
    select private.current_teaching_membership_for_profile_v2(profile_id)
  );
  if membership_id is null then
    raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
  end if;

  select learning_case.status, learning_case.version
  into case_status, case_version
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id
  for update;

  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    organization_id,
    p_operation_id,
    'add_case_evidence',
    'learning_case',
    p_case_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  if case_version <> p_expected_case_version then
    raise exception using errcode = 'P0001', message = 'version_conflict';
  end if;

  if case_status = 'closed' then
    select event.occurred_at
    into close_occurred_at
    from public.case_events as event
    join public.operation_receipts as receipt
      on receipt.organization_id = event.organization_id
     and receipt.operation_id = event.operation_id
     and receipt.command_type = 'close_case'
     and receipt.committed_at is not null
    where event.learning_case_id = p_case_id
      and event.event_type = 'case_closed'
      and event.operation_id is not null
      and event.operation_event_key = 'case_closed'
    order by receipt.committed_at desc, receipt.id desc
    limit 1
    for update of event;

    if close_occurred_at is null then
      raise exception using
        errcode = 'P0001',
        message = 'case_close_boundary_missing';
    end if;

    if p_observed_at <= close_occurred_at then
      raise exception using
        errcode = 'P0001',
        message = 'case_recurrence_before_close';
    end if;
  end if;

  if p_source_type not in (
    'exam',
    'homework',
    'essay',
    'classwork',
    'quiz',
    'observation',
    'guardian_report',
    'other'
  ) then
    raise exception using errcode = 'P0001', message = 'invalid_evidence_source';
  end if;

  insert into public.case_evidence (
    organization_id,
    learning_case_id,
    source_type,
    title,
    observed_at,
    summary,
    status,
    created_by_app_user_id,
    created_by_membership_id
  )
  values (
    organization_id,
    p_case_id,
    p_source_type,
    btrim(p_title),
    p_observed_at,
    btrim(p_summary),
    'finalized',
    app_user_id,
    membership_id
  )
  returning id into evidence_id;

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
    organization_id,
    p_case_id,
    'evidence_recorded',
    app_user_id,
    membership_id,
    jsonb_build_object('evidence_id', evidence_id),
    p_operation_id,
    'evidence_recorded'
  )
  returning id into event_id;

  perform private.assert_case_core_invariant_v2(p_case_id);

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', p_case_id,
    'evidence_id', evidence_id,
    'event_id', event_id,
    'status', case_status,
    'case_version', case_version
  );

  perform private.finish_case_operation_v2(
    organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

revoke all on function private.add_case_evidence(
  uuid,
  uuid,
  integer,
  text,
  text,
  timestamptz,
  text
) from public, anon, authenticated, service_role;
grant execute on function private.add_case_evidence(
  uuid,
  uuid,
  integer,
  text,
  text,
  timestamptz,
  text
) to service_role, authenticated;

create or replace function private.reopen_case_v2(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_recurrence_evidence_ids uuid[],
  p_expected_evidence_versions jsonb,
  p_next_action_type text,
  p_next_action_title text,
  p_next_action_due_on date
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
  v_profile_id uuid;
  v_membership_id uuid;
  v_case_status text;
  v_case_version integer;
  v_organization_time_zone text;
  v_is_claimed boolean;
  v_existing_result jsonb;
  v_close_event_id uuid;
  v_close_occurred_at timestamptz;
  v_evidence_id uuid;
  v_evidence_organization_id uuid;
  v_evidence_case_id uuid;
  v_evidence_status text;
  v_evidence_version integer;
  v_evidence_observed_at timestamptz;
  v_expected_evidence_version integer;
  v_locked_evidence_ids uuid[] := '{}'::uuid[];
  v_next_action_id uuid;
  v_event_id uuid;
  v_command_result jsonb;
begin
  if p_operation_id is null
    or p_case_id is null
    or p_expected_case_version is null
    or p_expected_case_version <= 0
    or p_next_action_type is null
    or p_next_action_type not in (
      'reteach',
      'practice',
      'verify',
      'communicate',
      'review',
      'other'
    )
    or p_next_action_title is null
    or char_length(btrim(p_next_action_title)) = 0 then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_command_input';
  end if;

  if p_recurrence_evidence_ids is null
    or cardinality(p_recurrence_evidence_ids) = 0
    or p_expected_evidence_versions is null
    or jsonb_typeof(p_expected_evidence_versions) <> 'object'
    or (select count(*) from jsonb_each(p_expected_evidence_versions))
      <> cardinality(p_recurrence_evidence_ids) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_recurrence_evidence';
  end if;

  if p_next_action_type = 'review'
    and p_next_action_due_on is null then
    raise exception using
      errcode = 'P0001',
      message = 'review_due_date_required';
  end if;

  if exists (
    select 1
    from unnest(p_recurrence_evidence_ids) as selected(evidence_id)
    where selected.evidence_id is null
  ) or exists (
    select selected.evidence_id
    from unnest(p_recurrence_evidence_ids) as selected(evidence_id)
    group by selected.evidence_id
    having count(*) > 1
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_recurrence_evidence';
  end if;

  if exists (
    select 1
    from unnest(p_recurrence_evidence_ids) as selected(evidence_id)
    where not (p_expected_evidence_versions ? (selected.evidence_id::text))
  ) or exists (
    select key
    from jsonb_object_keys(p_expected_evidence_versions) as expected(key)
    where not exists (
      select 1
      from unnest(p_recurrence_evidence_ids) as selected(evidence_id)
      where selected.evidence_id::text = expected.key
    )
  ) or exists (
    select 1
    from jsonb_each(p_expected_evidence_versions) as expected(key, value)
    where jsonb_typeof(expected.value) <> 'number'
      or expected.value::text !~ '^[1-9][0-9]{0,8}$'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_recurrence_evidence';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select
    learning_case.organization_id,
    learning_case.student_subject_profile_id
  into
    v_organization_id,
    v_profile_id
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id;

  if v_organization_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'case_not_found';
  end if;

  perform 1
  from public.student_subject_profiles as profile
  where profile.id = v_profile_id
    and profile.organization_id = v_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'case_not_found';
  end if;

  select learning_case.status, learning_case.version
  into v_case_status, v_case_version
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id
  for update;

  v_membership_id := (
    select private.current_teaching_membership_for_profile_v2(v_profile_id)
  );
  if v_membership_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'teaching_fact_gate';
  end if;

  if not exists (
    select 1
    from public.student_teacher_assignments as assignment
    where assignment.student_subject_profile_id = v_profile_id
      and assignment.organization_id = v_organization_id
      and assignment.membership_id = v_membership_id
      and assignment.assignment_role = 'lead'
      and assignment.status = 'active'
      and (now() at time zone (
        select organization.time_zone
        from public.organizations as organization
        where organization.id = v_organization_id
      ))::date >= assignment.active_from
      and (
        assignment.active_to is null
        or (now() at time zone (
          select organization.time_zone
          from public.organizations as organization
          where organization.id = v_organization_id
        ))::date <= assignment.active_to
      )
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'owner_permission_required';
  end if;

  select claimed, result
  into v_is_claimed, v_existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'reopen_case',
    'learning_case',
    p_case_id
  );

  if not v_is_claimed then
    return v_existing_result;
  end if;

  if v_case_version <> p_expected_case_version then
    raise exception using
      errcode = 'P0001',
      message = 'version_conflict';
  end if;

  if v_case_status <> 'closed' then
    raise exception using
      errcode = 'P0001',
      message = 'case_transition_not_allowed';
  end if;

  if exists (
    select 1
    from public.case_actions as action
    where action.learning_case_id = p_case_id
      and action.status = 'pending'
      and action.is_primary
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'closed_case_has_pending_action';
  end if;

  select
    event.id,
    event.occurred_at
  into
    v_close_event_id,
    v_close_occurred_at
  from public.case_events as event
  join public.operation_receipts as receipt
    on receipt.organization_id = event.organization_id
   and receipt.operation_id = event.operation_id
   and receipt.command_type = 'close_case'
   and receipt.committed_at is not null
  where event.learning_case_id = p_case_id
    and event.event_type = 'case_closed'
    and event.operation_id is not null
    and event.operation_event_key = 'case_closed'
  order by receipt.committed_at desc, receipt.id desc
  limit 1
  for update of event;

  if v_close_event_id is null or v_close_occurred_at is null then
    raise exception using
      errcode = 'P0001',
      message = 'case_close_boundary_missing';
  end if;

  for v_evidence_id in
    select selected.evidence_id
    from unnest(p_recurrence_evidence_ids) as selected(evidence_id)
    order by selected.evidence_id
  loop
    select
      evidence.organization_id,
      evidence.learning_case_id,
      evidence.status,
      evidence.version,
      evidence.observed_at
    into
      v_evidence_organization_id,
      v_evidence_case_id,
      v_evidence_status,
      v_evidence_version,
      v_evidence_observed_at
    from public.case_evidence as evidence
    where evidence.id = v_evidence_id
    for update;

    if not found
      or v_evidence_organization_id <> v_organization_id
      or v_evidence_case_id <> p_case_id then
      raise exception using
        errcode = 'P0001',
        message = 'evidence_not_found';
    end if;

    if v_evidence_status <> 'finalized' then
      raise exception using
        errcode = 'P0001',
        message = 'evidence_not_finalized';
    end if;

    v_expected_evidence_version := (
      p_expected_evidence_versions ->> (v_evidence_id::text)
    )::integer;

    if v_evidence_version <> v_expected_evidence_version then
      raise exception using
        errcode = 'P0001',
        message = 'evidence_version_conflict';
    end if;

    if v_evidence_observed_at <= v_close_occurred_at then
      raise exception using
        errcode = 'P0001',
        message = 'case_recurrence_before_close';
    end if;

    v_locked_evidence_ids := array_append(
      v_locked_evidence_ids,
      v_evidence_id
    );
  end loop;

  select organization.time_zone
  into v_organization_time_zone
  from public.organizations as organization
  where organization.id = v_organization_id;

  v_next_action_id := (
    select private.create_primary_case_action_v2(
      v_organization_id,
      p_case_id,
      v_membership_id,
      p_next_action_type,
      btrim(p_next_action_title),
      case
        when p_next_action_due_on is null then null
        else (
          p_next_action_due_on::timestamp without time zone
          at time zone v_organization_time_zone
        )
      end
    )
  );

  update public.learning_cases
  set status = 'confirmed',
      owner_membership_id = v_membership_id,
      stable_at = null,
      closed_at = null,
      reopened_count = reopened_count + 1,
      version = version + 1,
      updated_at = now()
  where id = p_case_id
    and version = p_expected_case_version;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'version_conflict';
  end if;

  insert into public.case_events (
    organization_id,
    learning_case_id,
    event_type,
    actor_app_user_id,
    actor_membership_id,
    occurred_at,
    metadata,
    operation_id,
    operation_event_key
  )
  values (
    v_organization_id,
    p_case_id,
    'case_reopened',
    app_user_id,
    v_membership_id,
    now(),
    jsonb_build_object(
      'previous_close_event_id', v_close_event_id,
      'previous_close_occurred_at', v_close_occurred_at,
      'recurrence_evidence_ids', to_jsonb(v_locked_evidence_ids),
      'next_action_id', v_next_action_id
    ),
    p_operation_id,
    'case_reopened'
  )
  returning id into v_event_id;

  perform private.assert_case_core_invariant_v2(p_case_id);

  v_command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', p_case_id,
    'evidence_id', v_locked_evidence_ids[1],
    'recurrence_evidence_ids', to_jsonb(v_locked_evidence_ids),
    'action_id', v_next_action_id,
    'event_id', v_event_id,
    'status', 'confirmed',
    'case_version', p_expected_case_version + 1
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    v_command_result
  );

  return v_command_result;
end
$function$;

revoke all on function private.reopen_case_v2(
  uuid,
  uuid,
  integer,
  uuid[],
  jsonb,
  text,
  text,
  date
) from public, anon, authenticated, service_role;
grant execute on function private.reopen_case_v2(
  uuid,
  uuid,
  integer,
  uuid[],
  jsonb,
  text,
  text,
  date
) to service_role, authenticated;

-- This service-role grant is needed by the inventory test; clients still use
-- the invoker wrapper below.
grant execute on function private.complete_case_action_v2(
  uuid,
  uuid,
  uuid,
  integer,
  integer,
  text,
  text,
  date
) to service_role;

create or replace function public.reopen_case(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_recurrence_evidence_ids uuid[],
  p_expected_evidence_versions jsonb,
  p_next_action_type text,
  p_next_action_title text,
  p_next_action_due_on date
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.reopen_case_v2(
    p_operation_id,
    p_case_id,
    p_expected_case_version,
    p_recurrence_evidence_ids,
    p_expected_evidence_versions,
    p_next_action_type,
    p_next_action_title,
    p_next_action_due_on
  )
$function$;

revoke all on function public.reopen_case(
  uuid,
  uuid,
  integer,
  uuid[],
  jsonb,
  text,
  text,
  date
) from public, anon, authenticated, service_role;
grant execute on function public.reopen_case(
  uuid,
  uuid,
  integer,
  uuid[],
  jsonb,
  text,
  text,
  date
) to service_role, authenticated;
