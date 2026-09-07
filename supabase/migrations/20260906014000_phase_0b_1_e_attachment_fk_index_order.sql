-- The Evidence foreign key is three columns after the integrity correction;
-- keep that exact order at the front of the detail index.

drop index if exists public.case_evidence_attachments_evidence_created_idx;

create index case_evidence_attachments_evidence_created_idx
  on public.case_evidence_attachments (
    case_evidence_id,
    learning_case_id,
    organization_id,
    created_at,
    id
  );
