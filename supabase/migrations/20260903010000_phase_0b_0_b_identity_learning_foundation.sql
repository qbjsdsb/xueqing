-- Phase 0B.0-B: provider-neutral identity and learning foundation.
-- This is a fictional/local compatibility migration. It is not a production
-- deployment or a permission to import real student data.

create schema if not exists private;
revoke all on schema private from public;

alter table public.organizations
  add column if not exists time_zone text not null default 'Asia/Shanghai',
  add column if not exists status text not null default 'active';

alter table public.organizations
  add constraint organizations_time_zone_not_blank
    check (char_length(btrim(time_zone)) > 0),
  add constraint organizations_status_check
    check (status in ('active', 'archived'));

alter table public.students
  add column if not exists student_code text,
  add column if not exists version integer not null default 1,
  add column if not exists merged_into_student_id uuid,
  add column if not exists updated_at timestamptz not null default timezone('utc', now()),
  add column if not exists archived_at timestamptz;

alter table public.students
  drop constraint if exists students_status_check;

alter table public.students
  add constraint students_status_check
    check (status in ('active', 'inactive', 'archived', 'merged')),
  add constraint students_version_positive
    check (version > 0),
  add constraint students_merged_status_consistency
    check (
      (status = 'merged' and merged_into_student_id is not null)
      or (status <> 'merged' and merged_into_student_id is null)
    ),
  add constraint students_merged_into_fk
    foreign key (merged_into_student_id)
    references public.students(id)
    on delete restrict;

alter table public.students
  add constraint students_id_organization_key
    unique (id, organization_id);

create table public.identity_links (
  id uuid primary key default gen_random_uuid(),
  app_user_id uuid not null references public.app_users(id) on delete restrict,
  provider_key text not null check (char_length(btrim(provider_key)) > 0),
  issuer text not null check (char_length(btrim(issuer)) > 0),
  external_subject text not null
    check (char_length(btrim(external_subject)) > 0),
  status text not null default 'active'
    check (status in ('active', 'retired')),
  created_at timestamptz not null default timezone('utc', now()),
  retired_at timestamptz,
  constraint identity_links_retired_at_check
    check (
      (status = 'active' and retired_at is null)
      or (status = 'retired' and retired_at is not null)
    ),
  constraint identity_links_provider_subject_key
    unique (provider_key, issuer, external_subject)
);

create unique index identity_links_one_active_per_user_idx
  on public.identity_links (app_user_id)
  where status = 'active';

create index identity_links_app_user_status_idx
  on public.identity_links (app_user_id, status);

create table public.organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  app_user_id uuid not null
    references public.app_users(id) on delete restrict,
  status text not null default 'onboarding'
    check (status in ('onboarding', 'active', 'disabled')),
  onboarding_expires_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint organization_memberships_id_organization_key
    unique (id, organization_id)
);

create unique index organization_memberships_one_non_disabled_per_user_idx
  on public.organization_memberships (app_user_id)
  where status in ('onboarding', 'active');

create index organization_memberships_org_status_idx
  on public.organization_memberships (organization_id, status);

create index organization_memberships_user_status_idx
  on public.organization_memberships (app_user_id, status);

create table public.membership_roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  membership_id uuid not null,
  role text not null
    check (role in (
      'org_admin',
      'academic_admin',
      'subject_lead',
      'teacher',
      'student_advisor'
    )),
  created_at timestamptz not null default timezone('utc', now()),
  constraint membership_roles_membership_fk
    foreign key (membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict,
  constraint membership_roles_unique_key
    unique (membership_id, role)
);

create index membership_roles_membership_idx
  on public.membership_roles (membership_id, role);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  code text not null
    check (char_length(btrim(code)) > 0),
  name text not null
    check (char_length(btrim(name)) > 0),
  status text not null default 'active'
    check (status in ('active', 'retired')),
  created_at timestamptz not null default timezone('utc', now()),
  constraint subjects_code_key unique (code)
);

create table public.organization_subjects (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  subject_id uuid not null
    references public.subjects(id) on delete restrict,
  display_name text not null
    check (char_length(btrim(display_name)) > 0),
  status text not null default 'active'
    check (status in ('active', 'archived')),
  created_at timestamptz not null default timezone('utc', now()),
  constraint organization_subjects_id_organization_key
    unique (id, organization_id),
  constraint organization_subjects_unique_key
    unique (organization_id, subject_id)
);

create index organization_subjects_org_status_idx
  on public.organization_subjects (organization_id, status);

create table public.membership_subject_scopes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  membership_id uuid not null,
  organization_subject_id uuid not null,
  scope_kind text not null
    check (scope_kind in ('teaching', 'leadership')),
  status text not null default 'active'
    check (status in ('active', 'ended')),
  active_from date not null,
  active_to date,
  created_at timestamptz not null default timezone('utc', now()),
  constraint membership_subject_scopes_membership_fk
    foreign key (membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict,
  constraint membership_subject_scopes_subject_fk
    foreign key (organization_subject_id, organization_id)
    references public.organization_subjects(id, organization_id)
    on delete restrict,
  constraint membership_subject_scopes_date_check
    check (active_to is null or active_to >= active_from)
);

