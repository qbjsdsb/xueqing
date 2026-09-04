-- Phase 0B.0-O: initialize organization subjects from the global catalog.
--
-- This is a fictional/development migration. It must be reviewed again
-- before any production deployment or real student data is introduced.
--
-- The global subjects table remains read-only to clients. Managers can add an
-- active global subject to their own organization through the guarded command.

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
    'create_organization_student',
    'create_organization_subject'
  ));

alter table public.operation_receipts
  drop constraint if exists operation_receipts_target_type_check;

alter table public.operation_receipts
  add constraint operation_receipts_target_type_check
  check (target_type in (
    'student_subject_profile',
    'learning_case',
    'case_action',
    'organization'
  ));

create or replace function public.list_organization_subject_catalog(
  p_organization_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
begin
  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  if p_organization_id is null
    or not (select private.can_manage_organization_v2(p_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', subject.id,
          'code', subject.code,
          'display_name', subject.name
        )
        order by subject.name, subject.code, subject.id
      )
      from public.subjects as subject
      where subject.status = 'active'
        and not exists (
          select 1
          from public.organization_subjects as organization_subject
          where organization_subject.organization_id = p_organization_id
            and organization_subject.subject_id = subject.id
        )
    ),
    '[]'::jsonb
  );
end
$function$;

create or replace function public.create_organization_subject(
  p_operation_id uuid,
  p_organization_id uuid,
  p_subject_id uuid
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
  v_organization_name text;
  v_subject_id uuid;
  v_subject_code text;
  v_subject_name text;
  organization_subject_id uuid;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
begin
  if p_operation_id is null
    or p_organization_id is null
    or p_subject_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_organization_subject_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select organization.id, organization.name
  into v_organization_id, v_organization_name
  from public.organizations as organization
  where organization.id = p_organization_id
    and organization.status = 'active'
  for update;

  if v_organization_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'organization_not_found';
  end if;

  if not (select private.can_manage_organization_v2(v_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  select subject.id, subject.code, subject.name
  into v_subject_id, v_subject_code, v_subject_name
  from public.subjects as subject
  where subject.id = p_subject_id
    and subject.status = 'active'
  for update;

  if v_subject_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'subject_not_found';
  end if;

  -- Claim before the organization duplicate check so an exact retry returns
  -- the committed result instead of being mistaken for a new duplicate.
  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'create_organization_subject',
    'organization',
    v_organization_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  if exists (
    select 1
    from public.organization_subjects as organization_subject
    where organization_subject.organization_id = v_organization_id
      and organization_subject.subject_id = v_subject_id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_subject_already_enabled';
  end if;

  organization_subject_id := gen_random_uuid();

  insert into public.organization_subjects (
    id,
    organization_id,
    subject_id,
    display_name,
    status
  )
  values (
    organization_subject_id,
    v_organization_id,
    v_subject_id,
    v_subject_name,
    'active'
  );

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', v_organization_id,
    'organization_name', v_organization_name,
    'organization_subject_id', organization_subject_id,
    'subject_id', v_subject_id,
    'subject_code', v_subject_code,
    'subject_name', v_subject_name
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

revoke all on function public.list_organization_subject_catalog(uuid) from public;
grant execute on function public.list_organization_subject_catalog(uuid) to authenticated;
revoke execute on function public.list_organization_subject_catalog(uuid) from anon;

revoke all on function public.create_organization_subject(uuid, uuid, uuid) from public;
grant execute on function public.create_organization_subject(uuid, uuid, uuid)
  to authenticated;
revoke execute on function public.create_organization_subject(uuid, uuid, uuid)
  from anon;
