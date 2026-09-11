-- v0.3.6 hardening: make record validity a database invariant, not only a UI/RPC convention.
--
-- Once a Learning Case has been voided:
--   * ordinary reads must not expose the Case or its child history;
--   * old/future teaching commands must not be able to append or mutate teaching facts;
--   * only the explicit audited restore command may reactivate the Case;
--   * voided history must not block organization operations such as teacher handoff,
--     ending a subject service, ending a subject scope, or disabling a member.

-- Central ordinary-read gate. Child RLS policies already delegate to this helper,
-- so adding record_state here hides Evidence / Actions / Events / attachments as
-- well as the Case row itself without erasing history.
create or replace function private.can_read_case_core_v2(
  target_case_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.learning_cases as learning_case
    where learning_case.id = target_case_id
      and learning_case.record_state = 'active'
      and (select private.can_read_profile_v2(
        learning_case.student_subject_profile_id
      ))
  )
$function$;

-- Attachment upload/metadata writes must also treat voided Cases as immutable.
create or replace function private.can_write_case_evidence_attachment_v2(
  target_evidence_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.case_evidence as evidence
    join public.learning_cases as learning_case
      on learning_case.id = evidence.learning_case_id
     and learning_case.organization_id = evidence.organization_id
    join public.student_subject_profiles as profile
      on profile.id = learning_case.student_subject_profile_id
     and profile.organization_id = learning_case.organization_id
    where evidence.id = target_evidence_id
      and evidence.status = 'finalized'
      and learning_case.record_state = 'active'
      and learning_case.status <> 'closed'
      and (select private.current_teaching_membership_for_profile_v2(profile.id))
        is not null
  )
$function$;

revoke all on function private.can_write_case_evidence_attachment_v2(uuid)
  from public, anon;
grant execute on function private.can_write_case_evidence_attachment_v2(uuid)
  to authenticated;

-- Preserve the proven strict filename/path policy while routing authorization
-- through the now record-state-aware write helper.
drop policy if exists "teachers can upload case evidence attachments"
  on storage.objects;
create policy "teachers can upload case evidence attachments"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'case-evidence-private'
  and (storage.foldername(name))[1] = 'org'
  and (storage.foldername(name))[3] = 'cases'
  and (storage.foldername(name))[5] = 'evidence'
  and storage.filename(name) ~
    E'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\\.(jpg|png|webp)$'
  and exists (
    select 1
    from public.case_evidence as evidence
    join public.learning_cases as learning_case
      on learning_case.id = evidence.learning_case_id
     and learning_case.organization_id = evidence.organization_id
    where evidence.id::text = (storage.foldername(name))[6]
      and learning_case.id::text = (storage.foldername(name))[4]
      and evidence.organization_id::text = (storage.foldername(name))[2]
      and evidence.status = 'finalized'
      and learning_case.record_state = 'active'
      and learning_case.status <> 'closed'
      and (select private.can_write_case_evidence_attachment_v2(evidence.id))
  )
);

-- A voided aggregate can only transition back to active through a strict
-- restore-shaped update. An open Case may also move responsibility to a
-- currently legal manager/teacher if the original owner is no longer legal.
create or replace function private.guard_voided_learning_case_update_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if old.record_state <> 'voided' then
    return new;
  end if;

  if new.record_state = 'active'
    and new.voided_at is null
    and new.voided_by_membership_id is null
    and new.void_reason is null
    and new.void_note is null
    and new.version = old.version + 1
    and (
      new.owner_membership_id = old.owner_membership_id
      or (
        old.status in (
          'confirmed',
          'intervening',
          'pending_verification',
          'stable'
        )
        and new.owner_membership_id is not null
        and (select private.legal_case_responsibility_membership_v2(
          old.student_subject_profile_id,
          new.owner_membership_id
        ))
      )
    )
    and (
      to_jsonb(new) - '{record_state,voided_at,voided_by_membership_id,void_reason,void_note,owner_membership_id,version,updated_at}'::text[]
    ) = (
      to_jsonb(old) - '{record_state,voided_at,voided_by_membership_id,void_reason,void_note,owner_membership_id,version,updated_at}'::text[]
    ) then
    return new;
  end if;

  raise exception using
    errcode = 'P0001',
    message = 'case_record_voided';
end
$function$;

revoke all on function private.guard_voided_learning_case_update_v2()
  from public, anon, authenticated, service_role;

drop trigger if exists learning_cases_voided_record_guard
  on public.learning_cases;
create trigger learning_cases_voided_record_guard
before update on public.learning_cases
for each row
execute function private.guard_voided_learning_case_update_v2();

-- Generic child-write guard. It reads the trigger row through jsonb so the same
-- function is valid for every child table even though only case_events has an
-- event_type column. The explicit case_voided audit insert is the sole child
-- write that is permitted after record_state has become voided.
create or replace function private.guard_voided_case_child_write_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_case_id uuid;
  v_row jsonb;
