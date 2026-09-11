-- v0.3.6: learning-record organization without rewriting teaching history.
--
-- A Learning Case has two independent dimensions:
--   * status: the teaching follow-up lifecycle;
--   * record_state: whether this Case is a valid record or has been voided as
--     an erroneous/duplicate record.
--
-- Voiding never deletes Evidence, Interventions, Assessments, attachments or
-- lifecycle events. It also never fabricates a teaching close. A pending
-- primary Action is cancelled in the same transaction so a voided record can
-- no longer create Today work.

alter table public.learning_cases
  add column if not exists record_state text not null default 'active',
  add column if not exists voided_at timestamptz,
  add column if not exists voided_by_membership_id uuid,
  add column if not exists void_reason text,
  add column if not exists void_note text;

alter table public.learning_cases
  drop constraint if exists learning_cases_record_state_check;
alter table public.learning_cases
  add constraint learning_cases_record_state_check
  check (record_state in ('active', 'voided'));

alter table public.learning_cases
  drop constraint if exists learning_cases_void_reason_check;
alter table public.learning_cases
  add constraint learning_cases_void_reason_check
  check (
    void_reason is null
    or void_reason in (
      'mistake',
      'duplicate',
      'wrong_student_subject',
      'other',
      'legacy_delete'
    )
  );

alter table public.learning_cases
  drop constraint if exists learning_cases_void_metadata_check;
alter table public.learning_cases
  add constraint learning_cases_void_metadata_check
  check (
    (record_state = 'active'
      and voided_at is null
      and voided_by_membership_id is null
      and void_reason is null
      and void_note is null)
    or
    (record_state = 'voided'
      and voided_at is not null
      and voided_by_membership_id is not null
      and void_reason is not null)
  );

alter table public.learning_cases
  drop constraint if exists learning_cases_voided_by_membership_fk;
alter table public.learning_cases
  add constraint learning_cases_voided_by_membership_fk
  foreign key (voided_by_membership_id, organization_id)
  references public.organization_memberships(id, organization_id)
  on delete restrict;

create index if not exists learning_cases_record_state_profile_idx
  on public.learning_cases (student_subject_profile_id, record_state, status);

comment on column public.learning_cases.record_state is
  'Record validity dimension independent from teaching follow-up status. Voided records remain auditable and are hidden from ordinary workspace/export reads.';

-- Keep the operation registry exhaustive.
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
    'update_organization_student_profile',
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
    'record_case_progress',
    'void_learning_case',
    'restore_learning_case'
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
    'case_reopened',
    'case_voided',
    'case_restored'
  ));

-- Ordinary table reads intentionally hide voided Cases. This keeps already
-- installed v0.3.5 clients from surfacing newly voided records. Governance
-- reads use dedicated SECURITY DEFINER RPCs below.
drop policy if exists "teachers can read learning cases"
  on public.learning_cases;
create policy "teachers can read learning cases"
on public.learning_cases
for select
to authenticated
using (
  record_state = 'active'
  and (select private.can_read_case_core_v2(learning_cases.id))
);