create unique index membership_subject_scopes_one_active_idx
  on public.membership_subject_scopes (
    membership_id,
    organization_subject_id,
    scope_kind
  )
  where status = 'active';

create index membership_subject_scopes_membership_status_idx
  on public.membership_subject_scopes (membership_id, status);

create table public.student_enrollments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  student_id uuid not null,
  grade text,
  class_name text,
  campus text,
  starts_on date not null,
  ends_on date,
  created_at timestamptz not null default timezone('utc', now()),
  constraint student_enrollments_student_fk
    foreign key (student_id, organization_id)
    references public.students(id, organization_id)
    on delete restrict,
  constraint student_enrollments_date_check
    check (ends_on is null or ends_on >= starts_on)
);

create index student_enrollments_student_dates_idx
  on public.student_enrollments (student_id, starts_on, ends_on);

create table public.student_subject_profiles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  student_id uuid not null,
  organization_subject_id uuid not null,
  status text not null default 'active'
    check (status in ('active', 'inactive', 'archived')),
  positioning text,
  strengths text,
  cadence_note text,
  version integer not null default 1
    check (version > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint student_subject_profiles_student_fk
    foreign key (student_id, organization_id)
    references public.students(id, organization_id)
    on delete restrict,
  constraint student_subject_profiles_subject_fk
    foreign key (organization_subject_id, organization_id)
    references public.organization_subjects(id, organization_id)
    on delete restrict,
  constraint student_subject_profiles_id_organization_key
    unique (id, organization_id),
  constraint student_subject_profiles_unique_key
    unique (organization_id, student_id, organization_subject_id)
);

create index student_subject_profiles_student_status_idx
  on public.student_subject_profiles (student_id, status);

create index student_subject_profiles_subject_status_idx
  on public.student_subject_profiles (organization_subject_id, status);

create table public.student_teacher_assignments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  student_subject_profile_id uuid not null,
  membership_id uuid not null,
  assignment_role text not null
    check (assignment_role in ('lead', 'collaborator')),
  status text not null default 'active'
    check (status in ('active', 'ended')),
  active_from date not null,
  active_to date,
  created_at timestamptz not null default timezone('utc', now()),
  ended_at timestamptz,
  constraint student_teacher_assignments_profile_fk
    foreign key (student_subject_profile_id, organization_id)
    references public.student_subject_profiles(id, organization_id)
    on delete restrict,
  constraint student_teacher_assignments_membership_fk
    foreign key (membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict,
  constraint student_teacher_assignments_date_check
    check (active_to is null or active_to >= active_from)
);

create unique index student_teacher_assignments_one_active_lead_idx
  on public.student_teacher_assignments (student_subject_profile_id)
  where status = 'active' and assignment_role = 'lead';

create unique index student_teacher_assignments_one_active_membership_idx
  on public.student_teacher_assignments (
    student_subject_profile_id,
    membership_id,
    assignment_role
  )
  where status = 'active';

create index student_teacher_assignments_membership_status_idx
  on public.student_teacher_assignments (membership_id, status);

create index student_teacher_assignments_profile_status_idx
  on public.student_teacher_assignments (student_subject_profile_id, status);

comment on table public.identity_links is
  'Provider-neutral identity mapping. external_subject is opaque text.';
comment on table public.organization_memberships is
  'Canonical organization membership for the post-Gate-A foundation.';
comment on table public.student_subject_profiles is
  'One current subject service profile per organization/student/subject.';
comment on table public.student_teacher_assignments is
  'Explicit legal teaching assignment; lesson participation cannot replace it.';

create or replace function private.current_app_user_id_v2()
returns uuid
language sql
stable
security definer
set search_path = ''
as $function$
  select link.app_user_id
  from public.identity_links as link
  join public.app_users as app_user
    on app_user.id = link.app_user_id
  where link.provider_key = 'supabase'
    and link.issuer =
      coalesce(nullif((select auth.jwt() ->> 'iss'), ''), 'supabase')
    and link.external_subject = (select auth.uid())::text
    and link.status = 'active'
    and app_user.status = 'active'
    and exists (
      select 1
      from auth.sessions as auth_session
      where auth_session.id =
        nullif((select auth.jwt() ->> 'session_id'), '')::uuid
        and auth_session.user_id = (select auth.uid())
    )
  limit 1
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
    where membership.id = target_membership_id
      and membership.app_user_id =
        (select private.current_app_user_id_v2())
      and membership.status <> 'disabled'
  )
$function$;

create or replace function private.can_read_subject_v2(
  target_organization_subject_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.organization_subjects as organization_subject
    where organization_subject.id = target_organization_subject_id
      and organization_subject.status = 'active'
      and (select private.can_read_organization_v2(
        organization_subject.organization_id
      ))
  )
