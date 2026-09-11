-- v0.3.6 export integrity: teacher-oriented exports must obey the same
-- record-validity boundary as ordinary workspace/student exports.
--
-- The legacy manager projection predates learning_cases.record_state and pages
-- raw facts before the caller can tell whether their Case was later voided.
-- Filtering only after a raw page would be incorrect because a short filtered
-- page can make the Flutter paginator stop before later valid history.
--
-- Keep the public RPC/signature stable for installed clients. The replacement
-- private implementation scans the proven provenance-aware base projection in
-- raw pages, resolves each row back to its Learning Case, removes voided Cases,
-- and only then applies the requested offset/limit. Historical actor attribution
-- stays untouched.

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
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_source_offset integer := 0;
  v_source_batch_count integer := 0;
  v_active_seen integer := 0;
  v_emitted integer := 0;
  v_row record;
begin
  if p_organization_id is null
    or p_membership_id is null
    or p_limit is null
    or p_limit < 1
    or p_limit > 500
    or p_offset is null
    or p_offset < 0 then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_command_input';
  end if;

  loop
    v_source_batch_count := 0;

    for v_row in
      with mapped as (
        select
          coalesce(
            case when base_record.record_kind = 'case_created'
              then base_record.record_id end,
            evidence.learning_case_id,
            intervention.learning_case_id,
            assessment.learning_case_id
          ) as mapped_case_id,
          base_record.*
        from private.list_teacher_learning_records(
          p_organization_id,
          p_membership_id,
          500,
          v_source_offset
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
        mapped.*,
        learning_case.record_state as mapped_record_state,
        case mapped.record_kind
          when 'evidence' then coalesce((
            select array_agg(
              attachment.storage_path
              order by attachment.created_at, attachment.id
            )
            from public.case_evidence_attachments as attachment
            where attachment.case_evidence_id = mapped.record_id
          ), array[]::text[])
          when 'case_created' then coalesce((
            select array_agg(
              attachment.storage_path
              order by attachment.created_at, attachment.id
            )
            from public.case_events as created_event
            join public.case_evidence_attachments as attachment
              on attachment.learning_case_id = created_event.learning_case_id
             and attachment.case_evidence_id::text =
                 nullif(created_event.metadata ->> 'evidence_id', '')
            where created_event.learning_case_id = mapped.record_id
              and created_event.event_type = 'case_created'
          ), array[]::text[])
          else array[]::text[]
        end as mapped_attachment_paths
      from mapped
      left join public.learning_cases as learning_case
        on learning_case.id = mapped.mapped_case_id
       and learning_case.organization_id = p_organization_id
      order by
        mapped.occurred_at,
        case mapped.record_kind
          when 'case_created' then 0
          when 'evidence' then 1
          when 'intervention' then 2
          when 'assessment' then 3
          else 9
        end,
        mapped.record_id
    loop
      v_source_batch_count := v_source_batch_count + 1;

      if v_row.mapped_case_id is null
        or v_row.mapped_record_state is distinct from 'active' then
        continue;
      end if;

      if v_active_seen < p_offset then
        v_active_seen := v_active_seen + 1;
        continue;
      end if;

      record_id := v_row.record_id;
      occurred_at := v_row.occurred_at;
      student_name := v_row.student_name;
      subject_name := v_row.subject_name;
      issue_title := v_row.issue_title;
      record_kind := v_row.record_kind;
      content := v_row.content;
      assessment_result := v_row.assessment_result;
      attachment_count := v_row.attachment_count;
      current_status := v_row.current_status;
      attachment_paths := v_row.mapped_attachment_paths;

      return next;
      v_emitted := v_emitted + 1;
      if v_emitted >= p_limit then
        return;
      end if;
    end loop;

    if v_source_batch_count < 500 then
      return;
    end if;

    v_source_offset := v_source_offset + v_source_batch_count;
  end loop;
end
$function$;

revoke all on function private.list_teacher_learning_records_with_attachments(
  uuid, uuid, integer, integer
) from public, anon, authenticated, service_role;
grant execute on function private.list_teacher_learning_records_with_attachments(
  uuid, uuid, integer, integer
) to authenticated, service_role;

comment on function private.list_teacher_learning_records_with_attachments(
  uuid, uuid, integer, integer
) is
  'Manager-gated provenance-aware teacher export. Voided Learning Cases are removed before pagination so erroneous history cannot reappear or truncate later valid records.';
