-- Phase 0B.0-M: allow a teacher to change the date of the
-- current primary Action without bypassing the Case command loop.
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
    'reschedule_case_action'
  ));

alter table public.operation_receipts
  drop constraint if exists operation_receipts_target_type_check;

alter table public.operation_receipts
  add constraint operation_receipts_target_type_check
  check (target_type in (
    'student_subject_profile',
    'learning_case',
    'case_action'
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
    'action_rescheduled'
  ));

create or replace function public.reschedule_case_action(
  p_operation_id uuid,
  p_action_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_expected_action_version integer,
  p_due_on date
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
  case_status text;
  case_version integer;
  action_version integer;
  action_status text;
  action_is_primary boolean;
  action_due_at timestamptz;
  organization_time_zone text;
  membership_id uuid;
  new_due_at timestamptz;
  event_id uuid;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
begin
  if p_operation_id is null
    or p_action_id is null
    or p_case_id is null
    or p_expected_case_version is null
    or p_expected_case_version <= 0
    or p_expected_action_version is null
    or p_expected_action_version <= 0 then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_command_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select
    action.organization_id,
    learning_case.student_subject_profile_id,
    learning_case.status,
    learning_case.version,
    action.version,
    action.status,
    action.is_primary,
    action.due_at,
    organization.time_zone
  into
    v_organization_id,
    v_profile_id,
    case_status,
    case_version,
    action_version,
    action_status,
    action_is_primary,
    action_due_at,
    organization_time_zone
  from public.case_actions as action
  join public.learning_cases as learning_case
    on learning_case.id = action.learning_case_id
   and learning_case.organization_id = action.organization_id
  join public.organizations as organization
    on organization.id = action.organization_id
  where action.id = p_action_id
    and action.learning_case_id = p_case_id
  for update of action, learning_case;

  if v_organization_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'action_not_found';
  end if;

  perform 1
  from public.student_subject_profiles as profile
  where profile.id = v_profile_id
    and profile.organization_id = v_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'action_not_found';
  end if;

  membership_id := (
    select private.current_teaching_membership_for_profile_v2(v_profile_id)
  );
  if membership_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'teaching_fact_gate';
  end if;

  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'reschedule_case_action',
    'case_action',
    p_action_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  if case_version <> p_expected_case_version
    or action_version <> p_expected_action_version then
    raise exception using
      errcode = 'P0001',
      message = 'version_conflict';
  end if;

  if case_status = 'closed'
    or action_status <> 'pending'
    or not action_is_primary then
    raise exception using
      errcode = 'P0001',
      message = 'action_not_pending';
  end if;

  new_due_at := case
    when p_due_on is null then null
    else (
      p_due_on::timestamp without time zone
      at time zone organization_time_zone
    )
  end;

  update public.case_actions
  set due_at = new_due_at,
      version = version + 1,
      updated_at = timezone('utc', now())
  where id = p_action_id;

  update public.learning_cases
  set version = version + 1,
      updated_at = timezone('utc', now())
  where id = p_case_id;

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
    v_organization_id,
    p_case_id,
    'action_rescheduled',
    app_user_id,
    membership_id,
    jsonb_build_object(
      'action_id', p_action_id,
      'previous_due_at', action_due_at,
      'due_on', p_due_on,
      'due_at', new_due_at
    ),
    p_operation_id,
    'action_rescheduled'
  )
  returning id into event_id;

  perform private.assert_case_core_invariant_v2(p_case_id);

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', p_case_id,
    'action_id', p_action_id,
    'event_id', event_id,
    'status', case_status,
    'case_version', case_version + 1,
    'action_version', action_version + 1,
    'due_at', new_due_at
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

revoke all on function public.reschedule_case_action(
  uuid,
  uuid,
  uuid,
  integer,
  integer,
  date
) from public;

grant execute on function public.reschedule_case_action(
  uuid,
  uuid,
  uuid,
  integer,
  integer,
  date
) to authenticated;

revoke execute on function public.reschedule_case_action(
  uuid,
  uuid,
  uuid,
  integer,
  integer,
  date
) from anon;