create or replace function private.void_learning_case_v2(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_reason text,
  p_note text
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
  v_owner_membership_id uuid;
  v_actor_membership_id uuid;
  v_teaching_membership_id uuid;
  v_case_status text;
  v_case_version integer;
  v_record_state text;
  v_cancelled_action_id uuid;
  v_event_id uuid;
  v_is_claimed boolean;
  v_existing_result jsonb;
  v_result jsonb;
  v_now timestamptz := timezone('utc', now());
begin
  if p_operation_id is null
    or p_case_id is null
    or p_expected_case_version is null
    or p_expected_case_version <= 0
    or p_reason is null
    or p_reason not in ('mistake', 'duplicate', 'wrong_student_subject', 'other') then
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
    learning_case.record_state
  into
    v_organization_id,
    v_profile_id,
    v_owner_membership_id,
    v_case_status,
    v_case_version,
    v_record_state
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id
  for update;

  if v_organization_id is null then
    raise exception using errcode = 'P0001', message = 'case_not_found';
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

  if not (select private.can_manage_organization_v2(v_organization_id)) then
    v_teaching_membership_id := (
      select private.current_teaching_membership_for_profile_v2(v_profile_id)
    );
    if v_teaching_membership_id is null
      or v_teaching_membership_id <> v_actor_membership_id then
      raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
    end if;
  end if;

  select claimed, result
  into v_is_claimed, v_existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'void_learning_case',
    'learning_case',
    p_case_id
  );

  if not v_is_claimed then
    return v_existing_result;
  end if;

  if v_case_version <> p_expected_case_version then
    raise exception using errcode = 'P0001', message = 'version_conflict';
  end if;

  if v_record_state = 'voided' then
    raise exception using errcode = 'P0001', message = 'case_already_voided';
  end if;

  v_cancelled_action_id := (
    select private.finish_primary_case_action_if_present_v2(
      p_case_id,
      v_actor_membership_id,
      v_now,
      'cancelled'
    )
  );

  update public.learning_cases
  set record_state = 'voided',
      voided_at = v_now,
      voided_by_membership_id = v_actor_membership_id,
      void_reason = p_reason,
      void_note = nullif(btrim(coalesce(p_note, '')), ''),
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
    'case_voided',
    v_app_user_id,
    v_actor_membership_id,
    v_now,
    jsonb_strip_nulls(jsonb_build_object(
      'case_status', v_case_status,
      'void_reason', p_reason,
      'void_note', nullif(btrim(coalesce(p_note, '')), ''),
      'cancelled_action_id', v_cancelled_action_id
    )),
    p_operation_id,
    'case_voided'
  )
  returning id into v_event_id;

  perform private.assert_case_core_invariant_v2(p_case_id);

  v_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', p_case_id,
    'event_id', v_event_id,
    'record_state', 'voided',
    'case_status', v_case_status,
    'case_version', v_case_version + 1,
    'void_reason', p_reason
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    v_result
  );

  return v_result;
end
$function$;

create or replace function public.void_learning_case(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_reason text,
  p_note text default null
)
returns jsonb
language sql
set search_path = ''
as $function$
  select private.void_learning_case_v2(
    p_operation_id,
    p_case_id,
    p_expected_case_version,
    p_reason,
    p_note
  )
$function$;

revoke all on function private.void_learning_case_v2(
  uuid, uuid, integer, text, text
) from public, anon, authenticated, service_role;
grant execute on function private.void_learning_case_v2(
  uuid, uuid, integer, text, text
) to authenticated, service_role;
revoke all on function public.void_learning_case(
  uuid, uuid, integer, text, text
) from public, anon, authenticated, service_role;
grant execute on function public.void_learning_case(
  uuid, uuid, integer, text, text
) to authenticated, service_role;

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
  v_actor_membership_id uuid;
  v_case_status text;
  v_case_version integer;
  v_record_state text;
  v_void_reason text;
  v_void_note text;
  v_voided_at timestamptz;
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
    learning_case.status,
    learning_case.version,
    learning_case.record_state,
    learning_case.void_reason,
    learning_case.void_note,
    learning_case.voided_at
  into
    v_organization_id,
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

  update public.learning_cases
  set record_state = 'active',
      voided_at = null,
      voided_by_membership_id = null,
      void_reason = null,
      void_note = null,
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
      'previous_voided_at', v_voided_at
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

create or replace function public.restore_learning_case(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer
)
returns jsonb
language sql
set search_path = ''
as $function$
  select private.restore_learning_case_v2(
    p_operation_id,
    p_case_id,
    p_expected_case_version
  )
$function$;

revoke all on function private.restore_learning_case_v2(
  uuid, uuid, integer
) from public, anon, authenticated, service_role;
grant execute on function private.restore_learning_case_v2(
  uuid, uuid, integer
) to authenticated, service_role;
revoke all on function public.restore_learning_case(
  uuid, uuid, integer
) from public, anon, authenticated, service_role;
grant execute on function public.restore_learning_case(
  uuid, uuid, integer
) to authenticated, service_role;

