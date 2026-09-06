-- Phase 0B.1-E: move the attachment registration RPC behind the
-- same private implementation / public invoker boundary as the other
-- privileged commands.
--
-- This is a follow-up migration, rather than an edit to the already-applied
-- attachment migration, so remote development projects receive the fix too.

alter function public.create_case_evidence_attachment(
  uuid, uuid, uuid, uuid, text, text, text, bigint
) set schema private;

revoke all on function private.create_case_evidence_attachment(
  uuid, uuid, uuid, uuid, text, text, text, bigint
) from public, anon, authenticated, service_role;
grant execute on function private.create_case_evidence_attachment(
  uuid, uuid, uuid, uuid, text, text, text, bigint
) to authenticated, service_role;

create or replace function public.create_case_evidence_attachment(
  p_organization_id uuid,
  p_learning_case_id uuid,
  p_case_evidence_id uuid,
  p_attachment_id uuid,
  p_storage_path text,
  p_original_file_name text,
  p_content_type text,
  p_size_bytes bigint
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.create_case_evidence_attachment(
    p_organization_id,
    p_learning_case_id,
    p_case_evidence_id,
    p_attachment_id,
    p_storage_path,
    p_original_file_name,
    p_content_type,
    p_size_bytes
  )
$function$;

revoke all on function public.create_case_evidence_attachment(
  uuid, uuid, uuid, uuid, text, text, text, bigint
) from public, anon, authenticated, service_role;
grant execute on function public.create_case_evidence_attachment(
  uuid, uuid, uuid, uuid, text, text, text, bigint
) to authenticated, service_role;
