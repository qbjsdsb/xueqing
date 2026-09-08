-- Quick Capture should preserve the classroom fact first.
-- A reminder / next Action is optional and should only exist when the teacher
-- explicitly asks for one. Existing callers that still pass an Action title
-- keep the old behavior.

create or replace function private.quick_capture_case_v2(
  p_operation_id uuid,
  p_profile_id uuid,
  p_expected_profile_version integer,
  p_case_type text,
  p_title text,
  p_description text,
  p_observed_at timestamptz,
  p_evidence_summary text,
  p_next_action_title text,
  p_next_action_due_at timestamptz,
  p_organization_case_type_id uuid
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
  membership_id uuid;
  case_id uuid := gen_random_uuid();
  evidence_id uuid;
  action_id uuid;
  event_id uuid;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
  custom_case_type_base text;
  custom_case_type_label text;
  normalized_action_title text := nullif(btrim(coalesce(p_next_action_title, '')), '');
begin
  if p_operation_id is null or p_profile_id is null
    or p_expected_profile_version is null
    or p_expected_profile_version <= 0 then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  if p_case_type is null
    or p_case_type not in ('knowledge', 'habit', 'exam_strategy', 'other')
    or p_title is null
    or char_length(btrim(p_title)) = 0
    or p_observed_at is null
    or p_evidence_summary is null
    or char_length(btrim(p_evidence_summary)) = 0
    or (normalized_action_title is null and p_next_action_due_at is not null) then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select profile.organization_id
  into v_organization_id
  from public.student_subject_profiles as profile
  where profile.id = p_profile_id
  for update;

  if v_organization_id is null then
    raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
  end if;

  if p_expected_profile_version <> (
    select profile.version
    from public.student_subject_profiles as profile
    where profile.id = p_profile_id
  ) then
    raise exception using errcode = 'P0001', message = 'version_conflict';
  end if;

  membership_id := (
    select private.current_teaching_membership_for_profile_v2(p_profile_id)
  );
  if membership_id is null then
    raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
  end if;

  if p_organization_case_type_id is not null then
    select case_type.base_case_type, case_type.display_name
    into custom_case_type_base, custom_case_type_label
    from public.organization_case_types as case_type
    where case_type.id = p_organization_case_type_id
      and case_type.organization_id = v_organization_id
      and case_type.status = 'active';

    if custom_case_type_label is null
      or custom_case_type_base is distinct from p_case_type then
      raise exception using errcode = 'P0001', message = 'invalid_case_type';
    end if;
  end if;

  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'quick_capture_case',
    'student_subject_profile',
    p_profile_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  insert into public.learning_cases (
    id,
    organization_id,
    student_subject_profile_id,
    owner_membership_id,
    case_type,
    organization_case_type_id,
    case_type_label_snapshot,
    title,
    description,
    priority,
    status,
    first_observed_at,
    created_by_app_user_id,
    created_by_membership_id
  )
  values (
    case_id,
    v_organization_id,
    p_profile_id,
    membership_id,
    p_case_type,
    p_organization_case_type_id,
    custom_case_type_label,
    btrim(p_title),
    nullif(btrim(p_description), ''),
    'normal',
    'new',
    p_observed_at,
    app_user_id,
    membership_id
  );

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
    v_organization_id,
    case_id,
    'observation',
    btrim(p_title),
    p_observed_at,
    btrim(p_evidence_summary),
    'finalized',
    app_user_id,
    membership_id
  )
  returning id into evidence_id;

  if normalized_action_title is not null then
    action_id := (
      select private.create_primary_case_action_v2(
        v_organization_id,
        case_id,
        membership_id,
        'review',
        normalized_action_title,
        p_next_action_due_at
      )
    );
  end if;

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
    case_id,
    'case_created',
    app_user_id,
    membership_id,
    jsonb_strip_nulls(jsonb_build_object(
      'profile_id', p_profile_id,
      'case_type', p_case_type,
      'organization_case_type_id', p_organization_case_type_id,
      'case_type_label', custom_case_type_label,
      'evidence_id', evidence_id,
      'action_id', action_id
    )),
    p_operation_id,
    'case_created'
  )
  returning id into event_id;

  perform private.assert_case_core_invariant_v2(case_id);

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', case_id,
    'evidence_id', evidence_id,
    'action_id', action_id,
    'event_id', event_id,
    'status', 'new',
    'case_version', 1
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

-- Keep the helper behind the existing guarded wrappers.
revoke all on function private.quick_capture_case_v2(
  uuid, uuid, integer, text, text, text, timestamptz, text, text,
  timestamptz, uuid
) from public, anon, authenticated, service_role;
