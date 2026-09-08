-- Progressive Case workflow: keep rigorous history while reducing teacher ceremony.
--
-- Product contract:
--   * closed means "current follow-up ended", not "must have reached stable first";
--   * an open Case may have zero or one pending primary Action;
--   * teachers can record a natural progress update and choose continue/remind/close
--     in one transaction;
--   * existing RC1 commands remain available for backward compatibility.

alter table public.learning_cases
  drop constraint if exists learning_cases_stable_at_check;

alter table public.learning_cases
  add constraint learning_cases_stable_at_check
  check (
    (status = 'stable' and stable_at is not null)
    or (status in ('new', 'confirmed', 'intervening', 'pending_verification')
      and stable_at is null)
    or status = 'closed'
  );

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
    'pause_organization_student_teaching',
    'resume_organization_student_teaching',
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
    'reopen_case',
    'end_case_follow_up',
    'record_case_progress'
  ));

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

  if pending_primary_count > 1 then
    raise exception using
      errcode = 'P0001',
      message = 'case_multiple_primary_actions';
  end if;

  if case_status in (
    'confirmed',
    'intervening',
    'pending_verification',
    'stable'
  ) and profile_status = 'active' then
    if owner_id is null then
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

create or replace function private.finish_primary_case_action_if_present_v2(
  target_case_id uuid,
  actor_membership_id uuid,
  finished_at timestamptz,
  final_status text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  action_id uuid;
begin
  if final_status not in ('done', 'cancelled') then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_action_final_status';
  end if;

  update public.case_actions as action
  set status = final_status,
      is_primary = false,
      completed_at = case
        when final_status = 'done' then coalesce(finished_at, timezone('utc', now()))
        else null
      end,
      completed_by_membership_id = case
        when final_status = 'done' then actor_membership_id
        else null
      end,
      cancelled_at = case
        when final_status = 'cancelled' then coalesce(finished_at, timezone('utc', now()))
        else null
      end,
      cancelled_by_membership_id = case
        when final_status = 'cancelled' then actor_membership_id
        else null
      end,
      version = action.version + 1,
      updated_at = timezone('utc', now())
  where action.learning_case_id = target_case_id
    and action.status = 'pending'
    and action.is_primary
  returning action.id into action_id;

  return action_id;
end
$function$;

revoke all on function private.finish_primary_case_action_if_present_v2(
  uuid, uuid, timestamptz, text
) from public, anon, authenticated, service_role;
grant execute on function private.finish_primary_case_action_if_present_v2(
  uuid, uuid, timestamptz, text
) to authenticated, service_role;

create or replace function private.end_case_follow_up_v2(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_reason text,
  p_note text,
  p_closed_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
  v_organization_id uuid;
  v_profile_id uuid;
  v_owner_membership_id uuid;
  v_membership_id uuid;
  v_case_status text;
  v_case_version integer;
  v_cancelled_action_id uuid;
  v_event_id uuid;
  v_is_claimed boolean;
  v_existing_result jsonb;
  v_command_result jsonb;
  v_closed_at timestamptz := coalesce(p_closed_at, timezone('utc', now()));
begin
  if p_operation_id is null
    or p_case_id is null
    or p_expected_case_version is null
    or p_expected_case_version <= 0
    or p_reason is null
    or p_reason not in ('resolved', 'pause_tracking', 'not_issue', 'other') then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select
    learning_case.organization_id,
    learning_case.student_subject_profile_id,
    learning_case.owner_membership_id,
    learning_case.status,
    learning_case.version
  into
    v_organization_id,
    v_profile_id,
    v_owner_membership_id,
    v_case_status,
    v_case_version
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id
  for update;

  if v_organization_id is null then
    raise exception using errcode = 'P0001', message = 'case_not_found';
  end if;

  perform 1
  from public.student_subject_profiles as profile
  where profile.id = v_profile_id
    and profile.organization_id = v_organization_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'case_not_found';
  end if;

  v_membership_id := (
    select private.current_teaching_membership_for_profile_v2(v_profile_id)
  );
  if v_membership_id is null then
    raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
  end if;

  if not (select private.can_manage_organization_v2(v_organization_id))
    and v_owner_membership_id <> v_membership_id then
    raise exception using errcode = 'P0001', message = 'owner_permission_required';
  end if;

  select claimed, result
  into v_is_claimed, v_existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'end_case_follow_up',
    'learning_case',
    p_case_id
  );

  if not v_is_claimed then
    return v_existing_result;
  end if;

  if v_case_version <> p_expected_case_version then
    raise exception using errcode = 'P0001', message = 'version_conflict';
  end if;

  if v_case_status = 'closed' then
    raise exception using errcode = 'P0001', message = 'case_already_closed';
  end if;

  v_cancelled_action_id := (
    select private.finish_primary_case_action_if_present_v2(
      p_case_id,
      v_membership_id,
      v_closed_at,
      'cancelled'
    )
  );

  update public.learning_cases
  set status = 'closed',
      closed_at = v_closed_at,
      version = version + 1,
      updated_at = timezone('utc', now())
  where id = p_case_id;

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
    'case_closed',
    app_user_id,
    v_membership_id,
    v_closed_at,
    jsonb_strip_nulls(jsonb_build_object(
      'previous_status', v_case_status,
      'closure_reason', p_reason,
      'closure_note', nullif(btrim(coalesce(p_note, '')), ''),
      'cancelled_action_id', v_cancelled_action_id
    )),
    p_operation_id,
    'case_closed'
  )
  returning id into v_event_id;

  perform private.assert_case_core_invariant_v2(p_case_id);

  v_command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', p_case_id,
    'event_id', v_event_id,
    'status', 'closed',
    'case_version', v_case_version + 1,
    'closure_reason', p_reason
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    v_command_result
  );

  return v_command_result;
