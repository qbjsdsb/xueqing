-- Workload indexes for the teacher workspace read model.
--
-- loadWorkspace() scopes each collection by organization_id and then joins
-- the returned rows by learning_case_id in the client. These indexes keep the
-- organization boundary selective as a small institution grows; they do not
-- change RLS or authorization semantics.

create index if not exists case_actions_workspace_org_idx
  on public.case_actions (
    organization_id,
    learning_case_id,
    status,
    due_at
  );

create index if not exists case_actions_workspace_pending_primary_idx
  on public.case_actions (
    organization_id,
    due_at,
    learning_case_id
  )
  where status = 'pending' and is_primary = true;

create index if not exists case_events_workspace_org_idx
  on public.case_events (
    organization_id,
    learning_case_id,
    occurred_at
  );

create index if not exists case_evidence_workspace_org_idx
  on public.case_evidence (
    organization_id,
    learning_case_id,
    observed_at desc
  );

create index if not exists interventions_workspace_org_idx
  on public.interventions (
    organization_id,
    learning_case_id,
    occurred_at desc
  );

create index if not exists assessments_workspace_org_idx
  on public.assessments (
    organization_id,
    learning_case_id,
    assessed_at desc
  );

create index if not exists student_enrollments_workspace_org_idx
  on public.student_enrollments (
    organization_id,
    student_id,
    starts_on desc,
    ends_on
  );
