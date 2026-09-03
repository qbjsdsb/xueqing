-- Phase 0B.0-C: the first transactional Learning Case loop.
-- This is still a fictional/local compatibility migration. It is not a
-- production migration or permission to import real student data.

create table public.operation_receipts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  operation_id uuid not null,
  command_type text not null
    check (command_type in (
      'quick_capture_case',
      'confirm_case',
      'add_case_evidence',
      'record_intervention',
      'record_assessment',
      'stabilize_case',
      'close_case'
    )),
  target_type text not null
    check (target_type in ('student_subject_profile', 'learning_case')),
  target_id uuid not null,
  result jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  committed_at timestamptz,
  constraint operation_receipts_unique_key
    unique (organization_id, operation_id),
  constraint operation_receipts_commit_check
    check (
      (result is null and committed_at is null)
      or (result is not null and committed_at is not null)
    )
);

create table public.learning_cases (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  student_subject_profile_id uuid not null,
  owner_membership_id uuid not null,
  case_type text not null
    check (case_type in ('knowledge', 'habit', 'exam_strategy', 'other')),
  title text not null
    check (char_length(btrim(title)) > 0),
  description text,
  priority text not null default 'normal'
    check (priority in ('low', 'normal', 'high', 'urgent')),
  status text not null default 'new'
    check (
      status in (
        'new',
        'confirmed',
        'intervening',
        'pending_verification',
        'stable',
        'closed'
      )
    ),
  first_observed_at timestamptz not null,
  stable_at timestamptz,
  closed_at timestamptz,
  reopened_count integer not null default 0
    check (reopened_count >= 0),
  version integer not null default 1
    check (version > 0),
  created_by_app_user_id uuid not null
    references public.app_users(id) on delete restrict,
  created_by_membership_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint learning_cases_profile_fk
    foreign key (student_subject_profile_id, organization_id)
    references public.student_subject_profiles(id, organization_id)
    on delete restrict,
  constraint learning_cases_owner_fk
    foreign key (owner_membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict,
  constraint learning_cases_creator_membership_fk
    foreign key (created_by_membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict,
  constraint learning_cases_id_organization_key
    unique (id, organization_id),
  constraint learning_cases_stable_at_check
    check (
      (status in ('stable', 'closed') and stable_at is not null)
      or (status not in ('stable', 'closed') and stable_at is null)
    ),
  constraint learning_cases_closed_at_check
    check (
      (status = 'closed' and closed_at is not null)
      or (status <> 'closed' and closed_at is null)
    )
);

create index learning_cases_profile_status_idx
  on public.learning_cases (student_subject_profile_id, status);

create index learning_cases_organization_status_idx
  on public.learning_cases (organization_id, status);

create table public.case_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  learning_case_id uuid not null,
  event_type text not null
    check (event_type in (
      'case_created',
      'case_confirmed',
      'evidence_recorded',
      'intervention_recorded',
      'assessment_recorded',
      'case_stabilized',
      'case_closed'
    )),
  actor_app_user_id uuid not null
    references public.app_users(id) on delete restrict,
  actor_membership_id uuid not null,
  occurred_at timestamptz not null default timezone('utc', now()),
  metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object'),
  operation_id uuid,
  operation_event_key text,
  constraint case_events_case_fk
    foreign key (learning_case_id, organization_id)
    references public.learning_cases(id, organization_id)
    on delete restrict,
  constraint case_events_actor_membership_fk
    foreign key (actor_membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict,
  constraint case_events_operation_key_check
    check (
      (operation_id is null and operation_event_key is null)
      or (operation_id is not null and operation_event_key is not null)
    ),
  constraint case_events_operation_unique_key
    unique (organization_id, operation_id, operation_event_key)
);

create index case_events_case_occurred_idx
  on public.case_events (learning_case_id, occurred_at, id);

create table public.case_evidence (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  learning_case_id uuid not null,
  source_type text not null
    check (source_type in (
      'exam',
      'homework',
      'essay',
      'classwork',
      'quiz',
      'observation',
      'guardian_report',
      'other'
    )),
  title text not null
    check (char_length(btrim(title)) > 0),
  observed_at timestamptz not null,
  summary text not null
    check (char_length(btrim(summary)) > 0),
  status text not null default 'finalized'
    check (status in ('draft', 'finalized')),
  created_by_app_user_id uuid not null
    references public.app_users(id) on delete restrict,
  created_by_membership_id uuid not null,
  version integer not null default 1
    check (version > 0),
  created_at timestamptz not null default timezone('utc', now()),
  constraint case_evidence_case_fk
    foreign key (learning_case_id, organization_id)
    references public.learning_cases(id, organization_id)
    on delete restrict,
  constraint case_evidence_creator_membership_fk
    foreign key (created_by_membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict,
  constraint case_evidence_id_organization_key
    unique (id, organization_id)
);

create index case_evidence_case_observed_idx
  on public.case_evidence (learning_case_id, observed_at desc, created_at desc);

create table public.interventions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  learning_case_id uuid not null,
  performed_by_app_user_id uuid not null
    references public.app_users(id) on delete restrict,
  performed_by_membership_id uuid not null,
  strategy text not null
    check (char_length(btrim(strategy)) > 0),
  notes text,
  occurred_at timestamptz not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint interventions_case_fk
    foreign key (learning_case_id, organization_id)
    references public.learning_cases(id, organization_id)
    on delete restrict,
  constraint interventions_membership_fk
    foreign key (performed_by_membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict
);

create index interventions_case_occurred_idx
  on public.interventions (learning_case_id, occurred_at desc, created_at desc);

create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  learning_case_id uuid not null,
  assessed_by_app_user_id uuid not null
    references public.app_users(id) on delete restrict,
  assessed_by_membership_id uuid not null,
  result text not null
    check (result in ('passed', 'partial', 'not_passed')),
  evidence_summary text not null
    check (char_length(btrim(evidence_summary)) > 0),
  notes text,
  assessed_at timestamptz not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint assessments_case_fk
    foreign key (learning_case_id, organization_id)
    references public.learning_cases(id, organization_id)
    on delete restrict,
  constraint assessments_membership_fk
    foreign key (assessed_by_membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict
);

create index assessments_case_assessed_idx
  on public.assessments (learning_case_id, assessed_at desc, created_at desc);

create table public.case_actions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  learning_case_id uuid not null,
  assigned_membership_id uuid not null,
  action_type text not null
    check (action_type in (
      'reteach',
      'practice',
      'verify',
      'communicate',
      'review',
      'other'
    )),
  title text not null
    check (char_length(btrim(title)) > 0),
  due_at timestamptz,
  is_primary boolean not null default false,
  status text not null default 'pending'
    check (status in ('pending', 'done', 'cancelled')),
  completed_at timestamptz,
  completed_by_membership_id uuid,
  cancelled_at timestamptz,
  cancelled_by_membership_id uuid,
  version integer not null default 1
    check (version > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint case_actions_case_fk
    foreign key (learning_case_id, organization_id)
    references public.learning_cases(id, organization_id)
    on delete restrict,
  constraint case_actions_assigned_membership_fk
    foreign key (assigned_membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict,
  constraint case_actions_completed_membership_fk
    foreign key (completed_by_membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict,
  constraint case_actions_cancelled_membership_fk
    foreign key (cancelled_by_membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict,
  constraint case_actions_id_organization_key
    unique (id, organization_id),
  constraint case_actions_state_check
    check (
      (status = 'pending'
        and completed_at is null
        and cancelled_at is null)
      or (status = 'done'
        and completed_at is not null
        and cancelled_at is null)
      or (status = 'cancelled'
        and completed_at is null
        and cancelled_at is not null)
    ),
  constraint case_actions_primary_check
    check (not is_primary or status = 'pending')
);

create unique index case_actions_one_pending_primary_idx
  on public.case_actions (learning_case_id)
  where status = 'pending' and is_primary;

create index case_actions_case_status_due_idx
  on public.case_actions (learning_case_id, status, due_at);

comment on table public.operation_receipts is
  'Exactly-once result registry for high-risk domain commands.';
comment on table public.learning_cases is
  'Learning Case resolution aggregate; status is not a task-list label.';
comment on table public.case_evidence is
  'Append-only observed teaching evidence; finalized history is immutable.';
comment on table public.case_events is
  'Append-only lifecycle facts, including immutable case_closed events.';
comment on table public.case_actions is
  'Current and historical next actions; one pending primary is enforced per Case.';

create or replace function private.current_teaching_membership_for_profile_v2(
  target_profile_id uuid
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $function$
  select assignment.membership_id
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
  join public.student_teacher_assignments as assignment
    on assignment.student_subject_profile_id = profile.id
   and assignment.organization_id = profile.organization_id
   and assignment.status = 'active'
   and (now() at time zone organization.time_zone)::date >=
     assignment.active_from
   and (
     assignment.active_to is null
     or (now() at time zone organization.time_zone)::date <= assignment.active_to
   )
  join public.organization_memberships as membership
    on membership.id = assignment.membership_id
   and membership.organization_id = assignment.organization_id
   and membership.status = 'active'
   and membership.app_user_id =
     (select private.current_app_user_id_v2())
  join public.membership_roles as membership_role
    on membership_role.membership_id = membership.id
   and membership_role.organization_id = membership.organization_id
   and membership_role.role = 'teacher'
  join public.membership_subject_scopes as scope
    on scope.membership_id = membership.id
   and scope.organization_id = membership.organization_id
   and scope.organization_subject_id = profile.organization_subject_id
   and scope.scope_kind = 'teaching'
   and scope.status = 'active'
   and (now() at time zone organization.time_zone)::date >=
     scope.active_from
   and (
     scope.active_to is null
     or (now() at time zone organization.time_zone)::date <= scope.active_to
   )
  where profile.id = target_profile_id
    and profile.status = 'active'
  order by
    case assignment.assignment_role
      when 'lead' then 0
      else 1
    end,
    assignment.id
  limit 1
$function$;

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
      and (select private.can_read_profile_v2(
        learning_case.student_subject_profile_id
      ))
  )
$function$;

create or replace function private.claim_case_operation_v2(
  target_organization_id uuid,
  target_operation_id uuid,
  expected_command_type text,
  expected_target_type text,
  expected_target_id uuid
)
returns table (
  claimed boolean,
  result jsonb
)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  inserted_receipt_id uuid;
  existing_command_type text;
  existing_target_type text;
  existing_target_id uuid;
  existing_result jsonb;
  existing_committed_at timestamptz;
begin
  insert into public.operation_receipts (
    organization_id,
    operation_id,
    command_type,
    target_type,
    target_id
  )
  values (
    target_organization_id,
    target_operation_id,
    expected_command_type,
    expected_target_type,
    expected_target_id
  )
  on conflict (organization_id, operation_id) do nothing
  returning id into inserted_receipt_id;

  if inserted_receipt_id is not null then
    claimed := true;
    result := null;
    return next;
    return;
  end if;

  select
    receipt.command_type,
    receipt.target_type,
    receipt.target_id,
    receipt.result,
    receipt.committed_at
  into
    existing_command_type,
    existing_target_type,
    existing_target_id,
    existing_result,
    existing_committed_at
  from public.operation_receipts as receipt
  where receipt.organization_id = target_organization_id
    and receipt.operation_id = target_operation_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'operation_not_found_after_conflict';
  end if;

  if existing_command_type <> expected_command_type
    or existing_target_type <> expected_target_type
    or existing_target_id <> expected_target_id then
    raise exception using
      errcode = 'P0001',
      message = 'operation_id_reuse_conflict';
  end if;

  if existing_result is null or existing_committed_at is null then
    raise exception using
      errcode = 'P0001',
      message = 'operation_incomplete';
  end if;

  claimed := false;
  result := existing_result;
  return next;
end
$function$;

create or replace function private.finish_case_operation_v2(
  target_organization_id uuid,
  target_operation_id uuid,
  operation_result jsonb
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
begin
  update public.operation_receipts
  set result = operation_result,
      committed_at = timezone('utc', now())
  where organization_id = target_organization_id
    and operation_id = target_operation_id
    and result is null;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'operation_receipt_missing';
  end if;
end
$function$;

create or replace function private.finish_primary_case_action_v2(
  target_case_id uuid,
  actor_membership_id uuid,
  finished_at timestamptz,
  final_status text
)
returns uuid
language plpgsql
volatile
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

  if action_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'case_primary_action_missing';
  end if;

  return action_id;
end
$function$;

create or replace function private.create_primary_case_action_v2(
  target_organization_id uuid,
  target_case_id uuid,
  assigned_membership_id uuid,
  action_type text,
  action_title text,
  action_due_at timestamptz
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  action_id uuid;
begin
  if action_title is null or char_length(btrim(action_title)) = 0 then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_next_action';
  end if;

  insert into public.case_actions (
    organization_id,
    learning_case_id,
    assigned_membership_id,
    action_type,
    title,
    due_at,
    is_primary,
    status
  )
  values (
    target_organization_id,
    target_case_id,
    assigned_membership_id,
    action_type,
    action_title,
    action_due_at,
    true,
    'pending'
  )
  returning id into action_id;

  return action_id;
end
$function$;

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
  profile_subject_id uuid;
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

  select profile.status, profile.organization_subject_id
  into profile_status, profile_subject_id
  from public.student_subject_profiles as profile
  where profile.id = profile_id
    and profile.organization_id = case_organization_id;

  select count(*)::integer
  into pending_primary_count
  from public.case_actions as action
  where action.learning_case_id = target_case_id
    and action.status = 'pending'
    and action.is_primary;

  if case_status in (
    'confirmed',
    'intervening',
    'pending_verification',
    'stable'
  ) and profile_status = 'active' then
    if owner_id is null or pending_primary_count <> 1 then
      raise exception using
        errcode = 'P0001',
        message = 'case_open_invariant';
    end if;

    if not exists (
      select 1
      from public.student_teacher_assignments as assignment
      join public.organization_memberships as membership
        on membership.id = assignment.membership_id
       and membership.organization_id = assignment.organization_id
       and membership.status = 'active'
      join public.membership_roles as membership_role
        on membership_role.membership_id = membership.id
       and membership_role.organization_id = membership.organization_id
       and membership_role.role = 'teacher'
      join public.membership_subject_scopes as scope
        on scope.membership_id = membership.id
       and scope.organization_id = membership.organization_id
       and scope.organization_subject_id = profile_subject_id
      where assignment.student_subject_profile_id = profile_id
        and assignment.organization_id = case_organization_id
        and assignment.membership_id = owner_id
        and assignment.status = 'active'
        and scope.scope_kind = 'teaching'
        and scope.status = 'active'
    ) then
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

create or replace function private.reject_case_history_mutation_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  raise exception using
    errcode = 'P0001',
    message = 'append_only_history';
end
$function$;

create trigger case_events_append_only
before update or delete on public.case_events
for each row execute function private.reject_case_history_mutation_v2();

create trigger case_evidence_append_only
before update or delete on public.case_evidence
for each row execute function private.reject_case_history_mutation_v2();

create trigger interventions_append_only
before update or delete on public.interventions
for each row execute function private.reject_case_history_mutation_v2();

create trigger assessments_append_only
before update or delete on public.assessments
for each row execute function private.reject_case_history_mutation_v2();

revoke all on function private.current_teaching_membership_for_profile_v2(uuid) from public;
revoke all on function private.can_read_case_core_v2(uuid) from public;
revoke all on function private.claim_case_operation_v2(uuid, uuid, text, text, uuid) from public;
revoke all on function private.finish_case_operation_v2(uuid, uuid, jsonb) from public;
revoke all on function private.finish_primary_case_action_v2(uuid, uuid, timestamptz, text) from public;
revoke all on function private.create_primary_case_action_v2(uuid, uuid, uuid, text, text, timestamptz) from public;
revoke all on function private.assert_case_core_invariant_v2(uuid) from public;
revoke all on function private.reject_case_history_mutation_v2() from public;

grant execute on function private.can_read_case_core_v2(uuid) to authenticated;

create or replace function public.quick_capture_case(
  p_operation_id uuid,
  p_profile_id uuid,
  p_expected_profile_version integer,
  p_case_type text,
  p_title text,
  p_description text,
  p_observed_at timestamptz,
  p_evidence_summary text,
  p_next_action_title text,
  p_next_action_due_at timestamptz
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
  organization_id uuid;
  membership_id uuid;
  case_id uuid := gen_random_uuid();
  evidence_id uuid;
  action_id uuid;
  event_id uuid;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
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
    or p_next_action_title is null
    or char_length(btrim(p_next_action_title)) = 0 then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select profile.organization_id
  into organization_id
  from public.student_subject_profiles as profile
  where profile.id = p_profile_id
  for update;

  if organization_id is null then
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

  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    organization_id,
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
    organization_id,
    p_profile_id,
    membership_id,
    p_case_type,
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
    organization_id,
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

  action_id := (
    select private.create_primary_case_action_v2(
      organization_id,
      case_id,
      membership_id,
      'review',
      btrim(p_next_action_title),
      p_next_action_due_at
    )
  );

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
    organization_id,
    case_id,
    'case_created',
    app_user_id,
    membership_id,
    jsonb_build_object(
      'profile_id', p_profile_id,
      'evidence_id', evidence_id,
      'action_id', action_id
    ),
    p_operation_id,
    'case_created'
  )
  returning id into event_id;

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
    organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

create or replace function public.confirm_case(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_next_action_title text,
  p_next_action_due_at timestamptz
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
  organization_id uuid;
  profile_id uuid;
  membership_id uuid;
  case_id uuid := p_case_id;
  case_status text;
  case_version integer;
  evidence_count integer;
  old_action_id uuid;
  action_id uuid;
  event_id uuid;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
begin
  if p_operation_id is null or p_case_id is null
    or p_expected_case_version is null or p_expected_case_version <= 0
    or p_next_action_title is null
    or char_length(btrim(p_next_action_title)) = 0 then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select learning_case.organization_id, learning_case.student_subject_profile_id
  into organization_id, profile_id
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id;

  if organization_id is null then
    raise exception using errcode = 'P0001', message = 'case_not_found';
  end if;

  perform 1
  from public.student_subject_profiles as profile
  where profile.id = profile_id
  for update;

  membership_id := (
    select private.current_teaching_membership_for_profile_v2(profile_id)
  );
  if membership_id is null then
    raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
  end if;

  select learning_case.status, learning_case.version
  into case_status, case_version
  from public.learning_cases as learning_case
  where learning_case.id = case_id
  for update;

  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    organization_id,
    p_operation_id,
    'confirm_case',
    'learning_case',
    p_case_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  if case_version <> p_expected_case_version then
    raise exception using errcode = 'P0001', message = 'version_conflict';
  end if;

  if case_status <> 'new' then
    raise exception using errcode = 'P0001', message = 'case_transition_not_allowed';
  end if;

  select count(*)::integer
  into evidence_count
  from public.case_evidence as evidence
  where evidence.learning_case_id = case_id
    and evidence.status = 'finalized';

  if evidence_count < 1 then
    raise exception using errcode = 'P0001', message = 'minimum_evidence_required';
  end if;

  old_action_id := (
    select private.finish_primary_case_action_v2(
      case_id,
      membership_id,
      timezone('utc', now()),
      'done'
    )
  );

  action_id := (
    select private.create_primary_case_action_v2(
      organization_id,
      case_id,
      membership_id,
      'practice',
      btrim(p_next_action_title),
      p_next_action_due_at
    )
  );

  update public.learning_cases
  set owner_membership_id = membership_id,
      status = 'confirmed',
      version = version + 1,
      updated_at = timezone('utc', now())
  where id = case_id;

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
    organization_id,
    case_id,
    'case_confirmed',
    app_user_id,
    membership_id,
    jsonb_build_object(
      'previous_action_id', old_action_id,
      'action_id', action_id
    ),
    p_operation_id,
    'case_confirmed'
  )
  returning id into event_id;

  perform private.assert_case_core_invariant_v2(case_id);

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', case_id,
    'action_id', action_id,
    'event_id', event_id,
    'status', 'confirmed',
    'case_version', case_version + 1
  );

  perform private.finish_case_operation_v2(
    organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

create or replace function public.add_case_evidence(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_source_type text,
  p_title text,
  p_observed_at timestamptz,
  p_summary text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
  organization_id uuid;
  profile_id uuid;
  membership_id uuid;
  case_status text;
  case_version integer;
  evidence_id uuid;
  event_id uuid;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
begin
  if p_operation_id is null or p_case_id is null
    or p_expected_case_version is null or p_expected_case_version <= 0
    or p_source_type is null or p_title is null
    or char_length(btrim(p_title)) = 0
    or p_observed_at is null or p_summary is null
    or char_length(btrim(p_summary)) = 0 then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select learning_case.organization_id, learning_case.student_subject_profile_id
  into organization_id, profile_id
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id;

  if organization_id is null then
    raise exception using errcode = 'P0001', message = 'case_not_found';
  end if;

  perform 1
  from public.student_subject_profiles as profile
  where profile.id = profile_id
  for update;

  membership_id := (
    select private.current_teaching_membership_for_profile_v2(profile_id)
  );
  if membership_id is null then
    raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
  end if;

  select learning_case.status, learning_case.version
  into case_status, case_version
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id
  for update;

  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    organization_id,
    p_operation_id,
    'add_case_evidence',
    'learning_case',
    p_case_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  if case_version <> p_expected_case_version then
    raise exception using errcode = 'P0001', message = 'version_conflict';
  end if;

  if case_status = 'closed' then
    raise exception using errcode = 'P0001', message = 'case_closed';
  end if;

  if p_source_type not in (
    'exam',
    'homework',
    'essay',
    'classwork',
    'quiz',
    'observation',
    'guardian_report',
    'other'
  ) then
    raise exception using errcode = 'P0001', message = 'invalid_evidence_source';
  end if;

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
    organization_id,
    p_case_id,
    p_source_type,
    btrim(p_title),
    p_observed_at,
    btrim(p_summary),
    'finalized',
    app_user_id,
    membership_id
  )
  returning id into evidence_id;

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
    organization_id,
    p_case_id,
    'evidence_recorded',
    app_user_id,
    membership_id,
    jsonb_build_object('evidence_id', evidence_id),
    p_operation_id,
    'evidence_recorded'
  )
  returning id into event_id;

  perform private.assert_case_core_invariant_v2(p_case_id);

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', p_case_id,
    'evidence_id', evidence_id,
    'event_id', event_id,
    'status', case_status,
    'case_version', case_version
  );

  perform private.finish_case_operation_v2(
    organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

create or replace function public.record_intervention(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_strategy text,
  p_notes text,
  p_occurred_at timestamptz,
  p_next_action_title text,
  p_next_action_due_at timestamptz
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
  organization_id uuid;
  profile_id uuid;
  membership_id uuid;
  case_status text;
  case_version integer;
  next_status text;
  intervention_id uuid;
  old_action_id uuid;
  action_id uuid;
  event_id uuid;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
begin
  if p_operation_id is null or p_case_id is null
    or p_expected_case_version is null or p_expected_case_version <= 0
    or p_strategy is null or char_length(btrim(p_strategy)) = 0
    or p_next_action_title is null
    or char_length(btrim(p_next_action_title)) = 0 then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select learning_case.organization_id, learning_case.student_subject_profile_id
  into organization_id, profile_id
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id;

  if organization_id is null then
    raise exception using errcode = 'P0001', message = 'case_not_found';
  end if;

  perform 1
  from public.student_subject_profiles as profile
  where profile.id = profile_id
  for update;

  membership_id := (
    select private.current_teaching_membership_for_profile_v2(profile_id)
  );
  if membership_id is null then
    raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
  end if;

  select learning_case.status, learning_case.version
  into case_status, case_version
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id
  for update;

  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    organization_id,
    p_operation_id,
    'record_intervention',
    'learning_case',
    p_case_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  if case_version <> p_expected_case_version then
    raise exception using errcode = 'P0001', message = 'version_conflict';
  end if;

  if case_status not in ('confirmed', 'intervening') then
    raise exception using errcode = 'P0001', message = 'case_transition_not_allowed';
  end if;

  next_status := case
    when case_status = 'confirmed' then 'intervening'
    else 'intervening'
  end;

  intervention_id := gen_random_uuid();

  insert into public.interventions (
    id,
    organization_id,
    learning_case_id,
    performed_by_app_user_id,
    performed_by_membership_id,
    strategy,
    notes,
    occurred_at
  )
  values (
    intervention_id,
    organization_id,
    p_case_id,
    app_user_id,
    membership_id,
    btrim(p_strategy),
    nullif(btrim(p_notes), ''),
    coalesce(p_occurred_at, timezone('utc', now()))
  );

  old_action_id := (
    select private.finish_primary_case_action_v2(
      p_case_id,
      membership_id,
      timezone('utc', now()),
      'done'
    )
  );

  action_id := (
    select private.create_primary_case_action_v2(
      organization_id,
      p_case_id,
      membership_id,
      'verify',
      btrim(p_next_action_title),
      p_next_action_due_at
    )
  );

  update public.learning_cases
  set status = next_status,
      version = version + 1,
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
    organization_id,
    p_case_id,
    'intervention_recorded',
    app_user_id,
    membership_id,
    jsonb_build_object(
      'intervention_id', intervention_id,
      'previous_action_id', old_action_id,
      'action_id', action_id
    ),
    p_operation_id,
    'intervention_recorded'
  )
  returning id into event_id;

  perform private.assert_case_core_invariant_v2(p_case_id);

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', p_case_id,
    'intervention_id', intervention_id,
    'action_id', action_id,
    'event_id', event_id,
    'status', next_status,
    'case_version', case_version + 1
  );

  perform private.finish_case_operation_v2(
    organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

create or replace function public.record_assessment(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_result text,
  p_evidence_summary text,
  p_notes text,
  p_assessed_at timestamptz,
  p_next_action_title text,
  p_next_action_due_at timestamptz
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
  organization_id uuid;
  profile_id uuid;
  membership_id uuid;
  case_status text;
  case_version integer;
  next_status text;
  assessment_id uuid;
  old_action_id uuid;
  action_id uuid;
  event_id uuid;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
begin
  if p_operation_id is null or p_case_id is null
    or p_expected_case_version is null or p_expected_case_version <= 0
    or p_result is null
    or p_evidence_summary is null
    or char_length(btrim(p_evidence_summary)) = 0
    or p_next_action_title is null
    or char_length(btrim(p_next_action_title)) = 0 then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select learning_case.organization_id, learning_case.student_subject_profile_id
  into organization_id, profile_id
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id;

  if organization_id is null then
    raise exception using errcode = 'P0001', message = 'case_not_found';
  end if;

  perform 1
  from public.student_subject_profiles as profile
  where profile.id = profile_id
  for update;

  membership_id := (
    select private.current_teaching_membership_for_profile_v2(profile_id)
  );
  if membership_id is null then
    raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
  end if;

  select learning_case.status, learning_case.version
  into case_status, case_version
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id
  for update;

  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    organization_id,
    p_operation_id,
    'record_assessment',
    'learning_case',
    p_case_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  if case_version <> p_expected_case_version then
    raise exception using errcode = 'P0001', message = 'version_conflict';
  end if;

  if case_status not in ('intervening', 'pending_verification') then
    raise exception using errcode = 'P0001', message = 'case_transition_not_allowed';
  end if;

  if p_result not in ('passed', 'partial', 'not_passed') then
    raise exception using errcode = 'P0001', message = 'invalid_assessment_result';
  end if;

  next_status := case
    when p_result = 'not_passed' then 'intervening'
    else 'pending_verification'
  end;

  assessment_id := gen_random_uuid();

  insert into public.assessments (
    id,
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
    assessment_id,
    organization_id,
    p_case_id,
    app_user_id,
    membership_id,
    p_result,
    btrim(p_evidence_summary),
    nullif(btrim(p_notes), ''),
    coalesce(p_assessed_at, timezone('utc', now()))
  );

  old_action_id := (
    select private.finish_primary_case_action_v2(
      p_case_id,
      membership_id,
      timezone('utc', now()),
      'done'
    )
  );

  action_id := (
    select private.create_primary_case_action_v2(
      organization_id,
      p_case_id,
      membership_id,
      case when p_result = 'not_passed' then 'practice' else 'review' end,
      btrim(p_next_action_title),
      p_next_action_due_at
    )
  );

  update public.learning_cases
  set status = next_status,
      version = version + 1,
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
    organization_id,
    p_case_id,
    'assessment_recorded',
    app_user_id,
    membership_id,
    jsonb_build_object(
      'assessment_id', assessment_id,
      'result', p_result,
      'previous_action_id', old_action_id,
      'action_id', action_id
    ),
    p_operation_id,
    'assessment_recorded'
  )
  returning id into event_id;

  perform private.assert_case_core_invariant_v2(p_case_id);

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', p_case_id,
    'assessment_id', assessment_id,
    'action_id', action_id,
    'event_id', event_id,
    'status', next_status,
    'case_version', case_version + 1
  );

  perform private.finish_case_operation_v2(
    organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

create or replace function public.stabilize_case(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_stabilized_at timestamptz,
  p_next_action_title text,
  p_next_action_due_at timestamptz
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
  organization_id uuid;
  profile_id uuid;
  membership_id uuid;
  case_status text;
  case_version integer;
  latest_result text;
  old_action_id uuid;
  action_id uuid;
  event_id uuid;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
begin
  if p_operation_id is null or p_case_id is null
    or p_expected_case_version is null or p_expected_case_version <= 0
    or p_next_action_title is null
    or char_length(btrim(p_next_action_title)) = 0 then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select learning_case.organization_id, learning_case.student_subject_profile_id
  into organization_id, profile_id
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id;

  if organization_id is null then
    raise exception using errcode = 'P0001', message = 'case_not_found';
  end if;

  perform 1
  from public.student_subject_profiles as profile
  where profile.id = profile_id
  for update;

  membership_id := (
    select private.current_teaching_membership_for_profile_v2(profile_id)
  );
  if membership_id is null then
    raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
  end if;

  select learning_case.status, learning_case.version
  into case_status, case_version
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id
  for update;

  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    organization_id,
    p_operation_id,
    'stabilize_case',
    'learning_case',
    p_case_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  if case_version <> p_expected_case_version then
    raise exception using errcode = 'P0001', message = 'version_conflict';
  end if;

  if case_status <> 'pending_verification' then
    raise exception using errcode = 'P0001', message = 'case_transition_not_allowed';
  end if;

  select assessment.result
  into latest_result
  from public.assessments as assessment
  where assessment.learning_case_id = p_case_id
  order by assessment.assessed_at desc, assessment.created_at desc, assessment.id desc
  limit 1;

  if latest_result is distinct from 'passed' then
    raise exception using errcode = 'P0001', message = 'latest_assessment_not_passed';
  end if;

  old_action_id := (
    select private.finish_primary_case_action_v2(
      p_case_id,
      membership_id,
      timezone('utc', now()),
      'done'
    )
  );

  action_id := (
    select private.create_primary_case_action_v2(
      organization_id,
      p_case_id,
      membership_id,
      'review',
      btrim(p_next_action_title),
      p_next_action_due_at
    )
  );

  update public.learning_cases
  set status = 'stable',
      stable_at = coalesce(p_stabilized_at, timezone('utc', now())),
      version = version + 1,
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
    organization_id,
    p_case_id,
    'case_stabilized',
    app_user_id,
    membership_id,
    jsonb_build_object(
      'assessment_result', latest_result,
      'previous_action_id', old_action_id,
      'action_id', action_id
    ),
    p_operation_id,
    'case_stabilized'
  )
  returning id into event_id;

  perform private.assert_case_core_invariant_v2(p_case_id);

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', p_case_id,
    'action_id', action_id,
    'event_id', event_id,
    'status', 'stable',
    'case_version', case_version + 1
  );

  perform private.finish_case_operation_v2(
    organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

create or replace function public.close_case(
  p_operation_id uuid,
  p_case_id uuid,
  p_expected_case_version integer,
  p_closed_at timestamptz
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
  v_membership_id uuid;
  v_case_status text;
  v_case_version integer;
  v_cancelled_action_id uuid;
  v_event_id uuid;
  v_is_claimed boolean;
  v_existing_result jsonb;
  v_command_result jsonb;
begin
  if p_operation_id is null or p_case_id is null
    or p_expected_case_version is null or p_expected_case_version <= 0 then
    raise exception using errcode = 'P0001', message = 'invalid_command_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select learning_case.organization_id, learning_case.student_subject_profile_id
  into v_organization_id, v_profile_id
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id;

  if v_organization_id is null then
    raise exception using errcode = 'P0001', message = 'case_not_found';
  end if;

  perform 1
  from public.student_subject_profiles as profile
  where profile.id = v_profile_id
  for update;

  v_membership_id := (
    select private.current_teaching_membership_for_profile_v2(v_profile_id)
  );
  if v_membership_id is null then
    raise exception using errcode = 'P0001', message = 'teaching_fact_gate';
  end if;

  if not exists (
    select 1
    from public.student_teacher_assignments as assignment
    where assignment.student_subject_profile_id = v_profile_id
      and assignment.organization_id = v_organization_id
      and assignment.membership_id = v_membership_id
      and assignment.assignment_role = 'lead'
      and assignment.status = 'active'
      and (now() at time zone (
        select organization.time_zone
        from public.organizations as organization
        where organization.id = v_organization_id
      ))::date >= assignment.active_from
      and (
        assignment.active_to is null
        or (now() at time zone (
          select organization.time_zone
          from public.organizations as organization
          where organization.id = v_organization_id
        ))::date <= assignment.active_to
      )
  ) then
    raise exception using errcode = 'P0001', message = 'owner_permission_required';
  end if;

  select learning_case.status, learning_case.version
  into v_case_status, v_case_version
  from public.learning_cases as learning_case
  where learning_case.id = p_case_id
  for update;

  select claimed, result
  into v_is_claimed, v_existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'close_case',
    'learning_case',
    p_case_id
  );

  if not v_is_claimed then
    return v_existing_result;
  end if;

  if v_case_version <> p_expected_case_version then
    raise exception using errcode = 'P0001', message = 'version_conflict';
  end if;

  if v_case_status <> 'stable' then
    raise exception using errcode = 'P0001', message = 'case_transition_not_allowed';
  end if;

  v_cancelled_action_id := (
    select private.finish_primary_case_action_v2(
      p_case_id,
      v_membership_id,
      coalesce(p_closed_at, timezone('utc', now())),
      'cancelled'
    )
  );

  update public.learning_cases
  set status = 'closed',
      closed_at = coalesce(p_closed_at, timezone('utc', now())),
      version = version + 1,
      updated_at = timezone('utc', now())
  where id = p_case_id;

  insert into public.case_events (
    v_organization_id,
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
    coalesce(p_closed_at, timezone('utc', now())),
    jsonb_build_object('v_cancelled_action_id', v_cancelled_action_id),
    p_operation_id,
    'case_closed'
  )
  returning id into v_event_id;

  perform private.assert_case_core_invariant_v2(p_case_id);

  v_command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'case_id', p_case_id,
    'v_event_id', v_event_id,
    'status', 'closed',
    'v_case_version', v_case_version + 1
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    v_command_result
  );

  return v_command_result;
end
$function$;

revoke all on function public.quick_capture_case(
  uuid,
  uuid,
  integer,
  text,
  text,
  text,
  timestamptz,
  text,
  text,
  timestamptz
) from public;
revoke all on function public.confirm_case(
  uuid,
  uuid,
  integer,
  text,
  timestamptz
) from public;
revoke all on function public.add_case_evidence(
  uuid,
  uuid,
  integer,
  text,
  text,
  timestamptz,
  text
) from public;
revoke all on function public.record_intervention(
  uuid,
  uuid,
  integer,
  text,
  text,
  timestamptz,
  text,
  timestamptz
) from public;
revoke all on function public.record_assessment(
  uuid,
  uuid,
  integer,
  text,
  text,
  text,
  timestamptz,
  text,
  timestamptz
) from public;
revoke all on function public.stabilize_case(
  uuid,
  uuid,
  integer,
  timestamptz,
  text,
  timestamptz
) from public;
revoke all on function public.close_case(
  uuid,
  uuid,
  integer,
  timestamptz
) from public;

grant execute on function public.quick_capture_case(
  uuid,
  uuid,
  integer,
  text,
  text,
  text,
  timestamptz,
  text,
  text,
  timestamptz
) to authenticated;
grant execute on function public.confirm_case(
  uuid,
  uuid,
  integer,
  text,
  timestamptz
) to authenticated;
grant execute on function public.add_case_evidence(
  uuid,
  uuid,
  integer,
  text,
  text,
  timestamptz,
  text
) to authenticated;
grant execute on function public.record_intervention(
  uuid,
  uuid,
  integer,
  text,
  text,
  timestamptz,
  text,
  timestamptz
) to authenticated;
grant execute on function public.record_assessment(
  uuid,
  uuid,
  integer,
  text,
  text,
  text,
  timestamptz,
  text,
  timestamptz
) to authenticated;
grant execute on function public.stabilize_case(
  uuid,
  uuid,
  integer,
  timestamptz,
  text,
  timestamptz
) to authenticated;
grant execute on function public.close_case(
  uuid,
  uuid,
  integer,
  timestamptz
) to authenticated;
revoke execute on function public.close_case(
  uuid,
  uuid,
  integer,
  timestamptz
) from anon;

alter table public.operation_receipts enable row level security;
alter table public.learning_cases enable row level security;
alter table public.case_events enable row level security;
alter table public.case_evidence enable row level security;
alter table public.interventions enable row level security;
alter table public.assessments enable row level security;
alter table public.case_actions enable row level security;

revoke all on table public.operation_receipts from anon, authenticated;
revoke all on table public.learning_cases from anon, authenticated;
revoke all on table public.case_events from anon, authenticated;
revoke all on table public.case_evidence from anon, authenticated;
revoke all on table public.interventions from anon, authenticated;
revoke all on table public.assessments from anon, authenticated;
revoke all on table public.case_actions from anon, authenticated;

grant select on table public.learning_cases to authenticated;
grant select on table public.case_events to authenticated;
grant select on table public.case_evidence to authenticated;
grant select on table public.interventions to authenticated;
grant select on table public.assessments to authenticated;
grant select on table public.case_actions to authenticated;

create policy "teachers can read learning cases"
on public.learning_cases
for select
to authenticated
using (
  (select private.can_read_case_core_v2(learning_cases.id))
);

create policy "teachers can read case events"
on public.case_events
for select
to authenticated
using (
  (select private.can_read_case_core_v2(case_events.learning_case_id))
);

create policy "teachers can read case evidence"
on public.case_evidence
for select
to authenticated
using (
  (select private.can_read_case_core_v2(case_evidence.learning_case_id))
);

create policy "teachers can read interventions"
on public.interventions
for select
to authenticated
using (
  (select private.can_read_case_core_v2(interventions.learning_case_id))
);

create policy "teachers can read assessments"
on public.assessments
for select
to authenticated
using (
  (select private.can_read_case_core_v2(assessments.learning_case_id))
);

create policy "teachers can read case actions"
on public.case_actions
for select
to authenticated
using (
  (select private.can_read_case_core_v2(case_actions.learning_case_id))
);
