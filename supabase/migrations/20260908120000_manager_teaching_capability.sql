-- Small-institution role model: organization leadership and teaching are not
-- mutually exclusive. Owners/admins may also teach, but concrete teaching
-- responsibility still requires an active teaching subject scope and assignment.

create or replace function private.ensure_manager_teacher_role_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.role in ('org_owner', 'org_admin') then
    insert into public.membership_roles (
      organization_id,
      membership_id,
      role
    )
    values (
      new.organization_id,
      new.membership_id,
      'teacher'
    )
    on conflict (membership_id, role) do nothing;
  end if;

  return new;
end
$function$;

revoke all on function private.ensure_manager_teacher_role_v2()
  from public, anon, authenticated, service_role;

drop trigger if exists membership_roles_manager_teaching_capability
  on public.membership_roles;

create trigger membership_roles_manager_teaching_capability
after insert on public.membership_roles
for each row
execute function private.ensure_manager_teacher_role_v2();

-- Existing managers should receive the same capability immediately. This does
-- not create a teaching subject scope or student assignment; it only makes the
-- membership eligible to receive those explicit teaching relationships.
insert into public.membership_roles (
  organization_id,
  membership_id,
  role
)
select distinct
  manager_role.organization_id,
  manager_role.membership_id,
  'teacher'
from public.membership_roles as manager_role
where manager_role.role in ('org_owner', 'org_admin')
on conflict (membership_id, role) do nothing;

comment on function private.ensure_manager_teacher_role_v2() is
  'Keeps owner/admin memberships teaching-capable without making teaching scopes or assignments implicit.';