end
$function$;

create or replace function public.end_case_follow_up(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_reason text,
  p_note text default null,
  p_closed_at timestamptz default null
)
returns jsonb
language sql
set search_path = ''
as $function$
  select private.end_case_follow_up_v2(
    p_operation_id,
    p_case_id,
    p_expected_case_version,
    p_reason,
    p_note,
    p_closed_at
  )
$function$;

revoke all on function private.end_case_follow_up_v2(
  uuid, uuid, integer, text, text, timestamptz
) from public, anon, authenticated, service_role;
grant execute on function private.end_case_follow_up_v2(
  uuid, uuid, integer, text, text, timestamptz
) to authenticated, service_role;
revoke all on function public.end_case_follow_up(
  uuid, uuid, integer, text, text, timestamptz
) from public, anon, authenticated, service_role;
grant execute on function public.end_case_follow_up(
  uuid, uuid, integer, text, text, timestamptz
) to authenticated, service_role;

create or replace function private.record_case_progress_v2(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_progress_kind text,
  p_summary text,
  p_assessment_result text,
  p_occurred_at timestamptz,
  p_complete_current_action boolean,
  p_current_action_id uuid,
  p_expected_action_version integer,
  p_next_step text,
  p_next_action_title text,
  p_next_action_due_on date,
  p_close_reason text,
  p_close_note text
)
returns jsonb
language plpgsql
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
  v_occurred_at timestamptz := coalesce(p_occurred_at, timezone('utc', now()));
  v_next_status text;
  v_action_version integer;
  v_action_status text;
  v_action_is_primary boolean;
  v_completed_action_id uuid;
  v_replaced_action_id uuid;
  v_next_action_id uuid;
  v_record_id uuid;
  v_progress_event_id uuid;
  v_action_event_id uuid;
  v_stable_event_id uuid;
  v_close_event_id uuid;
  v_is_claimed boolean;
  v_existing_result jsonb;
  v_command_result jsonb;
  v_default_action_type text;
  v_default_action_title text;
  v_effective_action_title text;
  v_auto_stable boolean := false;
