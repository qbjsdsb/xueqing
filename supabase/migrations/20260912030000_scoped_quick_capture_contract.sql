-- v0.3.8 explicit Quick Capture scope contract.
--
-- C1 made the legacy RPC responsibility-safe while preserving its signature.
-- This migration adds the explicit write contract needed by the future dual
-- Personal / Organization workspace UI:
--
--   personal     -> actor must be a real current assigned teacher;
--   organization -> actor must be an owner/admin supervisor and responsibility
--                   must remain the current active Lead;
--   legacy       -> compatibility path used only by the existing RPCs.
--
-- Explicit callers must send the responsibility membership they observed. The
-- server compares it with the current responsibility and locks the matching
-- Assignment/scope rows for the transaction, so a stale or concurrent handoff
-- cannot silently assign a new Case to the wrong teacher.

create or replace function private.lock_current_teaching_responsibility_v2(
  target_profile_id uuid,
  target_membership_id uuid,
  require_lead boolean
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $function$
begin
  perform 1
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
  join public.subjects as subject
    on subject.id = organization_subject.subject_id
   and subject.status = 'active'
  join public.student_teacher_assignments as assignment
    on assignment.student_subject_profile_id = profile.id
   and assignment.organization_id = profile.organization_id
   and assignment.membership_id = target_membership_id
   and assignment.status = 'active'
   and (not require_lead or assignment.assignment_role = 'lead')
   and assignment.active_from <=
     (now() at time zone organization.time_zone)::date
   and (
     assignment.active_to is null
     or assignment.active_to >=
       (now() at time zone organization.time_zone)::date
   )
  join public.organization_memberships as membership
    on membership.id = assignment.membership_id
   and membership.organization_id = assignment.organization_id
   and membership.status = 'active'
  join public.membership_roles as teacher_role
    on teacher_role.membership_id = membership.id
   and teacher_role.organization_id = membership.organization_id
   and teacher_role.role = 'teacher'
  join public.membership_subject_scopes as scope
    on scope.membership_id = membership.id
   and scope.organization_id = membership.organization_id
   and scope.organization_subject_id = profile.organization_subject_id
   and scope.scope_kind = 'teaching'
   and scope.status = 'active'
   and scope.active_from <=
     (now() at time zone organization.time_zone)::date
   and (
     scope.active_to is null
     or scope.active_to >=
       (now() at time zone organization.time_zone)::date
   )
  where profile.id = target_profile_id
    and profile.status = 'active'
  for share of assignment, membership, teacher_role, scope;

  return found;
end
$function$;

create or replace function private.quick_capture_case_scoped_v2(
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
  app_user_id uuid;
  v_organization_id uuid;
  actor_membership_id uuid;
  responsibility_membership_id uuid;
  v_require_lead boolean := false;
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
    or p_expected_profile_version <= 0
    or p_workspace_scope is null
    or p_workspace_scope not in ('legacy', 'personal', 'organization') then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  if p_workspace_scope <> 'legacy'
    and p_expected_responsibility_membership_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'responsibility_expectation_required';
  end if;

  if p_workspace_scope = 'legacy'
    and p_expected_responsibility_membership_id is not null then
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

  actor_membership_id := (
    select private.current_teaching_membership_for_profile_v2(p_profile_id)
  );
  if actor_membership_id is null then
    raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
  end if;

  if p_workspace_scope = 'personal' then
    if not (select private.membership_has_current_teaching_responsibility_v2(
      p_profile_id,
      actor_membership_id
    )) then
      raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
    end if;
    responsibility_membership_id := actor_membership_id;
  elsif p_workspace_scope = 'organization' then
    if not (select private.manager_membership_can_supervise_v2(
      v_organization_id,
      actor_membership_id
    )) then
      raise exception using errcode = 'P0001', message = 'manager_permission_required';
    end if;
    responsibility_membership_id := (
      select private.current_active_lead_membership_for_profile_v2(p_profile_id)
    );
    if responsibility_membership_id is null then
      raise exception using
        errcode = 'P0001',
        message = 'case_responsibility_required';
    end if;
    v_require_lead := true;
  else
    responsibility_membership_id := (
      select private.resolve_new_case_responsibility_membership_v2(
        p_profile_id,
        actor_membership_id
      )
    );
    if responsibility_membership_id is null then
      raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
    end if;
    v_require_lead := responsibility_membership_id <> actor_membership_id;
  end if;

  if p_workspace_scope <> 'legacy'
    and p_expected_responsibility_membership_id
      is distinct from responsibility_membership_id then
    raise exception using errcode = 'P0001', message = 'responsibility_conflict';
  end if;

  if not (select private.lock_current_teaching_responsibility_v2(
    p_profile_id,
    responsibility_membership_id,
    v_require_lead
  )) then
    if p_workspace_scope = 'legacy' then
      raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
    end if;
    raise exception using errcode = 'P0001', message = 'responsibility_conflict';
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
    responsibility_membership_id,
    p_case_type,
    p_organization_case_type_id,
    custom_case_type_label,
    btrim(p_title),
    nullif(btrim(p_description), ''),
    'normal',
    'new',
    p_observed_at,
    app_user_id,
    actor_membership_id
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
    actor_membership_id
  )
  returning id into evidence_id;

  if normalized_action_title is not null then
    action_id := (
      select private.create_primary_case_action_v2(
        v_organization_id,
        case_id,
        responsibility_membership_id,
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
    actor_membership_id,
    jsonb_strip_nulls(jsonb_build_object(
      'profile_id', p_profile_id,
      'workspace_scope', nullif(p_workspace_scope, 'legacy'),
      'case_type', p_case_type,
      'organization_case_type_id', p_organization_case_type_id,
      'case_type_label', custom_case_type_label,
      'evidence_id', evidence_id,
      'action_id', action_id,
      'owner_membership_id', responsibility_membership_id
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
    'case_version', 1,
    'actor_membership_id', actor_membership_id,
    'owner_membership_id', responsibility_membership_id
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

-- Preserve the legacy private signature used by both v0.3.7 public wrappers.
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
language sql
volatile
security definer
set search_path = ''
as $function$
  select private.quick_capture_case_scoped_v2(
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
    'legacy',
    null
  )
$function$;

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
language sql
volatile
security definer
set search_path = ''
as $function$
  select private.quick_capture_case_scoped_v2(
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
  )
$function$;

create or replace function public.quick_capture_case_in_scope(
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
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.quick_capture_case_in_scope(
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
  )
$function$;

revoke all on function private.lock_current_teaching_responsibility_v2(
  uuid, uuid, boolean
) from public, anon, authenticated, service_role;
revoke all on function private.quick_capture_case_scoped_v2(
  uuid, uuid, integer, text, text, text, timestamptz, text, text,
  timestamptz, uuid, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function private.quick_capture_case_v2(
  uuid, uuid, integer, text, text, text, timestamptz, text, text,
  timestamptz, uuid
) from public, anon, authenticated, service_role;
revoke all on function private.quick_capture_case_in_scope(
  uuid, uuid, integer, text, text, text, timestamptz, text, text,
  timestamptz, uuid, text, uuid
) from public, anon, authenticated, service_role;
grant execute on function private.quick_capture_case_in_scope(
  uuid, uuid, integer, text, text, text, timestamptz, text, text,
  timestamptz, uuid, text, uuid
) to authenticated, service_role;

revoke all on function public.quick_capture_case_in_scope(
  uuid, uuid, integer, text, text, text, timestamptz, text, text,
  timestamptz, uuid, text, uuid
) from public, anon, authenticated, service_role;
grant execute on function public.quick_capture_case_in_scope(
  uuid, uuid, integer, text, text, text, timestamptz, text, text,
  timestamptz, uuid, text, uuid
) to authenticated, service_role;

comment on function public.quick_capture_case_in_scope(
  uuid, uuid, integer, text, text, text, timestamptz, text, text,
  timestamptz, uuid, text, uuid
) is
  'Explicit Personal/Organization Quick Capture contract. Callers must provide the responsibility membership they observed; stale responsibility fails closed.';

-- Advertise the additive capability without changing the v0.3.7 release checks.
create or replace function public.xueqing_backend_compatibility()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select jsonb_build_object(
    'contract_version', 1,
    'schema_version', '20260912030000',
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
      'responsibility_safe_quick_capture',
        to_regprocedure(
          'public.quick_capture_case_in_scope(uuid,uuid,integer,text,text,text,timestamp with time zone,text,text,timestamp with time zone,uuid,text,uuid)'
        ) is not null
        and to_regprocedure(
          'private.resolve_new_case_responsibility_membership_v2(uuid,uuid)'
        ) is not null
    )
  )
$function$;

revoke all on function public.xueqing_backend_compatibility()
  from public, anon, authenticated, service_role;
grant execute on function public.xueqing_backend_compatibility()
  to anon, authenticated, service_role;
