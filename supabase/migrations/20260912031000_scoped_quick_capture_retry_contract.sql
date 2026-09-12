-- Preserve exactly-once retry semantics for the explicit scoped Quick Capture
-- contract when responsibility changes after the original transaction commits.
--
-- Authorization is still checked against the current caller before a receipt is
-- returned. Only stale Profile/responsibility expectations are skipped for an
-- already committed operation, because those facts may legitimately change
-- after the first write while the client is retrying a lost response.

create or replace function private.quick_capture_case_in_scope(
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
  p_organization_case_type_id uuid,
  p_workspace_scope text,
  p_expected_responsibility_membership_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_app_user_id uuid;
  v_organization_id uuid;
  v_actor_membership_id uuid;
  v_existing_result jsonb;
begin
  if p_operation_id is null
    or p_profile_id is null
    or p_workspace_scope is null
    or p_workspace_scope not in ('personal', 'organization') then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  v_app_user_id := (select private.current_app_user_id_v2());
  if v_app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select profile.organization_id
  into v_organization_id
  from public.student_subject_profiles as profile
  where profile.id = p_profile_id
    and profile.status = 'active';

  if v_organization_id is null then
    raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
  end if;

  v_actor_membership_id := (
    select private.current_teaching_membership_for_profile_v2(p_profile_id)
  );
  if v_actor_membership_id is null then
    raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
  end if;

  if p_workspace_scope = 'personal' then
    if not (select private.membership_has_current_teaching_responsibility_v2(
      p_profile_id,
      v_actor_membership_id
    )) then
      raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
    end if;
  elsif not (select private.manager_membership_can_supervise_v2(
    v_organization_id,
    v_actor_membership_id
  )) then
    raise exception using errcode = 'P0001', message = 'manager_permission_required';
  end if;

  select receipt.result
  into v_existing_result
  from public.operation_receipts as receipt
  where receipt.organization_id = v_organization_id
    and receipt.operation_id = p_operation_id
    and receipt.command_type = 'quick_capture_case'
    and receipt.target_type = 'student_subject_profile'
    and receipt.target_id = p_profile_id
    and receipt.result is not null
    and receipt.committed_at is not null;

  if v_existing_result is not null then
    return v_existing_result;
  end if;

  return private.quick_capture_case_scoped_v2(
    p_operation_id,
    p_profile_id,
    p_expected_profile_version,
    p_case_type,
    p_title,
    p_description,
    p_observed_at,
    p_evidence_summary,
    p_next_action_title,
    p_next_action_due_at,
    p_organization_case_type_id,
    p_workspace_scope,
    p_expected_responsibility_membership_id
  );
end
$function$;

revoke all on function private.quick_capture_case_in_scope(
  uuid, uuid, integer, text, text, text, timestamptz, text, text,
  timestamptz, uuid, text, uuid
) from public, anon, authenticated, service_role;
grant execute on function private.quick_capture_case_in_scope(
  uuid, uuid, integer, text, text, text, timestamptz, text, text,
  timestamptz, uuid, text, uuid
) to authenticated, service_role;

comment on function private.quick_capture_case_in_scope(
  uuid, uuid, integer, text, text, text, timestamptz, text, text,
  timestamptz, uuid, text, uuid
) is
  'Authorization-aware exactly-once wrapper: committed scoped Quick Capture retries return the original receipt before stale responsibility/version checks.';