begin
  if p_operation_id is null
    or p_case_id is null
    or p_expected_case_version is null
    or p_expected_case_version <= 0
    or p_progress_kind is null
    or p_progress_kind not in ('observation', 'intervention', 'assessment')
    or p_summary is null
    or char_length(btrim(p_summary)) = 0
    or p_next_step is null
    or p_next_step not in ('continue', 'remind', 'close') then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  if p_progress_kind = 'assessment' then
    if p_assessment_result is null
      or p_assessment_result not in ('passed', 'partial', 'not_passed') then
      raise exception using errcode = 'P0001', message = 'invalid_command_input';
    end if;
  elsif p_assessment_result is not null then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  if coalesce(p_complete_current_action, false) then
    if p_current_action_id is null
      or p_expected_action_version is null
      or p_expected_action_version <= 0 then
      raise exception using errcode = 'P0001', message = 'invalid_command_input';
    end if;
  elsif p_current_action_id is not null or p_expected_action_version is not null then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  if p_next_step = 'close' then
    if p_close_reason is null
      or p_close_reason not in ('resolved', 'pause_tracking', 'not_issue', 'other') then
      raise exception using errcode = 'P0001', message = 'invalid_command_input';
    end if;
  elsif p_close_reason is not null or p_close_note is not null then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select
    learning_case.organization_id,
    learning_case.student_subject_profile_id,
    learning_case.status,
    learning_case.version,
    organization.time_zone
  into
    v_organization_id,
    v_profile_id,
    v_case_status,
    v_case_version,
    v_organization_time_zone
  from public.learning_cases as learning_case
  join public.organizations as organization
    on organization.id = learning_case.organization_id
  where learning_case.id = p_case_id
  for update of learning_case;

  if v_organization_id is null then
    raise exception using errcode = 'P0001', message = 'case_not_found';
  end if;

  perform 1
  from public.student_subject_profiles as profile
  where profile.id = v_profile_id
    and profile.organization_id = v_organization_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'case_not_found';
  end if;

  v_membership_id := (
    select private.current_teaching_membership_for_profile_v2(v_profile_id)
  );
  if v_membership_id is null then
    raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
  end if;

  select claimed, result
  into v_is_claimed, v_existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'record_case_progress',
    'learning_case',
    p_case_id
  );

  if not v_is_claimed then
    return v_existing_result;
  end if;

  if v_case_version <> p_expected_case_version then
    raise exception using errcode = 'P0001', message = 'version_conflict';
  end if;

  if v_case_status = 'closed' then
    raise exception using errcode = 'P0001', message = 'case_closed';
  end if;

  if coalesce(p_complete_current_action, false) then
    select action.version, action.status, action.is_primary
    into v_action_version, v_action_status, v_action_is_primary
    from public.case_actions as action
    where action.id = p_current_action_id
      and action.learning_case_id = p_case_id
      and action.organization_id = v_organization_id
    for update;

    if v_action_version is null then
      raise exception using errcode = 'P0001', message = 'action_not_found';
    end if;
    if v_action_version <> p_expected_action_version then
      raise exception using errcode = 'P0001', message = 'version_conflict';
    end if;
    if v_action_status <> 'pending' or not v_action_is_primary then
      raise exception using errcode = 'P0001', message = 'action_not_pending';
    end if;

    update public.case_actions as action
    set status = 'done',
        is_primary = false,
        completed_at = v_occurred_at,
        completed_by_membership_id = v_membership_id,
        version = action.version + 1,
        updated_at = timezone('utc', now())
    where action.id = p_current_action_id
    returning action.id into v_completed_action_id;
  end if;

  if p_progress_kind = 'observation' then
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
      p_case_id,
      'observation',
      left(btrim(p_summary), 120),
      v_occurred_at,
      btrim(p_summary),
      'finalized',
      app_user_id,
      v_membership_id
    )
    returning id into v_record_id;

    v_next_status := case
      when v_case_status in ('new', 'stable') then 'confirmed'
      else v_case_status
    end;
  elsif p_progress_kind = 'intervention' then
    insert into public.interventions (
      organization_id,
      learning_case_id,
      performed_by_app_user_id,
      performed_by_membership_id,
      strategy,
      notes,
      occurred_at
    )
    values (
      v_organization_id,
      p_case_id,
      app_user_id,
      v_membership_id,
      btrim(p_summary),
      null,
      v_occurred_at
    )
    returning id into v_record_id;

    v_next_status := 'intervening';
  else
    insert into public.assessments (
      organization_id,
      learning_case_id,
      assessed_by_app_user_id,
      assessed_by_membership_id,
      result,
      evidence_summary,
      notes,
      assessed_at
    )
    values (
      v_organization_id,
      p_case_id,
      app_user_id,
      v_membership_id,
      p_assessment_result,
      btrim(p_summary),
      null,
      v_occurred_at
    )
    returning id into v_record_id;

    v_next_status := case
      when p_assessment_result = 'passed' then 'pending_verification'
      else 'intervening'
    end;
  end if;

  if p_next_step = 'remind' then
    if v_completed_action_id is null then
      v_replaced_action_id := (
        select private.finish_primary_case_action_if_present_v2(
          p_case_id,
          v_membership_id,
          v_occurred_at,
          'cancelled'
        )
      );
    end if;

    v_default_action_type := case
      when p_progress_kind = 'assessment' and p_assessment_result = 'passed' then 'review'
      when p_progress_kind = 'intervention' then 'verify'
      else 'review'
    end;
    v_default_action_title := case
      when p_progress_kind = 'assessment' and p_assessment_result = 'passed'
        then '再观察一次是否稳定'
      when p_progress_kind = 'intervention'
        then '再检查一次效果'
      else '继续观察这个问题'
    end;
    v_effective_action_title := coalesce(
      nullif(btrim(coalesce(p_next_action_title, '')), ''),
      v_default_action_title
    );

    v_next_action_id := (
      select private.create_primary_case_action_v2(
        v_organization_id,
        p_case_id,
        v_membership_id,
        v_default_action_type,
        v_effective_action_title,
        case
          when p_next_action_due_on is null then null
          else (
            p_next_action_due_on::timestamp without time zone
            at time zone v_organization_time_zone
          )
        end
      )
    );
  elsif p_next_step = 'close' then
    if v_completed_action_id is null then
      v_replaced_action_id := (
        select private.finish_primary_case_action_if_present_v2(
          p_case_id,
          v_membership_id,
          v_occurred_at,
          'cancelled'
        )
      );
    end if;
    v_auto_stable := p_close_reason = 'resolved'
      and p_progress_kind = 'assessment'
      and p_assessment_result = 'passed';
    v_next_status := 'closed';
  end if;

  update public.learning_cases
  set status = v_next_status,
      stable_at = case
        when p_next_step = 'close' and v_auto_stable
          then coalesce(stable_at, v_occurred_at)
        when p_next_step = 'close'
          then stable_at
        when v_next_status = 'stable'
          then coalesce(stable_at, v_occurred_at)
        else null
      end,
      closed_at = case
        when p_next_step = 'close' then v_occurred_at
        else null
      end,
      version = version + 1,
      updated_at = timezone('utc', now())
  where id = p_case_id;

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
    case p_progress_kind
      when 'observation' then 'evidence_recorded'
      when 'intervention' then 'intervention_recorded'
      else 'assessment_recorded'
    end,
    app_user_id,
    v_membership_id,
    v_occurred_at,
    jsonb_strip_nulls(jsonb_build_object(
      'record_id', v_record_id,
      'summary', btrim(p_summary),
      'assessment_result', p_assessment_result,
      'next_step', p_next_step,
      'completed_action_id', v_completed_action_id,
      'replaced_action_id', v_replaced_action_id,
      'next_action_id', v_next_action_id
    )),
    p_operation_id,
    'progress_recorded'
  )
  returning id into v_progress_event_id;

  if v_completed_action_id is not null then
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
      'action_completed',
      app_user_id,
      v_membership_id,
      v_occurred_at,
      jsonb_build_object(
        'completed_action_id', v_completed_action_id,
        'next_action_id', v_next_action_id
      ),
      p_operation_id,
      'action_completed'
    )
    returning id into v_action_event_id;
  end if;

  if p_next_step = 'close' and v_auto_stable then
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
      'case_stabilized',
      app_user_id,
      v_membership_id,
      v_occurred_at,
      jsonb_build_object('source', 'record_case_progress'),
      p_operation_id,
      'case_stabilized'
    )
    returning id into v_stable_event_id;
  end if;

  if p_next_step = 'close' then
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
      'case_closed',
      app_user_id,
      v_membership_id,
      v_occurred_at,
      jsonb_strip_nulls(jsonb_build_object(
        'previous_status', v_case_status,
        'closure_reason', p_close_reason,
        'closure_note', nullif(btrim(coalesce(p_close_note, '')), ''),
        'completed_action_id', v_completed_action_id,
        'cancelled_action_id', v_replaced_action_id
      )),
      p_operation_id,
      'case_closed'
    )
    returning id into v_close_event_id;
  end if;

  perform private.assert_case_core_invariant_v2(p_case_id);

  v_command_result := jsonb_strip_nulls(jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', p_case_id,
    'record_id', v_record_id,
    'progress_event_id', v_progress_event_id,
    'action_event_id', v_action_event_id,
    'stable_event_id', v_stable_event_id,
    'close_event_id', v_close_event_id,
    'completed_action_id', v_completed_action_id,
    'replaced_action_id', v_replaced_action_id,
    'next_action_id', v_next_action_id,
    'status', v_next_status,
    'case_version', v_case_version + 1,
    'next_step', p_next_step
  ));

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    v_command_result
  );

  return v_command_result;
