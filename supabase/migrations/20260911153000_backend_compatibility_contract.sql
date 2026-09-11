-- v0.3.5: data-free production backend compatibility contract.
-- Stable release CI calls this with the public publishable key before signing
-- and publishing clients. It exposes no student/member data or credentials.

create or replace function public.xueqing_backend_compatibility()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select jsonb_build_object(
    'contract_version', 1,
    'schema_version', '20260911153000',
    'capabilities', jsonb_build_object(
      'student_profile_edit',
        to_regprocedure(
          'public.update_organization_student_profile(uuid,uuid,uuid,integer,text,text,text,text,text)'
        ) is not null,
      'learning_record_export_attachments',
        to_regprocedure(
          'public.list_student_subject_learning_records_with_attachments(uuid,integer,integer)'
        ) is not null
    )
  )
$function$;

revoke all on function public.xueqing_backend_compatibility()
  from public, anon, authenticated, service_role;
grant execute on function public.xueqing_backend_compatibility()
  to anon, authenticated, service_role;

comment on function public.xueqing_backend_compatibility() is
  'Data-free schema/capability contract used by stable release compatibility gates.';