-- Dedicated governance read. Ordinary direct table reads intentionally hide
-- these rows, while current teaching staff/managers may inspect the audit list.
create or replace function private.list_voided_learning_cases(
  p_profile_id uuid
)
returns table (
  case_id uuid,
  profile_id uuid,
  title text,
  case_status text,
  case_version integer,
  void_reason text,
  void_note text,
  voided_at timestamptz,
  voided_by_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_organization_id uuid;
  v_teaching_membership_id uuid;
begin
  select profile.organization_id
  into v_organization_id
  from public.student_subject_profiles as profile
  where profile.id = p_profile_id;

  if v_organization_id is null then
    raise exception using errcode = 'P0001', message = 'profile_not_found';
  end if;

  if not (select private.can_manage_organization_v2(v_organization_id)) then
    v_teaching_membership_id := (
      select private.current_teaching_membership_for_profile_v2(p_profile_id)
    );
    if v_teaching_membership_id is null then
      raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
    end if;
  end if;

  return query
  select
    learning_case.id,
    learning_case.student_subject_profile_id,
    learning_case.title,
    learning_case.status,
    learning_case.version,
    learning_case.void_reason,
    learning_case.void_note,
    learning_case.voided_at,
    coalesce(nullif(btrim(app_user.display_name), ''), '未命名成员')
  from public.learning_cases as learning_case
  join public.organization_memberships as membership
    on membership.id = learning_case.voided_by_membership_id
   and membership.organization_id = learning_case.organization_id
  join public.app_users as app_user
    on app_user.id = membership.app_user_id
  where learning_case.student_subject_profile_id = p_profile_id
    and learning_case.record_state = 'voided'
  order by learning_case.voided_at desc, learning_case.id;
end
$function$;

create or replace function public.list_voided_learning_cases(
  p_profile_id uuid
)
returns table (
  case_id uuid,
  profile_id uuid,
  title text,
  case_status text,
  case_version integer,
  void_reason text,
  void_note text,
  voided_at timestamptz,
  voided_by_name text
)
language sql
stable
set search_path = ''
as $function$
  select * from private.list_voided_learning_cases(p_profile_id)
$function$;

revoke all on function private.list_voided_learning_cases(uuid)
  from public, anon, authenticated, service_role;
grant execute on function private.list_voided_learning_cases(uuid)
  to authenticated, service_role;
revoke all on function public.list_voided_learning_cases(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.list_voided_learning_cases(uuid)
  to authenticated, service_role;

-- Compatibility bridge for v0.3.5's old UI. It used end_case_follow_up with a
-- unique fixed note when the user pressed “删除问题”. Convert only that exact
-- legacy signature; ordinary “确认不是问题” closures stay valid history.
create or replace function private.bridge_legacy_case_delete_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_previous_status text;
begin
  if new.event_type <> 'case_closed'
    or new.metadata ->> 'closure_reason' <> 'not_issue'
    or new.metadata ->> 'closure_note' <> '教师删除/作废误建或重复问题' then
    return new;
  end if;

  v_previous_status := new.metadata ->> 'previous_status';
  if v_previous_status is null
    or v_previous_status not in (
      'new', 'confirmed', 'intervening', 'pending_verification', 'stable'
    ) then
    return new;
  end if;

  update public.learning_cases
  set record_state = 'voided',
      voided_at = new.occurred_at,
      voided_by_membership_id = new.actor_membership_id,
      void_reason = 'legacy_delete',
      void_note = '由旧版“删除问题”安全迁移',
      status = v_previous_status,
      closed_at = null,
      updated_at = timezone('utc', now())
  where id = new.learning_case_id
    and organization_id = new.organization_id
    and record_state = 'active';

  if found then
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
      new.organization_id,
      new.learning_case_id,
      'case_voided',
      new.actor_app_user_id,
      new.actor_membership_id,
      new.occurred_at,
      jsonb_build_object(
        'case_status', v_previous_status,
        'void_reason', 'legacy_delete',
        'void_note', '由旧版“删除问题”安全迁移',
        'legacy_case_closed_event_id', new.id
      ),
      new.operation_id,
      case when new.operation_id is null then null else 'legacy_case_voided' end
    );
  end if;

  return new;
end
$function$;

revoke all on function private.bridge_legacy_case_delete_v2()
  from public, anon, authenticated, service_role;

drop trigger if exists bridge_legacy_case_delete on public.case_events;
create trigger bridge_legacy_case_delete
after insert on public.case_events
for each row
when (new.event_type = 'case_closed')
execute function private.bridge_legacy_case_delete_v2();

-- Backfill only the exact old delete signature. Do not classify ordinary
-- not_issue closures as voided.
with legacy_delete as (
  select distinct on (event.learning_case_id)
    event.learning_case_id,
    event.organization_id,
    event.actor_app_user_id,
    event.actor_membership_id,
    event.occurred_at,
    event.id as close_event_id,
    event.operation_id,
    event.metadata ->> 'previous_status' as previous_status
  from public.case_events as event
  where event.event_type = 'case_closed'
    and event.metadata ->> 'closure_reason' = 'not_issue'
    and event.metadata ->> 'closure_note' = '教师删除/作废误建或重复问题'
    and event.metadata ->> 'previous_status' in (
      'new', 'confirmed', 'intervening', 'pending_verification', 'stable'
    )
  order by event.learning_case_id, event.occurred_at desc, event.id desc
)
update public.learning_cases as learning_case
set record_state = 'voided',
    voided_at = legacy_delete.occurred_at,
    voided_by_membership_id = legacy_delete.actor_membership_id,
    void_reason = 'legacy_delete',
    void_note = '由旧版“删除问题”安全迁移',
    status = legacy_delete.previous_status,
    closed_at = null,
    updated_at = timezone('utc', now())
from legacy_delete
where learning_case.id = legacy_delete.learning_case_id
  and learning_case.organization_id = legacy_delete.organization_id
  and learning_case.record_state = 'active';

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
select
  legacy_delete.organization_id,
  legacy_delete.learning_case_id,
  'case_voided',
  legacy_delete.actor_app_user_id,
  legacy_delete.actor_membership_id,
  legacy_delete.occurred_at,
  jsonb_build_object(
    'case_status', legacy_delete.previous_status,
    'void_reason', 'legacy_delete',
    'void_note', '由旧版“删除问题”安全迁移',
    'legacy_case_closed_event_id', legacy_delete.close_event_id
  ),
  null,
  null
from (
  select distinct on (event.learning_case_id)
    event.learning_case_id,
    event.organization_id,
    event.actor_app_user_id,
    event.actor_membership_id,
    event.occurred_at,
    event.id as close_event_id,
    event.metadata ->> 'previous_status' as previous_status
  from public.case_events as event
  where event.event_type = 'case_closed'
    and event.metadata ->> 'closure_reason' = 'not_issue'
    and event.metadata ->> 'closure_note' = '教师删除/作废误建或重复问题'
    and event.metadata ->> 'previous_status' in (
      'new', 'confirmed', 'intervening', 'pending_verification', 'stable'
    )
  order by event.learning_case_id, event.occurred_at desc, event.id desc
) as legacy_delete
where not exists (
  select 1
  from public.case_events as void_event
  where void_event.learning_case_id = legacy_delete.learning_case_id
    and void_event.event_type = 'case_voided'
    and void_event.metadata ->> 'legacy_case_closed_event_id' =
        legacy_delete.close_event_id::text
);

-- Case-aware export. The old RPC stays available for installed clients. The
-- v2 RPC adds learning_case_id so the client can select whole Cases rather
-- than matching by title.
create or replace function private.list_student_subject_learning_records_v2_with_attachments(
  p_profile_id uuid,
  p_limit integer default 500,
  p_offset integer default 0
)
returns table (
  learning_case_id uuid,
  record_id uuid,
  occurred_at timestamptz,
  student_name text,
  subject_name text,
  issue_title text,
  record_kind text,
  content text,
  assessment_result text,
  teacher_name text,
  next_step text,
  attachment_count integer,
  current_status text,
  attachment_paths text[]
)
language sql
stable
security definer
set search_path = ''
as $function$
  with mapped as (
    select
      coalesce(
        case when base_record.record_kind = 'case_created'
          then base_record.record_id end,
        evidence.learning_case_id,
        intervention.learning_case_id,
        assessment.learning_case_id
      ) as learning_case_id,
      base_record.*
    from private.list_student_subject_learning_records_with_attachments(
      p_profile_id,
      p_limit,
      p_offset
    ) as base_record
    left join public.case_evidence as evidence
      on base_record.record_kind = 'evidence'
     and evidence.id = base_record.record_id
    left join public.interventions as intervention
      on base_record.record_kind = 'intervention'
     and intervention.id = base_record.record_id
    left join public.assessments as assessment
      on base_record.record_kind = 'assessment'
     and assessment.id = base_record.record_id
  )
  select
    mapped.learning_case_id,
    mapped.record_id,
    mapped.occurred_at,
    mapped.student_name,
    mapped.subject_name,
    mapped.issue_title,
    mapped.record_kind,
    mapped.content,
    mapped.assessment_result,
    mapped.teacher_name,
    mapped.next_step,
    mapped.attachment_count,
    mapped.current_status,
    mapped.attachment_paths
  from mapped
  join public.learning_cases as learning_case
    on learning_case.id = mapped.learning_case_id
   and learning_case.student_subject_profile_id = p_profile_id
   and learning_case.record_state = 'active'
  order by mapped.occurred_at, mapped.record_id
$function$;

create or replace function public.list_student_subject_learning_records_v2_with_attachments(
  p_profile_id uuid,
  p_limit integer default 500,
  p_offset integer default 0
)
returns table (
  learning_case_id uuid,
  record_id uuid,
  occurred_at timestamptz,
  student_name text,
  subject_name text,
  issue_title text,
  record_kind text,
  content text,
  assessment_result text,
  teacher_name text,
  next_step text,
  attachment_count integer,
  current_status text,
  attachment_paths text[]
)
language sql
stable
set search_path = ''
as $function$
  select *
  from private.list_student_subject_learning_records_v2_with_attachments(
    p_profile_id,
    p_limit,
    p_offset
  )
$function$;

revoke all on function private.list_student_subject_learning_records_v2_with_attachments(
  uuid, integer, integer
) from public, anon, authenticated, service_role;
grant execute on function private.list_student_subject_learning_records_v2_with_attachments(
  uuid, integer, integer
) to authenticated, service_role;
revoke all on function public.list_student_subject_learning_records_v2_with_attachments(
  uuid, integer, integer
) from public, anon, authenticated, service_role;
grant execute on function public.list_student_subject_learning_records_v2_with_attachments(
  uuid, integer, integer
) to authenticated;

-- Preserve the v0.3.5 public signature while making its default export omit
-- voided Cases as well.
create or replace function public.list_student_subject_learning_records_with_attachments(
  p_profile_id uuid,
  p_limit integer default 500,
  p_offset integer default 0
)
returns table (
  record_id uuid,
  occurred_at timestamptz,
  student_name text,
  subject_name text,
  issue_title text,
  record_kind text,
  content text,
  assessment_result text,
  teacher_name text,
  next_step text,
  attachment_count integer,
  current_status text,
  attachment_paths text[]
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select
    record.record_id,
    record.occurred_at,
    record.student_name,
    record.subject_name,
    record.issue_title,
    record.record_kind,
    record.content,
    record.assessment_result,
    record.teacher_name,
    record.next_step,
    record.attachment_count,
    record.current_status,
    record.attachment_paths
  from private.list_student_subject_learning_records_v2_with_attachments(
    p_profile_id,
    p_limit,
    p_offset
  ) as record
$function$;

revoke all on function public.list_student_subject_learning_records_with_attachments(
  uuid, integer, integer
) from public, anon, authenticated, service_role;
grant execute on function public.list_student_subject_learning_records_with_attachments(
  uuid, integer, integer
) to authenticated;

-- Extend the production compatibility contract without invalidating previous
-- clients. Release gates compare schema versions monotonically.
create or replace function public.xueqing_backend_compatibility()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  select jsonb_build_object(
    'contract_version', 1,
    'schema_version', '20260911183000',
    'capabilities', jsonb_build_object(
      'student_profile_edit',
        to_regprocedure('public.update_organization_student_profile(uuid,uuid,uuid,integer,text,text,text,text,text)') is not null,
      'learning_record_export_attachments',
        to_regprocedure('public.list_student_subject_learning_records_with_attachments(uuid,integer,integer)') is not null,
      'learning_case_record_organization',
        to_regprocedure('public.void_learning_case(uuid,uuid,integer,text,text)') is not null
        and to_regprocedure('public.restore_learning_case(uuid,uuid,integer)') is not null,
      'selective_learning_record_export',
        to_regprocedure('public.list_student_subject_learning_records_v2_with_attachments(uuid,integer,integer)') is not null
    )
  )
$function$;

revoke all on function public.xueqing_backend_compatibility()
  from public, anon, authenticated, service_role;
grant execute on function public.xueqing_backend_compatibility()
  to anon, authenticated, service_role;
