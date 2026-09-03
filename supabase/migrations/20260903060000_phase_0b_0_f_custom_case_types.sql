-- Phase 0B.0-F: organization-managed Case type labels.
-- This is a fictional/local compatibility migration. It is not a
-- production migration or permission to import real student data.

create table public.organization_case_types (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  code text not null
    check (char_length(btrim(code)) > 0),
  display_name text not null
    check (
      char_length(btrim(display_name)) > 0
      and char_length(btrim(display_name)) <= 64
    ),
  base_case_type text not null
    check (base_case_type in ('knowledge', 'habit', 'exam_strategy', 'other')),
  status text not null default 'active'
    check (status in ('active', 'archived')),
  sort_order integer not null default 0
    check (sort_order >= 0),
  version integer not null default 1
    check (version > 0),
  created_by_app_user_id uuid not null
    references public.app_users(id) on delete restrict,
  created_by_membership_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint organization_case_types_created_by_membership_fk
    foreign key (created_by_membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict,
  constraint organization_case_types_id_organization_key
    unique (id, organization_id),
  constraint organization_case_types_org_code_key
    unique (organization_id, code)
);

create unique index organization_case_types_active_name_key
  on public.organization_case_types (organization_id, lower(btrim(display_name)))
  where status = 'active';

alter table public.learning_cases
  add column if not exists organization_case_type_id uuid,
  add column if not exists case_type_label_snapshot text;

alter table public.learning_cases
  add constraint learning_cases_case_type_reference_fk
    foreign key (organization_case_type_id, organization_id)
    references public.organization_case_types(id, organization_id)
    on delete restrict,
  add constraint learning_cases_case_type_snapshot_check
    check (
      (organization_case_type_id is null and case_type_label_snapshot is null)
      or (
        organization_case_type_id is not null
        and case_type_label_snapshot is not null
        and char_length(btrim(case_type_label_snapshot)) > 0
      )
    );

create index learning_cases_organization_case_type_idx
  on public.learning_cases (organization_id, organization_case_type_id);

create or replace function private.validate_learning_case_type_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  custom_case_type_base text;
  custom_case_type_label text;
begin
  if new.organization_case_type_id is null then
    if new.case_type_label_snapshot is not null then
      raise exception using errcode = 'P0001', message = 'invalid_case_type_snapshot';
    end if;
    return new;
  end if;

  select case_type.base_case_type, case_type.display_name
  into custom_case_type_base, custom_case_type_label
  from public.organization_case_types as case_type
  where case_type.id = new.organization_case_type_id
    and case_type.organization_id = new.organization_id;

  if custom_case_type_label is null
    or custom_case_type_base is distinct from new.case_type then
    raise exception using errcode = 'P0001', message = 'invalid_case_type_reference';
  end if;

  if tg_op = 'INSERT' then
    new.case_type_label_snapshot := custom_case_type_label;
  elsif new.organization_case_type_id is distinct from old.organization_case_type_id
    or new.case_type_label_snapshot is distinct from old.case_type_label_snapshot then
    raise exception using errcode = 'P0001', message = 'case_type_immutable';
  end if;

  return new;
end
$function$;

create trigger learning_cases_case_type_guard
before insert or update of
  organization_id,
  case_type,
  organization_case_type_id,
  case_type_label_snapshot
on public.learning_cases
for each row
execute function private.validate_learning_case_type_v2();

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
  organization_id uuid;
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

  if p_organization_case_type_id is not null then
    select case_type.base_case_type, case_type.display_name
    into custom_case_type_base, custom_case_type_label
    from public.organization_case_types as case_type
    where case_type.id = p_organization_case_type_id
      and case_type.organization_id = organization_id
      and case_type.status = 'active';

    if custom_case_type_label is null
      or custom_case_type_base is distinct from p_case_type then
      raise exception using errcode = 'P0001', message = 'invalid_case_type';
    end if;
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
    organization_id,
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
      'case_type', p_case_type,
      'organization_case_type_id', p_organization_case_type_id,
      'case_type_label', custom_case_type_label,
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
begin
  return private.quick_capture_case_v2(
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
    null
  );
end
$function$;

create or replace function public.quick_capture_case_with_type(
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
begin
  if p_organization_case_type_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_case_type';
  end if;

  return private.quick_capture_case_v2(
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
    p_organization_case_type_id
  );
end
$function$;

create or replace function private.case_type_result_v2(
  target_case_type_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  select jsonb_build_object(
    'id', case_type.id,
    'display_name', case_type.display_name,
    'base_case_type', case_type.base_case_type,
    'status', case_type.status,
    'sort_order', case_type.sort_order,
    'version', case_type.version
  )
  from public.organization_case_types as case_type
  where case_type.id = target_case_type_id
$function$;

create or replace function private.can_manage_case_types_v2(
  target_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.organization_memberships as membership
    join public.membership_roles as membership_role
      on membership_role.membership_id = membership.id
     and membership_role.organization_id = membership.organization_id
     and membership_role.role in ('org_admin', 'academic_admin')
    join public.organizations as organization
      on organization.id = membership.organization_id
     and organization.status = 'active'
    where membership.organization_id = target_organization_id
      and membership.app_user_id =
        (select private.current_app_user_id_v2())
      and membership.status = 'active'
  )
$function$;

create or replace function public.create_organization_case_type(
  p_organization_id uuid,
  p_display_name text,
  p_base_case_type text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
  membership_id uuid;
  case_type_id uuid := gen_random_uuid();
  command_result jsonb;
begin
  if p_organization_id is null
    or p_display_name is null
    or char_length(btrim(p_display_name)) = 0
    or char_length(btrim(p_display_name)) > 64
    or btrim(p_display_name) in ('知识漏洞', '学习习惯', '考试技巧', '其他')
    or p_base_case_type is null
    or p_base_case_type not in ('knowledge', 'habit', 'exam_strategy', 'other') then
    raise exception using errcode = 'P0001', message = 'invalid_case_type_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  if not (select private.can_manage_case_types_v2(p_organization_id)) then
    raise exception using errcode = 'P0001', message = 'case_type_manager_required';
  end if;

  select membership.id
  into membership_id
  from public.organization_memberships as membership
  where membership.organization_id = p_organization_id
    and membership.app_user_id = app_user_id
    and membership.status = 'active'
  order by membership.id
  limit 1;

  if membership_id is null then
    raise exception using errcode = 'P0001', message = 'case_type_manager_required';
  end if;

  begin
    insert into public.organization_case_types (
      id,
      organization_id,
      code,
      display_name,
      base_case_type,
      status,
      created_by_app_user_id,
      created_by_membership_id
    )
    values (
      case_type_id,
      p_organization_id,
      'custom_' || replace(case_type_id::text, '-', ''),
      btrim(p_display_name),
      p_base_case_type,
      'active',
      app_user_id,
      membership_id
    );
  exception
    when unique_violation then
      raise exception using errcode = 'P0001', message = 'case_type_name_taken';
  end;

  command_result := private.case_type_result_v2(case_type_id);
  if command_result is null then
    raise exception using errcode = 'P0001', message = 'case_type_create_failed';
  end if;
  return command_result;
end
$function$;

create or replace function public.rename_organization_case_type(
  p_case_type_id uuid,
  p_display_name text,
  p_expected_version integer
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
  case_type_status text;
  case_type_version integer;
  command_result jsonb;
begin
  if p_case_type_id is null
    or p_display_name is null
    or char_length(btrim(p_display_name)) = 0
    or char_length(btrim(p_display_name)) > 64
    or btrim(p_display_name) in ('知识漏洞', '学习习惯', '考试技巧', '其他')
    or p_expected_version is null
    or p_expected_version <= 0 then
    raise exception using errcode = 'P0001', message = 'invalid_case_type_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select case_type.organization_id, case_type.status, case_type.version
  into organization_id, case_type_status, case_type_version
  from public.organization_case_types as case_type
  where case_type.id = p_case_type_id
  for update;

  if organization_id is null then
    raise exception using errcode = 'P0001', message = 'case_type_not_found';
  end if;

  if not (select private.can_manage_case_types_v2(organization_id)) then
    raise exception using errcode = 'P0001', message = 'case_type_manager_required';
  end if;

  if case_type_status <> 'active' then
    raise exception using errcode = 'P0001', message = 'case_type_archived';
  end if;

  if case_type_version <> p_expected_version then
    raise exception using errcode = 'P0001', message = 'version_conflict';
  end if;

  begin
    update public.organization_case_types
    set display_name = btrim(p_display_name),
        version = version + 1,
        updated_at = timezone('utc', now())
    where id = p_case_type_id;
  exception
    when unique_violation then
      raise exception using errcode = 'P0001', message = 'case_type_name_taken';
  end;

  command_result := private.case_type_result_v2(p_case_type_id);
  if command_result is null then
    raise exception using errcode = 'P0001', message = 'case_type_update_failed';
  end if;
  return command_result;
end
$function$;

create or replace function public.archive_organization_case_type(
  p_case_type_id uuid,
  p_expected_version integer
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
  case_type_status text;
  case_type_version integer;
  command_result jsonb;
begin
  if p_case_type_id is null
    or p_expected_version is null
    or p_expected_version <= 0 then
    raise exception using errcode = 'P0001', message = 'invalid_case_type_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_live_session';
  end if;

  select case_type.organization_id, case_type.status, case_type.version
  into organization_id, case_type_status, case_type_version
  from public.organization_case_types as case_type
  where case_type.id = p_case_type_id
  for update;

  if organization_id is null then
    raise exception using errcode = 'P0001', message = 'case_type_not_found';
  end if;

  if not (select private.can_manage_case_types_v2(organization_id)) then
    raise exception using errcode = 'P0001', message = 'case_type_manager_required';
  end if;

  if case_type_status = 'archived' then
    return private.case_type_result_v2(p_case_type_id);
  end if;

  if case_type_version <> p_expected_version then
    raise exception using errcode = 'P0001', message = 'version_conflict';
  end if;

  update public.organization_case_types
  set status = 'archived',
      version = version + 1,
      updated_at = timezone('utc', now())
  where id = p_case_type_id;

  command_result := private.case_type_result_v2(p_case_type_id);
  if command_result is null then
    raise exception using errcode = 'P0001', message = 'case_type_archive_failed';
  end if;
  return command_result;
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
revoke all on function public.quick_capture_case_with_type(
  uuid,
  uuid,
  integer,
  text,
  text,
  text,
  timestamptz,
  text,
  text,
  timestamptz,
  uuid
) from public;
revoke all on function public.create_organization_case_type(
  uuid,
  text,
  text
) from public;
revoke all on function public.rename_organization_case_type(
  uuid,
  text,
  integer
) from public;
revoke all on function public.archive_organization_case_type(
  uuid,
  integer
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
grant execute on function public.quick_capture_case_with_type(
  uuid,
  uuid,
  integer,
  text,
  text,
  text,
  timestamptz,
  text,
  text,
  timestamptz,
  uuid
) to authenticated;
grant execute on function public.create_organization_case_type(
  uuid,
  text,
  text
) to authenticated;
grant execute on function public.rename_organization_case_type(
  uuid,
  text,
  integer
) to authenticated;
grant execute on function public.archive_organization_case_type(
  uuid,
  integer
) to authenticated;

revoke execute on function public.quick_capture_case(
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
) from anon;
revoke execute on function public.quick_capture_case_with_type(
  uuid,
  uuid,
  integer,
  text,
  text,
  text,
  timestamptz,
  text,
  text,
  timestamptz,
  uuid
) from anon;
revoke execute on function public.create_organization_case_type(
  uuid,
  text,
  text
) from anon;
revoke execute on function public.rename_organization_case_type(
  uuid,
  text,
  integer
) from anon;
revoke execute on function public.archive_organization_case_type(
  uuid,
  integer
) from anon;

alter table public.organization_case_types enable row level security;

revoke all on table public.organization_case_types from anon, authenticated;
grant select on table public.organization_case_types to authenticated;

create policy "members can read organization Case types"
on public.organization_case_types
for select
to authenticated
using (
  (select private.can_read_organization_v2(
    organization_case_types.organization_id
  ))
);