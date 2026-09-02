-- Phase 0B.0-A: minimal provider compatibility/security spike.
-- This migration is deliberately limited to identity, organization, and student access.

create extension if not exists pgcrypto;

create schema if not exists private;
revoke all on schema private from public;

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) > 0),
  created_at timestamptz not null default timezone('utc', now())
);

create table public.app_users (
  id uuid primary key default gen_random_uuid(),
  auth_provider text not null check (char_length(btrim(auth_provider)) > 0),
  auth_subject_id text not null check (char_length(btrim(auth_subject_id)) > 0),
  display_name text not null check (char_length(btrim(display_name)) > 0),
  status text not null default 'active' check (status in ('active', 'disabled')),
  created_at timestamptz not null default timezone('utc', now()),
  constraint app_users_provider_subject_key unique (auth_provider, auth_subject_id)
);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  user_id uuid not null references public.app_users(id) on delete restrict,
  role text not null check (role in ('teacher', 'org_admin')),
  status text not null default 'active' check (status in ('active', 'disabled')),
  created_at timestamptz not null default timezone('utc', now()),
  constraint memberships_organization_user_key unique (organization_id, user_id)
);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  name text not null check (char_length(btrim(name)) > 0),
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default timezone('utc', now())
);

create table public.teacher_assignments (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.app_users(id) on delete restrict,
  student_id uuid not null references public.students(id) on delete restrict,
  subject text not null check (char_length(btrim(subject)) > 0),
  status text not null default 'active' check (status in ('active', 'ended')),
  created_at timestamptz not null default timezone('utc', now()),
  constraint teacher_assignments_teacher_student_subject_key
    unique (teacher_id, student_id, subject)
);

create index memberships_user_status_idx
  on public.memberships (user_id, status);

create index students_organization_status_idx
  on public.students (organization_id, status);

create index teacher_assignments_teacher_status_idx
  on public.teacher_assignments (teacher_id, status);

create index teacher_assignments_student_status_idx
  on public.teacher_assignments (student_id, status);

comment on schema private is
  'Non-API authorization helpers for the Phase 0B.0-A compatibility spike.';

comment on table public.organizations is
  'Fictional/dev foundation table; not a complete product organization model.';
comment on table public.app_users is
  'Provider-neutral application identity mapped to an external auth subject.';
comment on table public.memberships is
  'Organization membership and role boundary for the compatibility spike.';
comment on table public.students is
  'Student subject root for the compatibility spike.';
comment on table public.teacher_assignments is
  'Explicit teacher-to-student access relation for the compatibility spike.';

-- A revoked Auth session must stop producing a business identity. The helper
-- is kept outside the exposed API schema and validates the JWT session_id
-- against auth.sessions before RLS evaluates any business table.
create or replace function private.current_app_user_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $function$
  select au.id
  from public.app_users as au
  where au.auth_provider = 'supabase'
    and au.auth_subject_id = (select auth.uid())::text
    and au.status = 'active'
    and exists (
      select 1
      from auth.sessions as auth_session
      where auth_session.id =
        nullif((select auth.jwt() ->> 'session_id'), '')::uuid
        and auth_session.user_id = (select auth.uid())
    )
  limit 1
$function$;

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

revoke all on function private.current_app_user_id() from public;
revoke all on function private.can_read_organization(uuid) from public;
revoke all on function private.can_read_student(uuid) from public;
revoke all on function private.can_read_assignment(uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.current_app_user_id() to authenticated;
grant execute on function private.can_read_organization(uuid) to authenticated;
grant execute on function private.can_read_student(uuid) to authenticated;
grant execute on function private.can_read_assignment(uuid) to authenticated;

alter table public.organizations enable row level security;
alter table public.app_users enable row level security;
alter table public.memberships enable row level security;
alter table public.students enable row level security;
alter table public.teacher_assignments enable row level security;

revoke all on table public.organizations from anon;
revoke all on table public.app_users from anon;
revoke all on table public.memberships from anon;
revoke all on table public.students from anon;
revoke all on table public.teacher_assignments from anon;

grant select on table public.organizations to authenticated;
grant select on table public.app_users to authenticated;
grant select on table public.memberships to authenticated;
grant select on table public.students to authenticated;
grant select on table public.teacher_assignments to authenticated;

create policy "active members can read their organizations"
on public.organizations
for select
to authenticated
using ((select private.can_read_organization(organizations.id)));

create policy "users can read their own application identity"
on public.app_users
for select
to authenticated
using (id = (select private.current_app_user_id()));

create policy "users can read their active memberships"
on public.memberships
for select
to authenticated
using (
  user_id = (select private.current_app_user_id())
  and status = 'active'
);

create policy "teachers can read assigned students in their active organization"
on public.students
for select
to authenticated
using (
  status = 'active'
  and (select private.can_read_student(students.id))
);

create policy "teachers can read their active assignments"
on public.teacher_assignments
for select
to authenticated
using ((select private.can_read_assignment(teacher_assignments.id)));
