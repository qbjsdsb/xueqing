-- Allow a teacher to finish a real reminder without inventing a new learning fact
-- or being forced to create another reminder.
--
-- Backward compatibility:
--   * the public/private RPC signatures stay unchanged;
--   * callers may still pass a complete next-action tuple and get the old behavior;
--   * passing NULL for type/title/due date now means "complete only".
--
-- This is safe after the progressive Case workflow because an open Case may have
-- zero or one pending primary Action.

create or replace function private.complete_case_action_v2(
  p_operation_id uuid,
  p_action_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_expected_action_version integer,
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
  profile_id uuid;
  organization_time_zone text;
  membership_id uuid;
  case_status text;
  case_version integer;
  action_version integer;
  action_status text;
  action_is_primary boolean;
  completed_action_id uuid;
  next_action_id uuid;
  event_id uuid;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
  has_next_action boolean := p_next_action_type is not null
    or p_next_action_title is not null
    or p_next_action_due_on is not null;
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

  if has_next_action then
    if p_next_action_type is null
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
    organization.time_zone
  into
    v_organization_id,
    profile_id,
    case_status,
    case_version,
    action_version,
    action_status,
    action_is_primary,
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
  where profile.id = profile_id
    and profile.organization_id = v_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'action_not_found';
  end if;

  membership_id := (
    select private.current_teaching_membership_for_profile_v2(profile_id)
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
    'complete_case_action',
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

  if case_status = 'closed' then
    raise exception using
      errcode = 'P0001',
      message = 'case_closed';
  end if;

  if case_status not in (
    'confirmed',
    'intervening',
    'pending_verification',
    'stable'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'case_transition_not_allowed';
  end if;

  if action_status <> 'pending' or not action_is_primary then
    raise exception using
      errcode = 'P0001',
      message = 'action_not_pending';
  end if;

  completed_action_id := (
    select private.finish_primary_case_action_if_present_v2(
      p_case_id,
      membership_id,
      timezone('utc', now()),
      'done'
    )
  );

  if completed_action_id is distinct from p_action_id then
    raise exception using
      errcode = 'P0001',
      message = 'action_not_pending';
  end if;

  if has_next_action then
    next_action_id := (
      select private.create_primary_case_action_v2(
        v_organization_id,
        p_case_id,
        membership_id,
        p_next_action_type,
        btrim(p_next_action_title),
        case
          when p_next_action_due_on is null then null
          else (
            p_next_action_due_on::timestamp without time zone
            at time zone organization_time_zone
          )
        end
      )
    );
  end if;

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
    'action_completed',
    app_user_id,
    membership_id,
    jsonb_strip_nulls(jsonb_build_object(
      'completed_action_id', completed_action_id,
      'next_action_id', next_action_id
    )),
    p_operation_id,
    'action_completed'
  )
  returning id into event_id;

  perform private.assert_case_core_invariant_v2(p_case_id);

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', p_case_id,
    'action_id', next_action_id,
    'completed_action_id', completed_action_id,
    'event_id', event_id,
    'status', case_status,
    'case_version', case_version + 1,
    'completed_action_version', action_version + 1,
    'next_action_version', case when next_action_id is null then null else 1 end
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;
