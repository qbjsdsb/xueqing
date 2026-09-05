-- Phase 0B.0-P: keep inactive or archived students outside the
-- teacher-readable profile graph, and expose one server-owned business date
-- for clients that must render date-only work consistently.
-- This is a fictional/local compatibility migration. It is not a
-- production migration or permission to import real student data.

create or replace function private.can_read_profile_v2(
  target_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.student_subject_profiles as profile
    join public.students as student
      on student.id = profile.student_id
     and student.organization_id = profile.organization_id
     and student.status = 'active'
    join public.organizations as organization
      on organization.id = profile.organization_id
     and organization.status = 'active'
    join public.student_teacher_assignments as assignment
      on assignment.student_subject_profile_id = profile.id
     and assignment.organization_id = profile.organization_id
     and assignment.status = 'active'
     and (now() at time zone organization.time_zone)::date >=
       assignment.active_from
     and (
       assignment.active_to is null
       or (now() at time zone organization.time_zone)::date <= assignment.active_to
     )
    join public.organization_memberships as membership
      on membership.id = assignment.membership_id
     and membership.organization_id = assignment.organization_id
     and membership.status = 'active'
     and membership.app_user_id =
       (select private.current_app_user_id_v2())
    join public.membership_roles as membership_role
      on membership_role.membership_id = membership.id
     and membership_role.organization_id = membership.organization_id
     and membership_role.role = 'teacher'
    join public.membership_subject_scopes as scope
      on scope.membership_id = membership.id
     and scope.organization_id = membership.organization_id
     and scope.organization_subject_id = profile.organization_subject_id
     and scope.scope_kind = 'teaching'
     and scope.status = 'active'
     and (now() at time zone organization.time_zone)::date >=
       scope.active_from
     and (
       scope.active_to is null
       or (now() at time zone organization.time_zone)::date <= scope.active_to
     )
    where profile.id = target_profile_id
      and profile.status = 'active'
  )
$function$;

create or replace view public.teacher_workspace_context
with (security_invoker = true)
as
select
  organization.id,
  organization.name,
  organization.time_zone,
  (now() at time zone organization.time_zone)::date as business_date
from public.organizations as organization
where organization.status = 'active';

comment on view public.teacher_workspace_context is
  'RLS-aware read model for the organization business date used by the client.';

revoke all on table public.teacher_workspace_context from anon, authenticated;
grant select on table public.teacher_workspace_context to authenticated;