end
$function$;

create or replace function public.record_case_progress(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_progress_kind text,
  p_summary text,
  p_assessment_result text default null,
  p_occurred_at timestamptz default null,
  p_complete_current_action boolean default false,
  p_current_action_id uuid default null,
  p_expected_action_version integer default null,
  p_next_step text default 'continue',
  p_next_action_title text default null,
  p_next_action_due_on date default null,
  p_close_reason text default null,
  p_close_note text default null
)
returns jsonb
language sql
set search_path = ''
as $function$
  select private.record_case_progress_v2(
    p_operation_id,
    p_case_id,
    p_expected_case_version,
    p_progress_kind,
    p_summary,
    p_assessment_result,
    p_occurred_at,
    p_complete_current_action,
    p_current_action_id,
    p_expected_action_version,
    p_next_step,
    p_next_action_title,
    p_next_action_due_on,
    p_close_reason,
    p_close_note
  )
$function$;

revoke all on function private.record_case_progress_v2(
  uuid, uuid, integer, text, text, text, timestamptz, boolean,
  uuid, integer, text, text, date, text, text
) from public, anon, authenticated, service_role;
grant execute on function private.record_case_progress_v2(
  uuid, uuid, integer, text, text, text, timestamptz, boolean,
  uuid, integer, text, text, date, text, text
) to authenticated, service_role;
revoke all on function public.record_case_progress(
  uuid, uuid, integer, text, text, text, timestamptz, boolean,
  uuid, integer, text, text, date, text, text
) from public, anon, authenticated, service_role;
grant execute on function public.record_case_progress(
  uuid, uuid, integer, text, text, text, timestamptz, boolean,
  uuid, integer, text, text, date, text, text
) to authenticated, service_role;

comment on function public.end_case_follow_up(
  uuid, uuid, integer, text, text, timestamptz
) is
  'Ends current follow-up from any non-closed Case state, preserving history and closure reason.';
comment on function public.record_case_progress(
  uuid, uuid, integer, text, text, text, timestamptz, boolean,
  uuid, integer, text, text, date, text, text
) is
  'Records one natural teacher progress update and atomically continues, reminds, or closes the Case.';
