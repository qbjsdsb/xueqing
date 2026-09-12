-- v0.3.8 stable-release compatibility hardening.
--
-- The public responsibility context RPC existed before Organization scope gained
-- Profile -> active Lead responsibility data. A release gate that only checks
-- the public RPC name can therefore produce a false green against an older
-- backend: the client loads an empty profile_responsibilities map and safely
-- blocks Organization Quick Capture even though the release was allowed.
--
-- Validate the private prerequisite while this migration runs with migration
-- privileges, then advertise the installed capability without making anon or
-- authenticated compatibility callers resolve objects in the private schema.

do $block$
begin
  if to_regprocedure(
    'private.workspace_responsibility_context_with_profile_leads_v2(uuid)'
  ) is null then
    raise exception using
      errcode = 'P0001',
      message = 'v038_profile_responsibility_prerequisite_missing';
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
        ) is not null
    )
  )
$function$;

revoke all on function public.xueqing_backend_compatibility()
  from public, anon, authenticated, service_role;
grant execute on function public.xueqing_backend_compatibility()
  to anon, authenticated, service_role;

comment on function public.xueqing_backend_compatibility() is
  'Data-free release compatibility contract. The v0.3.8 migration validates Organization Profile responsibility support before advertising the capability, while keeping the public probe callable without private-schema access.';