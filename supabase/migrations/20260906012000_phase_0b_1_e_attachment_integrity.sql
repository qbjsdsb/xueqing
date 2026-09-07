-- Keep the denormalized Case id on attachment metadata structurally tied to
-- the parent Evidence row. The RPC already checks this relationship; the
-- composite foreign key also protects future server-side maintenance jobs.

create unique index if not exists case_evidence_id_case_organization_key
  on public.case_evidence (id, learning_case_id, organization_id);

alter table public.case_evidence_attachments
  drop constraint if exists case_evidence_attachments_evidence_fk;

alter table public.case_evidence_attachments
  add constraint case_evidence_attachments_evidence_fk
  foreign key (case_evidence_id, learning_case_id, organization_id)
  references public.case_evidence(id, learning_case_id, organization_id)
  on delete restrict;

alter table public.case_evidence_attachments
  add constraint case_evidence_attachments_path_length_check
  check (char_length(storage_path) <= 512);