$function$;

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

create or replace function private.can_read_student_v2(
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
    from public.student_subject_profiles as profile
    where profile.student_id = target_student_id
      and (select private.can_read_profile_v2(profile.id))
  )
$function$;

create or replace function private.can_read_assignment_v2(
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
    from public.student_teacher_assignments as assignment
    where assignment.id = target_assignment_id
      and (select private.can_read_profile_v2(
        assignment.student_subject_profile_id
      ))
  )
$function$;

revoke all on function private.current_app_user_id_v2() from public;
revoke all on function private.can_read_organization_v2(uuid) from public;
revoke all on function private.can_read_membership_v2(uuid) from public;
revoke all on function private.can_read_subject_v2(uuid) from public;
revoke all on function private.can_read_profile_v2(uuid) from public;
revoke all on function private.can_read_student_v2(uuid) from public;
revoke all on function private.can_read_assignment_v2(uuid) from public;

grant usage on schema private to authenticated;
grant execute on function private.current_app_user_id_v2() to authenticated;
grant execute on function private.can_read_organization_v2(uuid) to authenticated;
grant execute on function private.can_read_membership_v2(uuid) to authenticated;
grant execute on function private.can_read_subject_v2(uuid) to authenticated;
grant execute on function private.can_read_profile_v2(uuid) to authenticated;
grant execute on function private.can_read_student_v2(uuid) to authenticated;
grant execute on function private.can_read_assignment_v2(uuid) to authenticated;

alter table public.identity_links enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.membership_roles enable row level security;
alter table public.subjects enable row level security;
alter table public.organization_subjects enable row level security;
alter table public.membership_subject_scopes enable row level security;
alter table public.student_enrollments enable row level security;
alter table public.student_subject_profiles enable row level security;
alter table public.student_teacher_assignments enable row level security;

revoke all on table public.identity_links from anon, authenticated;
revoke all on table public.organization_memberships from anon, authenticated;
revoke all on table public.membership_roles from anon, authenticated;
revoke all on table public.subjects from anon, authenticated;
revoke all on table public.organization_subjects from anon, authenticated;
revoke all on table public.membership_subject_scopes from anon, authenticated;
revoke all on table public.student_enrollments from anon, authenticated;
revoke all on table public.student_subject_profiles from anon, authenticated;
revoke all on table public.student_teacher_assignments from anon, authenticated;

grant select on table public.organization_memberships to authenticated;
grant select on table public.membership_roles to authenticated;
grant select on table public.subjects to authenticated;
grant select on table public.organization_subjects to authenticated;
grant select on table public.membership_subject_scopes to authenticated;
grant select on table public.student_enrollments to authenticated;
grant select on table public.student_subject_profiles to authenticated;
grant select on table public.student_teacher_assignments to authenticated;

drop policy if exists "active members can read their organizations"
  on public.organizations;
drop policy if exists
  "teachers can read assigned students in their active organization"
  on public.students;

create policy "active canonical members can read their organizations"
on public.organizations
for select
to authenticated
using (
  status = 'active'
  and (select private.can_read_organization_v2(organizations.id))
);

create policy "users can read their canonical memberships"
on public.organization_memberships
for select
to authenticated
using (
  (select private.can_read_membership_v2(organization_memberships.id))
);

create policy "users can read their canonical roles"
on public.membership_roles
for select
to authenticated
using (
  (select private.can_read_membership_v2(membership_roles.membership_id))
);

create policy "active members can read organization subjects"
on public.organization_subjects
for select
to authenticated
using (
  status = 'active'
  and (select private.can_read_organization_v2(
    organization_subjects.organization_id
  ))
);

create policy "active members can read subjects"
on public.subjects
for select
to authenticated
using (
  status = 'active'
  and exists (
    select 1
    from public.organization_subjects as organization_subject
    where organization_subject.subject_id = subjects.id
      and organization_subject.status = 'active'
      and (select private.can_read_organization_v2(
        organization_subject.organization_id
      ))
  )
);

create policy "users can read their subject scopes"
on public.membership_subject_scopes
for select
to authenticated
using (
  (select private.can_read_membership_v2(
    membership_subject_scopes.membership_id
  ))
);

create policy "teachers can read assigned students"
on public.students
for select
to authenticated
using (
  status = 'active'
  and (select private.can_read_student_v2(students.id))
);

create policy "teachers can read assigned enrollments"
on public.student_enrollments
for select
to authenticated
using (
  (select private.can_read_student_v2(student_enrollments.student_id))
);

create policy "teachers can read assigned subject profiles"
on public.student_subject_profiles
for select
to authenticated
using (
  status = 'active'
  and (select private.can_read_profile_v2(student_subject_profiles.id))
);

create policy "teachers can read their assignments"
on public.student_teacher_assignments
for select
to authenticated
using (
  (select private.can_read_assignment_v2(
    student_teacher_assignments.id
  ))
);
