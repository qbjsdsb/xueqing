-- v0.3.6 hardening: page over valid learning records, not over raw rows that
-- may later be discarded because their Learning Case was voided.
--
-- The first v0.3.6 projection wrapped the v0.3.5 paged projection and then
-- filtered record_state. That can return a short page before the true end of
-- the active record stream (for example when a voided Case occupies the first
-- raw row). Flutter correctly treats a short page as EOF, so later valid
-- records could be missed. This implementation scans raw pages internally and
-- applies p_offset / p_limit only after record validity has been checked.

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
  if p_profile_id is null
    or p_limit is null
    or p_limit < 1
    or p_limit > 500
    or p_offset is null
    or p_offset < 0 then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_command_input';
  end if;

  if (select private.current_teaching_membership_for_profile_v2(p_profile_id))
    is null then
    raise exception using
      errcode = 'P0001',
      message = 'teaching_fact_gate';
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
        from private.list_student_subject_learning_records_with_attachments(
          p_profile_id,
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
        learning_case.record_state as mapped_record_state
      from mapped
      left join public.learning_cases as learning_case
        on learning_case.id = mapped.mapped_case_id
       and learning_case.student_subject_profile_id = p_profile_id
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

      learning_case_id := v_row.mapped_case_id;
      record_id := v_row.record_id;
      occurred_at := v_row.occurred_at;
      student_name := v_row.student_name;
      subject_name := v_row.subject_name;
      issue_title := v_row.issue_title;
      record_kind := v_row.record_kind;
      content := v_row.content;
      assessment_result := v_row.assessment_result;
      teacher_name := v_row.teacher_name;
      next_step := v_row.next_step;
      attachment_count := v_row.attachment_count;
      current_status := v_row.current_status;
      attachment_paths := v_row.attachment_paths;

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

revoke all on function private.list_student_subject_learning_records_v2_with_attachments(
  uuid, integer, integer
) from public, anon, authenticated, service_role;
grant execute on function private.list_student_subject_learning_records_v2_with_attachments(
  uuid, integer, integer
) to authenticated, service_role;

comment on function private.list_student_subject_learning_records_v2_with_attachments(
  uuid, integer, integer
) is
  'Teaching-gated active-record projection. Pagination is applied after voided Learning Cases are removed so short pages cannot truncate later valid history.';

-- Advance the compatibility floor only after the pagination semantics are safe.
create or replace function public.xueqing_backend_compatibility()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  select jsonb_build_object(
    'contract_version', 1,
    'schema_version', '20260911190000',
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
