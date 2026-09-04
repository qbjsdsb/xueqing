-- Phase 0B.0-L: evaluate enrollment validity in the organization's
-- business timezone before the Flutter client assembles the workspace.
-- This is a fictional/local compatibility migration. It is not a
-- production migration or permission to import real student data.

create or replace view public.teacher_workspace_student_enrollments
with (security_invoker = true)
as
select
  enrollment.id,
  enrollment.organization_id,
  enrollment.student_id,
  enrollment.grade,
  enrollment.class_name,
  enrollment.campus,
  enrollment.starts_on,
  enrollment.ends_on,
  (now() at time zone organization.time_zone)::date as business_date,
  (
    enrollment.starts_on <=
      (now() at time zone organization.time_zone)::date
    and (
      enrollment.ends_on is null
      or enrollment.ends_on >=
        (now() at time zone organization.time_zone)::date
    )
  ) as is_current
from public.student_enrollments as enrollment
join public.organizations as organization
  on organization.id = enrollment.organization_id;

comment on view public.teacher_workspace_student_enrollments is
  'RLS-aware read model for enrollment validity in organization business time.';

revoke all on table public.teacher_workspace_student_enrollments
  from anon, authenticated;
grant select on table public.teacher_workspace_student_enrollments
  to authenticated;
