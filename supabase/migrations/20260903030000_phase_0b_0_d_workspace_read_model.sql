-- Phase 0B.0-D: a read-only action queue for the Teacher Workspace.
-- This remains a fictional/local compatibility migration. It is not a
-- production migration or permission to import real student data.

create view public.teacher_workspace_action_queue
with (security_invoker = true)
as
select
  action.id,
  action.organization_id,
  action.learning_case_id,
  learning_case.student_subject_profile_id,
  action.assigned_membership_id,
  action.action_type,
  action.title,
  action.due_at,
  action.is_primary,
  action.status,
  learning_case.status as case_status,
  (action.due_at at time zone organization.time_zone)::date
    as business_due_date,
  case
    when action.due_at is null then 'undated'
    when (action.due_at at time zone organization.time_zone)::date <
      (now() at time zone organization.time_zone)::date then 'overdue'
    when (action.due_at at time zone organization.time_zone)::date =
      (now() at time zone organization.time_zone)::date then 'today'
    else 'future'
  end as due_bucket
from public.case_actions as action
join public.learning_cases as learning_case
  on learning_case.id = action.learning_case_id
 and learning_case.organization_id = action.organization_id
join public.organizations as organization
  on organization.id = action.organization_id
where action.status = 'pending'
  and action.is_primary;

comment on view public.teacher_workspace_action_queue is
  'RLS-aware read model for current primary Case Actions and business-date buckets.';

revoke all on table public.teacher_workspace_action_queue from anon, authenticated;
grant select on table public.teacher_workspace_action_queue to authenticated;