begin
  v_row := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  v_case_id := nullif(v_row->>'learning_case_id', '')::uuid;

  if tg_table_name = 'case_events'
    and tg_op = 'INSERT'
    and v_row->>'event_type' = 'case_voided' then
    return new;
  end if;

  if exists (
    select 1
    from public.learning_cases as learning_case
    where learning_case.id = v_case_id
      and learning_case.record_state = 'voided'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'case_record_voided';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end
$function$;

revoke all on function private.guard_voided_case_child_write_v2()
  from public, anon, authenticated, service_role;

drop trigger if exists case_evidence_voided_record_guard
  on public.case_evidence;
create trigger case_evidence_voided_record_guard
before insert or update or delete on public.case_evidence
for each row
execute function private.guard_voided_case_child_write_v2();

drop trigger if exists interventions_voided_record_guard
  on public.interventions;
create trigger interventions_voided_record_guard
before insert or update or delete on public.interventions
for each row
execute function private.guard_voided_case_child_write_v2();

drop trigger if exists assessments_voided_record_guard
  on public.assessments;
create trigger assessments_voided_record_guard
before insert or update or delete on public.assessments
for each row
execute function private.guard_voided_case_child_write_v2();

drop trigger if exists case_actions_voided_record_guard
  on public.case_actions;
create trigger case_actions_voided_record_guard
before insert or update or delete on public.case_actions
for each row
execute function private.guard_voided_case_child_write_v2();

drop trigger if exists case_events_voided_record_guard
  on public.case_events;
create trigger case_events_voided_record_guard
before insert or update or delete on public.case_events
for each row
execute function private.guard_voided_case_child_write_v2();

drop trigger if exists case_evidence_attachments_voided_record_guard
  on public.case_evidence_attachments;
create trigger case_evidence_attachments_voided_record_guard
before insert or update or delete on public.case_evidence_attachments
for each row
execute function private.guard_voided_case_child_write_v2();

-- Existing organization-management commands predate record_state and therefore
-- used only `status <> 'closed'` to detect unresolved Cases. Patch their current
-- installed definitions with strict preconditions so voided history cannot block
-- handoff/service/scope/member lifecycle operations.
create or replace function private.patch_v036_active_case_filter(
  target_function regprocedure,
  expected_occurrences integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_definition text;
  v_old text := 'and learning_case.status <> ''closed''';
  v_new text := E'and learning_case.record_state = ''active''\n          and learning_case.status <> ''closed''';
  v_occurrences integer;
begin
  select pg_catalog.pg_get_functiondef(target_function::oid)
  into v_definition;

  v_occurrences := (
    length(v_definition) - length(replace(v_definition, v_old, ''))
  ) / length(v_old);

  if v_occurrences <> expected_occurrences then
    raise exception 'v0.3.6 record-state patch precondition failed for %: expected %, found %',
      target_function::text,
      expected_occurrences,
      v_occurrences;
  end if;

  execute replace(v_definition, v_old, v_new);
end
$function$;

revoke all on function private.patch_v036_active_case_filter(regprocedure, integer)
  from public, anon, authenticated, service_role;

select private.patch_v036_active_case_filter(
  'private.end_organization_student_subject_service(uuid,uuid,uuid,integer)'::regprocedure,
  1
);
select private.patch_v036_active_case_filter(
  'private.transfer_organization_student_teacher_assignment(uuid,uuid,uuid,integer,uuid)'::regprocedure,
  1
);
select private.patch_v036_active_case_filter(
  'private.update_organization_teacher_subject_scope(uuid,uuid,uuid,uuid,uuid,integer,text)'::regprocedure,
  2
);
select private.patch_v036_active_case_filter(
  'private.update_organization_membership_status_manager_legacy(uuid,uuid,uuid,integer,text)'::regprocedure,
  2
);

drop function private.patch_v036_active_case_filter(regprocedure, integer);

-- Restoring is only safe when the student/subject service is active again.
-- If an open Case's previous owner lost legal responsibility while the Case was
-- voided, preserve history but assign current responsibility to the restoring
-- manager so the aggregate cannot come back in an invalid ownership state.
create or replace function private.restore_learning_case_v2(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer
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
  v_profile_id uuid;
  v_actor_membership_id uuid;
  v_previous_owner_membership_id uuid;
  v_restored_owner_membership_id uuid;
  v_case_status text;
  v_case_version integer;
  v_record_state text;
  v_void_reason text;
  v_void_note text;
  v_voided_at timestamptz;
  v_context_active boolean;
  v_event_id uuid;
  v_is_claimed boolean;
  v_existing_result jsonb;
  v_result jsonb;
  v_now timestamptz := timezone('utc', now());
begin
  if p_operation_id is null
    or p_case_id is null
    or p_expected_case_version is null
    or p_expected_case_version <= 0 then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  v_app_user_id := (select private.current_app_user_id_v2());
  if v_app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select
    learning_case.organization_id,
    learning_case.student_subject_profile_id,
    learning_case.owner_membership_id,
    learning_case.status,
    learning_case.version,
    learning_case.record_state,
    learning_case.void_reason,
    learning_case.void_note,
    learning_case.voided_at
  into
    v_organization_id,
    v_profile_id,
    v_previous_owner_membership_id,
    v_case_status,
    v_case_version,
    v_record_state,
    v_void_reason,
    v_void_note,
    v_voided_at
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id
  for update;

  if v_organization_id is null then
    raise exception using errcode = 'P0001', message = 'case_not_found';
  end if;

  if not (select private.can_manage_organization_v2(v_organization_id)) then
    raise exception using errcode = 'P0001', message = 'manager_permission_required';
  end if;

  select membership.id
  into v_actor_membership_id
  from public.organization_memberships as membership
  where membership.organization_id = v_organization_id
    and membership.app_user_id = v_app_user_id
    and membership.status = 'active'
  order by membership.created_at, membership.id
  limit 1;

  if v_actor_membership_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select claimed, result
  into v_is_claimed, v_existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'restore_learning_case',
    'learning_case',
    p_case_id
  );

  if not v_is_claimed then
    return v_existing_result;
  end if;

  if v_case_version <> p_expected_case_version then
    raise exception using errcode = 'P0001', message = 'version_conflict';
  end if;

  if v_record_state <> 'voided' then
    raise exception using errcode = 'P0001', message = 'case_not_voided';
  end if;

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
    where profile.id = v_profile_id
      and profile.organization_id = v_organization_id
      and profile.status = 'active'
  ) into v_context_active;

  if not v_context_active then
    raise exception using
      errcode = 'P0001',
      message = 'case_restore_context_inactive';
  end if;

  v_restored_owner_membership_id := v_previous_owner_membership_id;
  if v_case_status in (
    'confirmed',
    'intervening',
    'pending_verification',
    'stable'
  ) then
    v_restored_owner_membership_id := (
      select private.resolve_case_responsibility_membership_v2(
        v_profile_id,
        v_previous_owner_membership_id,
        v_actor_membership_id
      )
    );

    if v_restored_owner_membership_id is null
      or not (select private.legal_case_responsibility_membership_v2(
        v_profile_id,
        v_restored_owner_membership_id
      )) then
      raise exception using
        errcode = 'P0001',
        message = 'case_restore_responsibility_unavailable';
    end if;
  end if;

  update public.learning_cases
  set record_state = 'active',
      voided_at = null,
      voided_by_membership_id = null,
      void_reason = null,
      void_note = null,
      owner_membership_id = v_restored_owner_membership_id,
      version = version + 1,
      updated_at = v_now
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
  ) values (
    v_organization_id,
    p_case_id,
    'case_restored',
    v_app_user_id,
    v_actor_membership_id,
    v_now,
    jsonb_strip_nulls(jsonb_build_object(
      'case_status', v_case_status,
      'previous_void_reason', v_void_reason,
      'previous_void_note', v_void_note,
      'previous_voided_at', v_voided_at,
      'previous_owner_membership_id', case
        when v_previous_owner_membership_id is distinct from v_restored_owner_membership_id
          then v_previous_owner_membership_id
        else null
      end,
      'restored_owner_membership_id', case
        when v_previous_owner_membership_id is distinct from v_restored_owner_membership_id
          then v_restored_owner_membership_id
        else null
      end
    )),
    p_operation_id,
    'case_restored'
  )
  returning id into v_event_id;

  perform private.assert_case_core_invariant_v2(p_case_id);

  v_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', p_case_id,
    'event_id', v_event_id,
    'record_state', 'active',
    'case_status', v_case_status,
    'case_version', v_case_version + 1
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    v_result
  );

  return v_result;
end
$function$;

-- Stable releases must require the complete integrity guard, not merely the
-- earlier record_state columns/RPCs. Keep the function data-free and callable
-- with the public publishable key used by release CI; the trigger count itself
-- proves the private trigger functions were installed successfully.
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
        )
    )
  )
$function$;

revoke all on function public.xueqing_backend_compatibility()
  from public, anon, authenticated, service_role;
grant execute on function public.xueqing_backend_compatibility()
  to anon, authenticated, service_role;

comment on function private.guard_voided_learning_case_update_v2() is
  'Allows only the audited restore-shaped update once a Learning Case record has been voided.';
comment on function private.guard_voided_case_child_write_v2() is
  'Rejects teaching-history child writes for voided Learning Cases; case_voided is the sole post-void audit insert.';
