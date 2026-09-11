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

-- A voided aggregate can only transition back to active through the exact
-- restore-shaped update. All teaching lifecycle/content fields stay unchanged.
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
      to_jsonb(new) - '{record_state,voided_at,voided_by_membership_id,void_reason,void_note,version,updated_at}'::text[]
    ) = (
      to_jsonb(old) - '{record_state,voided_at,voided_by_membership_id,void_reason,void_note,version,updated_at}'::text[]
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

-- Generic child-write guard. The explicit case_voided event is the only child
-- insert that legitimately occurs after record_state has become voided.
create or replace function private.guard_voided_case_child_write_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_case_id uuid;
begin
  if tg_op = 'DELETE' then
    v_case_id := old.learning_case_id;
  else
    v_case_id := new.learning_case_id;
  end if;

  if tg_table_name = 'case_events'
    and tg_op = 'INSERT'
    and new.event_type = 'case_voided' then
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

-- Stable releases must require the complete integrity guard, not merely the
-- earlier record_state columns/RPCs.
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
        to_regprocedure('private.guard_voided_learning_case_update_v2()') is not null
        and to_regprocedure('private.guard_voided_case_child_write_v2()') is not null
        and (
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
