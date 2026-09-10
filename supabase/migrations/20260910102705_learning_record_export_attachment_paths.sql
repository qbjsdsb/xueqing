-- v0.3.1: attachment-aware learning-record export boundaries.
--
-- Existing v0.3.0 export RPCs remain untouched so installed clients continue
-- to work. The new functions reuse their established teaching/manager gates
-- and only add the private Storage paths that belong to each exported fact.
-- Object bytes are still protected by Storage RLS and are never exposed here.

create or replace function private.list_student_subject_learning_records_with_attachments(
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
security definer
set search_path = ''
as $function$
  select
    base_record.record_id,
    base_record.occurred_at,
    base_record.student_name,
    base_record.subject_name,
    base_record.issue_title,
    base_record.record_kind,
    base_record.content,
    base_record.assessment_result,
    base_record.teacher_name,
    base_record.next_step,
    base_record.attachment_count,
    base_record.current_status,
    case base_record.record_kind
      when 'evidence' then coalesce((
        select array_agg(attachment.storage_path order by attachment.created_at, attachment.id)
        from public.case_evidence_attachments as attachment
        where attachment.case_evidence_id = base_record.record_id
      ), array[]::text[])
      when 'case_created' then coalesce((
        select array_agg(attachment.storage_path order by attachment.created_at, attachment.id)
        from public.case_events as created_event
        join public.case_evidence_attachments as attachment
          on attachment.learning_case_id = created_event.learning_case_id
         and attachment.case_evidence_id::text =
             nullif(created_event.metadata ->> 'evidence_id', '')
        where created_event.learning_case_id = base_record.record_id
          and created_event.event_type = 'case_created'
      ), array[]::text[])
      else array[]::text[]
    end as attachment_paths
  from private.list_student_subject_learning_records(
    p_profile_id,
    p_limit,
    p_offset
  ) as base_record
$function$;

revoke all on function private.list_student_subject_learning_records_with_attachments(
  uuid, integer, integer
) from public, anon, authenticated, service_role;
grant execute on function private.list_student_subject_learning_records_with_attachments(
  uuid, integer, integer
) to authenticated, service_role;

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
  select *
  from private.list_student_subject_learning_records_with_attachments(
    p_profile_id,
    p_limit,
    p_offset
  )
$function$;

revoke all on function public.list_student_subject_learning_records_with_attachments(
  uuid, integer, integer
) from public, anon, authenticated, service_role;
grant execute on function public.list_student_subject_learning_records_with_attachments(
  uuid, integer, integer
) to authenticated;

create or replace function private.list_teacher_learning_records_with_attachments(
  p_organization_id uuid,
  p_membership_id uuid,
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
  attachment_count integer,
  current_status text,
  attachment_paths text[]
)
language sql
stable
security definer
set search_path = ''
as $function$
  select
    base_record.record_id,
    base_record.occurred_at,
    base_record.student_name,
    base_record.subject_name,
    base_record.issue_title,
    base_record.record_kind,
    base_record.content,
    base_record.assessment_result,
    base_record.attachment_count,
    base_record.current_status,
    case base_record.record_kind
      when 'evidence' then coalesce((
        select array_agg(attachment.storage_path order by attachment.created_at, attachment.id)
        from public.case_evidence_attachments as attachment
        where attachment.case_evidence_id = base_record.record_id
      ), array[]::text[])
      when 'case_created' then coalesce((
        select array_agg(attachment.storage_path order by attachment.created_at, attachment.id)
        from public.case_events as created_event
        join public.case_evidence_attachments as attachment
          on attachment.learning_case_id = created_event.learning_case_id
         and attachment.case_evidence_id::text =
             nullif(created_event.metadata ->> 'evidence_id', '')
        where created_event.learning_case_id = base_record.record_id
          and created_event.event_type = 'case_created'
      ), array[]::text[])
      else array[]::text[]
    end as attachment_paths
  from private.list_teacher_learning_records(
    p_organization_id,
    p_membership_id,
    p_limit,
    p_offset
  ) as base_record
$function$;

revoke all on function private.list_teacher_learning_records_with_attachments(
  uuid, uuid, integer, integer
) from public, anon, authenticated, service_role;
grant execute on function private.list_teacher_learning_records_with_attachments(
  uuid, uuid, integer, integer
) to authenticated, service_role;

create or replace function public.list_teacher_learning_records_with_attachments(
  p_organization_id uuid,
  p_membership_id uuid,
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
  attachment_count integer,
  current_status text,
  attachment_paths text[]
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select *
  from private.list_teacher_learning_records_with_attachments(
    p_organization_id,
    p_membership_id,
    p_limit,
    p_offset
  )
$function$;

revoke all on function public.list_teacher_learning_records_with_attachments(
  uuid, uuid, integer, integer
) from public, anon, authenticated, service_role;
grant execute on function public.list_teacher_learning_records_with_attachments(
  uuid, uuid, integer, integer
) to authenticated;

comment on function public.list_student_subject_learning_records_with_attachments(
  uuid, integer, integer
) is
  'v0.3.1 teaching-gated export projection that adds private attachment paths for offline workbook embedding; Storage RLS still protects object bytes.';

comment on function public.list_teacher_learning_records_with_attachments(
  uuid, uuid, integer, integer
) is
  'v0.3.1 manager-gated export projection that adds private attachment paths for offline workbook embedding; Storage RLS still protects object bytes.';
