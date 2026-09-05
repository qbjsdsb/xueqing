-- Phase 0B.0-Y: make an archived organization a complete Data API read stop.
-- The user's own application identity remains readable so the client can show
-- an account state, but organization-linked metadata and teaching data fail
-- closed through both the legacy spike helpers and the canonical helpers.

create or replace function private.can_read_organization(
  target_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.memberships as membership
    join public.organizations as organization
      on organization.id = membership.organization_id
     and organization.status = 'active'
    where membership.organization_id = target_organization_id
      and membership.user_id = (select private.current_app_user_id())
      and membership.status = 'active'
  )
$function$;

create or replace function private.can_read_student(
  target_student_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.students as student
    join public.organizations as organization
      on organization.id = student.organization_id
     and organization.status = 'active'
    join public.teacher_assignments as assignment
      on assignment.student_id = student.id
     and assignment.status = 'active'
    join public.memberships as membership
      on membership.organization_id = student.organization_id
     and membership.user_id = assignment.teacher_id
     and membership.role = 'teacher'
     and membership.status = 'active'
    where student.id = target_student_id
      and student.status = 'active'
      and assignment.teacher_id = (select private.current_app_user_id())
  )
$function$;

create or replace function private.can_read_assignment(
  target_assignment_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.teacher_assignments as assignment
    join public.students as student
      on student.id = assignment.student_id
    join public.organizations as organization
      on organization.id = student.organization_id
     and organization.status = 'active'
    join public.memberships as membership
      on membership.organization_id = student.organization_id
     and membership.user_id = assignment.teacher_id
     and membership.role = 'teacher'
     and membership.status = 'active'
    where assignment.id = target_assignment_id
      and assignment.teacher_id = (select private.current_app_user_id())
      and assignment.status = 'active'
      and student.status = 'active'
  )
$function$;

create or replace function private.can_read_organization_v2(
  target_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.organization_memberships as membership
    join public.organizations as organization
      on organization.id = membership.organization_id
     and organization.status = 'active'
    where membership.organization_id = target_organization_id
      and membership.app_user_id =
        (select private.current_app_user_id_v2())
      and membership.status = 'active'
  )
$function$;

create or replace function private.can_read_membership_v2(
  target_membership_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.organization_memberships as membership
    join public.organizations as organization
      on organization.id = membership.organization_id
     and organization.status = 'active'
    where membership.id = target_membership_id
      and membership.app_user_id =
        (select private.current_app_user_id_v2())
      and membership.status <> 'disabled'
  )
$function$;

drop policy if exists "users can read their active memberships"
  on public.memberships;

create policy "users can read their active memberships"
on public.memberships
for select
to authenticated
using (
  user_id = (select private.current_app_user_id())
  and status = 'active'
  and (select private.can_read_organization(memberships.organization_id))
);

revoke all on function private.can_read_organization(uuid)
  from public, anon;
revoke all on function private.can_read_student(uuid)
  from public, anon;
revoke all on function private.can_read_assignment(uuid)
  from public, anon;
revoke all on function private.can_read_organization_v2(uuid)
  from public, anon;
revoke all on function private.can_read_membership_v2(uuid)
  from public, anon;

grant execute on function private.can_read_organization(uuid)
  to authenticated;
grant execute on function private.can_read_student(uuid)
  to authenticated;
grant execute on function private.can_read_assignment(uuid)
  to authenticated;
grant execute on function private.can_read_organization_v2(uuid)
  to authenticated;
grant execute on function private.can_read_membership_v2(uuid)
  to authenticated;
