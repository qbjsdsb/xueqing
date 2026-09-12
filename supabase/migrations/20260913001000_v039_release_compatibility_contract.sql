-- v0.3.9 stable-release compatibility contract.
--
-- v0.3.9 adds two server-authoritative responsibility workflows after v0.3.8:
--   * previewed, explicit teaching responsibility handoff;
--   * establishing a missing active Lead for an active student-subject service.
--
-- `schema_version` remains the stable structural/integrity floor shared with
-- older clients. Newer optional release requirements are advertised as named
-- capabilities so an older stable client is not coupled to a later migration
-- timestamp. A v0.3.9 publisher must require the two capabilities below.

do $block$
begin
  if to_regprocedure(
    'public.preview_organization_student_teacher_handoff(uuid,uuid,uuid)'
  ) is null
    or to_regprocedure(
      'public.commit_organization_student_teacher_handoff(uuid,uuid,uuid,integer,uuid,jsonb,jsonb)'
    ) is null then
    raise exception using
      errcode = 'P0001',
      message = 'v039_explicit_teaching_handoff_prerequisite_missing';
  end if;

  if to_regprocedure(
    'public.set_organization_student_subject_lead(uuid,uuid,uuid,integer,uuid)'
  ) is null then
    raise exception using
      errcode = 'P0001',
      message = 'v039_set_student_subject_lead_prerequisite_missing';
  end if;
end
$block$;

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
        ),
      'responsibility_read_model',
        to_regprocedure('public.get_workspace_responsibility_context(uuid)') is not null,
      'organization_profile_responsibility', true,
      'responsibility_safe_quick_capture',
        to_regprocedure(
          'public.quick_capture_case_in_scope(uuid,uuid,integer,text,text,text,timestamp with time zone,text,text,timestamp with time zone,uuid,text,uuid)'
        ) is not null,
      'explicit_teaching_handoff',
        to_regprocedure(
          'public.preview_organization_student_teacher_handoff(uuid,uuid,uuid)'
        ) is not null
        and to_regprocedure(
          'public.commit_organization_student_teacher_handoff(uuid,uuid,uuid,integer,uuid,jsonb,jsonb)'
        ) is not null,
      'set_student_subject_lead',
        to_regprocedure(
          'public.set_organization_student_subject_lead(uuid,uuid,uuid,integer,uuid)'
        ) is not null
    )
  )
$function$;

revoke all on function public.xueqing_backend_compatibility()
  from public, anon, authenticated, service_role;
grant execute on function public.xueqing_backend_compatibility()
  to anon, authenticated, service_role;

comment on function public.xueqing_backend_compatibility() is
  'Data-free stable-release compatibility contract. v0.3.9 adds capability flags for explicit teaching handoff and missing-Lead assignment while preserving the stable structural schema floor.';
