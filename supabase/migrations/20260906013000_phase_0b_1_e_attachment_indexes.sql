-- Cover the attachment table's foreign keys explicitly. The read path still
-- keeps its Evidence ordering columns after the FK columns so the same index
-- serves both integrity checks and Case detail rendering.

drop index if exists public.case_evidence_attachments_evidence_created_idx;

create index case_evidence_attachments_evidence_created_idx
  on public.case_evidence_attachments (
    case_evidence_id,
    organization_id,
    created_at,
    id
  );

create index case_evidence_attachments_case_idx
  on public.case_evidence_attachments (learning_case_id, organization_id);

create index case_evidence_attachments_organization_idx
  on public.case_evidence_attachments (organization_id);

create index case_evidence_attachments_creator_app_user_idx
  on public.case_evidence_attachments (created_by_app_user_id);

create index case_evidence_attachments_creator_membership_idx
  on public.case_evidence_attachments (
    created_by_membership_id,
    organization_id
  );
