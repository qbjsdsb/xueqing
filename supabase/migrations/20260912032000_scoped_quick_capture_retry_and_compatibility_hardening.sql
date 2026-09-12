-- v0.3.8 scoped Quick Capture retry + compatibility hardening.
--
-- Keep the compatibility schema_version as the stable release floor. Additive
-- post-v0.3.6 capabilities are advertised by named capability flags instead of
-- forcing older clients/tests to treat every migration timestamp as a new floor.
--
-- Also make committed scoped Quick Capture receipts safe to retry after a Lead
-- handoff without allowing the same operation id to be replayed under a
-- different actor, responsibility expectation, or workspace scope.

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
  v_existing_scope text;
  v_existing_actor_membership_id uuid;
  v_existing_owner_membership_id uuid;
begin
  if p_operation_id is null
    or p_profile_id is null
    or p_workspace_scope is null
    or p_workspace_scope not in ('personal', 'organization')
    or p_expected_responsibility_membership_id is null then
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
    v_existing_actor_membership_id :=
      nullif(v_existing_result->>'actor_membership_id', '')::uuid;
    v_existing_owner_membership_id :=
      nullif(v_existing_result->>'owner_membership_id', '')::uuid;

    select coalesce(event.metadata->>'workspace_scope', 'legacy')
    into v_existing_scope
    from public.case_events as event
    where event.organization_id = v_organization_id
      and event.learning_case_id = nullif(v_existing_result->>'case_id', '')::uuid
      and event.operation_id = p_operation_id
      and event.event_type = 'case_created'
      and event.operation_event_key = 'case_created'
    order by event.occurred_at, event.id
    limit 1;

    if v_existing_actor_membership_id is distinct from v_actor_membership_id
      or v_existing_owner_membership_id is distinct from
        p_expected_responsibility_membership_id
      or v_existing_scope is distinct from p_workspace_scope then
      raise exception using errcode = 'P0001', message = 'operation_scope_conflict';
    end if;

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
  'Authorization-aware exactly-once wrapper. A committed scoped capture may be retried after responsibility changes only by the same actor with the original owner expectation and workspace scope.';

create or replace function public.xueqing_backend_compatibility()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select jsonb_build_object(
    'contract_version', 1,
    'schema_version', '20260911193000',
    'capabilities', jsonb_build_object(
      'student_profile_edit',
        to_regprocedure('public.update_organization_student_profile(uuid,uuid,uuid,integer,text,text,text,text,text)') is not null,
      'learning_record_export_attachments',
        to_regprocedure('public.list_student_subject_learning_records_with_attachments(uuid,integer,integer)') is not null,
      'learning_case_record_organization',
        to_regprocedure('public.void_learning_case(uuid,uuid,integer,text,text)') is not null
        and to_regprocedure('public.restore_learning_case(uuid,uuid,integer)') is not null,
      'selective_learning_record_export',
        to_regprocedure('public.list_student_subject_learning_records_v2_with_attachments(uuid,integer,integer)') is not null,
      'voided_record_integrity_guard',
        (
          select count(*) = 7
          from pg_catalog.pg_trigger as trigger_row
          join pg_catalog.pg_class as relation
            on relation.oid = trigger_row.tgrelid
          join pg_catalog.pg_namespace as namespace
            on namespace.oid = relation.relnamespace
          where namespace.nspname = 'public'
            and not trigger_row.tgisinternal
            and trigger_row.tgname in (
              'learning_cases_voided_record_guard',
              'case_evidence_voided_record_guard',
              'interventions_voided_record_guard',
              'assessments_voided_record_guard',
              'case_actions_voided_record_guard',
              'case_events_voided_record_guard',
              'case_evidence_attachments_voided_record_guard'
            )
        ),
      'responsibility_read_model',
        to_regprocedure('public.get_workspace_responsibility_context(uuid)') is not null,
      'responsibility_safe_quick_capture',
        to_regprocedure(
          'public.quick_capture_case_in_scope(uuid,uuid,integer,text,text,text,timestamp with time zone,text,text,timestamp with time zone,uuid,text,uuid)'
        ) is not null
    )
  )
$function$;

revoke all on function public.xueqing_backend_compatibility()
  from public, anon, authenticated, service_role;
grant execute on function public.xueqing_backend_compatibility()
  to anon, authenticated, service_role;

comment on function public.xueqing_backend_compatibility() is
  'Data-free release compatibility contract. schema_version is the stable minimum floor; additive backend features are advertised by named capabilities.';
