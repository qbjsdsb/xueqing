-- Provenance-aware student + subject learning-record export.
--
-- This read boundary is intentionally narrow:
--   * callers supply one active student_subject_profile id;
--   * access is granted only through the existing teaching entitlement gate;
--   * historical facts are attributed to the membership that actually created,
--     performed, or assessed them; current assignment never rewrites history;
--   * creator memberships are not required to remain active, so handoff or
--     account disablement does not erase the historical record person.
--
-- The public function is SECURITY INVOKER. Privileged table reads stay inside
-- the private SECURITY DEFINER implementation, matching existing RPC patterns.

create or replace function private.list_student_subject_learning_records(
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
  current_status text
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  actor_membership_id uuid;
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

  actor_membership_id := (
    select private.current_teaching_membership_for_profile_v2(p_profile_id)
  );
  if actor_membership_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'teaching_fact_gate';
  end if;

  return query
  with created_event as (
    select distinct on (event.learning_case_id)
      event.learning_case_id,
      nullif(event.metadata ->> 'evidence_id', '')::uuid as evidence_id
    from public.case_events as event
    join public.learning_cases as event_case
      on event_case.id = event.learning_case_id
     and event_case.organization_id = event.organization_id
    where event_case.student_subject_profile_id = p_profile_id
      and event.event_type = 'case_created'
    order by event.learning_case_id, event.occurred_at, event.id
  ),
  raw_records as (
    select
      learning_case.id as record_id,
      learning_case.first_observed_at as occurred_at,
      student.name as student_name,
      organization_subject.display_name as subject_name,
      learning_case.title as issue_title,
      'case_created'::text as record_kind,
      case
        when nullif(btrim(coalesce(learning_case.description, '')), '') is null
          and initial_evidence.id is null
          then learning_case.title
        when nullif(btrim(coalesce(learning_case.description, '')), '') is null
          then concat(initial_evidence.title, '：', initial_evidence.summary)
        when initial_evidence.id is null
          or btrim(initial_evidence.summary) = btrim(learning_case.description)
          then btrim(learning_case.description)
        else concat(
          btrim(learning_case.description),
          E'\n学生表现：',
          btrim(initial_evidence.summary)
        )
      end as content,
      null::text as assessment_result,
      coalesce(nullif(btrim(creator_user.display_name), ''), '未命名成员')
        as teacher_name,
      (
        select action.title
        from public.case_actions as action
        where action.learning_case_id = learning_case.id
          and action.status = 'pending'
          and action.is_primary
        order by action.updated_at desc, action.id
        limit 1
      ) as next_step,
      coalesce((
        select count(*)::integer
        from public.case_evidence_attachments as attachment
        where attachment.case_evidence_id = initial_evidence.id
      ), 0) as attachment_count,
      learning_case.status as current_status,
      0 as sort_order
    from public.learning_cases as learning_case
    join public.student_subject_profiles as profile
      on profile.id = learning_case.student_subject_profile_id
     and profile.organization_id = learning_case.organization_id
    join public.students as student
      on student.id = profile.student_id
     and student.organization_id = profile.organization_id
    join public.organization_subjects as organization_subject
      on organization_subject.id = profile.organization_subject_id
     and organization_subject.organization_id = profile.organization_id
    join public.organization_memberships as creator_membership
      on creator_membership.id = learning_case.created_by_membership_id
     and creator_membership.organization_id = learning_case.organization_id
    join public.app_users as creator_user
      on creator_user.id = creator_membership.app_user_id
    left join created_event
      on created_event.learning_case_id = learning_case.id
    left join public.case_evidence as initial_evidence
      on initial_evidence.id = created_event.evidence_id
     and initial_evidence.learning_case_id = learning_case.id
    where learning_case.student_subject_profile_id = p_profile_id

    union all

    select
      evidence.id as record_id,
      evidence.observed_at as occurred_at,
      student.name as student_name,
      organization_subject.display_name as subject_name,
      learning_case.title as issue_title,
      'evidence'::text as record_kind,
      concat(evidence.title, '：', evidence.summary) as content,
      null::text as assessment_result,
      coalesce(nullif(btrim(creator_user.display_name), ''), '未命名成员')
        as teacher_name,
      (
        select action.title
        from public.case_actions as action
        where action.learning_case_id = learning_case.id
          and action.status = 'pending'
          and action.is_primary
        order by action.updated_at desc, action.id
        limit 1
      ) as next_step,
      coalesce((
        select count(*)::integer
        from public.case_evidence_attachments as attachment
        where attachment.case_evidence_id = evidence.id
      ), 0) as attachment_count,
      learning_case.status as current_status,
      1 as sort_order
    from public.case_evidence as evidence
    join public.learning_cases as learning_case
      on learning_case.id = evidence.learning_case_id
     and learning_case.organization_id = evidence.organization_id
    join public.student_subject_profiles as profile
      on profile.id = learning_case.student_subject_profile_id
     and profile.organization_id = learning_case.organization_id
    join public.students as student
      on student.id = profile.student_id
     and student.organization_id = profile.organization_id
    join public.organization_subjects as organization_subject
      on organization_subject.id = profile.organization_subject_id
     and organization_subject.organization_id = profile.organization_id
    join public.organization_memberships as creator_membership
      on creator_membership.id = evidence.created_by_membership_id
     and creator_membership.organization_id = evidence.organization_id
    join public.app_users as creator_user
      on creator_user.id = creator_membership.app_user_id
    where learning_case.student_subject_profile_id = p_profile_id
      and not exists (
        select 1
        from public.case_events as initial_event
        where initial_event.organization_id = evidence.organization_id
          and initial_event.learning_case_id = evidence.learning_case_id
          and initial_event.event_type = 'case_created'
          and initial_event.metadata ->> 'evidence_id' = evidence.id::text
      )

    union all

    select
      intervention.id as record_id,
      intervention.occurred_at as occurred_at,
      student.name as student_name,
      organization_subject.display_name as subject_name,
      learning_case.title as issue_title,
      'intervention'::text as record_kind,
      case
        when nullif(btrim(coalesce(intervention.notes, '')), '') is null
          then intervention.strategy
        else concat(intervention.strategy, E'\n', btrim(intervention.notes))
      end as content,
      null::text as assessment_result,
      coalesce(nullif(btrim(creator_user.display_name), ''), '未命名成员')
        as teacher_name,
      (
        select action.title
        from public.case_actions as action
        where action.learning_case_id = learning_case.id
          and action.status = 'pending'
          and action.is_primary
        order by action.updated_at desc, action.id
        limit 1
      ) as next_step,
      0 as attachment_count,
      learning_case.status as current_status,
      2 as sort_order
    from public.interventions as intervention
    join public.learning_cases as learning_case
      on learning_case.id = intervention.learning_case_id
     and learning_case.organization_id = intervention.organization_id
    join public.student_subject_profiles as profile
      on profile.id = learning_case.student_subject_profile_id
     and profile.organization_id = learning_case.organization_id
    join public.students as student
      on student.id = profile.student_id
     and student.organization_id = profile.organization_id
    join public.organization_subjects as organization_subject
      on organization_subject.id = profile.organization_subject_id
     and organization_subject.organization_id = profile.organization_id
    join public.organization_memberships as creator_membership
      on creator_membership.id = intervention.performed_by_membership_id
     and creator_membership.organization_id = intervention.organization_id
    join public.app_users as creator_user
      on creator_user.id = creator_membership.app_user_id
    where learning_case.student_subject_profile_id = p_profile_id

    union all

    select
      assessment.id as record_id,
      assessment.assessed_at as occurred_at,
      student.name as student_name,
      organization_subject.display_name as subject_name,
      learning_case.title as issue_title,
      'assessment'::text as record_kind,
      case
        when nullif(btrim(coalesce(assessment.notes, '')), '') is null
          then assessment.evidence_summary
        else concat(assessment.evidence_summary, E'\n', btrim(assessment.notes))
      end as content,
      assessment.result as assessment_result,
      coalesce(nullif(btrim(creator_user.display_name), ''), '未命名成员')
        as teacher_name,
      (
        select action.title
        from public.case_actions as action
        where action.learning_case_id = learning_case.id
          and action.status = 'pending'
          and action.is_primary
        order by action.updated_at desc, action.id
        limit 1
      ) as next_step,
      0 as attachment_count,
      learning_case.status as current_status,
      3 as sort_order
    from public.assessments as assessment
    join public.learning_cases as learning_case
      on learning_case.id = assessment.learning_case_id
     and learning_case.organization_id = assessment.organization_id
    join public.student_subject_profiles as profile
      on profile.id = learning_case.student_subject_profile_id
     and profile.organization_id = learning_case.organization_id
    join public.students as student
      on student.id = profile.student_id
     and student.organization_id = profile.organization_id
    join public.organization_subjects as organization_subject
      on organization_subject.id = profile.organization_subject_id
     and organization_subject.organization_id = profile.organization_id
    join public.organization_memberships as creator_membership
      on creator_membership.id = assessment.assessed_by_membership_id
     and creator_membership.organization_id = assessment.organization_id
    join public.app_users as creator_user
      on creator_user.id = creator_membership.app_user_id
    where learning_case.student_subject_profile_id = p_profile_id
  )
  select
    raw_records.record_id,
    raw_records.occurred_at,
    raw_records.student_name,
    raw_records.subject_name,
    raw_records.issue_title,
    raw_records.record_kind,
    raw_records.content,
    raw_records.assessment_result,
    raw_records.teacher_name,
    raw_records.next_step,
    raw_records.attachment_count,
    raw_records.current_status
  from raw_records
  order by
    raw_records.occurred_at,
    raw_records.sort_order,
    raw_records.record_id
  limit p_limit
  offset p_offset;
end
$function$;

revoke all on function private.list_student_subject_learning_records(
  uuid, integer, integer
) from public, anon, authenticated, service_role;
grant execute on function private.list_student_subject_learning_records(
  uuid, integer, integer
) to authenticated, service_role;

create or replace function public.list_student_subject_learning_records(
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
  current_status text
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select *
  from private.list_student_subject_learning_records(
    p_profile_id,
    p_limit,
    p_offset
  )
$function$;

revoke all on function public.list_student_subject_learning_records(
  uuid, integer, integer
) from public, anon, authenticated, service_role;
grant execute on function public.list_student_subject_learning_records(
  uuid, integer, integer
) to authenticated;

comment on function private.list_student_subject_learning_records(
  uuid, integer, integer
) is
  'Teaching-gated paged student-subject learning record export. Historical facts stay attributed to the membership that actually created, performed, or assessed them; current assignment does not rewrite provenance.';

comment on function public.list_student_subject_learning_records(
  uuid, integer, integer
) is
  'SECURITY INVOKER API wrapper for provenance-aware student-subject learning record export.';