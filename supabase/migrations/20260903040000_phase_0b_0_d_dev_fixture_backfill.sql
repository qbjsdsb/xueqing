-- Phase 0B.0-D: backfill the existing fictional compatibility fixture into
-- the canonical learning model used by the Teacher Workspace.
--
-- This migration is for the xueqing-dev project only. It intentionally keeps
-- the legacy compatibility tables in place and never imports real student
-- data. Every insert is idempotent so a retry cannot duplicate the fixture.

do $backfill$
declare
  -- Supabase hosted JWTs use the project Auth URL as the issuer. This value is
  -- intentionally fixed here because this is a development-project fixture,
  -- not a portable production data migration.
  v_issuer text :=
    'https://czuctoulgnfytcfonkhc.supabase.co/auth/v1';
begin
  insert into public.identity_links (
    app_user_id,
    provider_key,
    issuer,
    external_subject,
    status
  )
  select
    app_user.id,
    'supabase',
    v_issuer,
    app_user.auth_subject_id,
    'active'
  from public.app_users as app_user
  where app_user.auth_provider = 'supabase'
    and app_user.status = 'active'
    and not exists (
      select 1
      from public.identity_links as existing_link
      where existing_link.app_user_id = app_user.id
        and existing_link.status = 'active'
    )
  on conflict (provider_key, issuer, external_subject) do nothing;

  insert into public.organization_memberships (
    id,
    organization_id,
    app_user_id,
    status
  )
  select
    legacy_membership.id,
    legacy_membership.organization_id,
    legacy_membership.user_id,
    case
      when legacy_membership.status = 'active' then 'active'
      else 'disabled'
    end
  from public.memberships as legacy_membership
  on conflict (id) do nothing;

  insert into public.membership_roles (
    organization_id,
    membership_id,
    role
  )
  select
    legacy_membership.organization_id,
    legacy_membership.id,
    legacy_membership.role
  from public.memberships as legacy_membership
  where legacy_membership.role in (
    'org_admin',
    'academic_admin',
    'subject_lead',
    'teacher',
    'student_advisor'
  )
  on conflict (membership_id, role) do nothing;

  insert into public.subjects (code, name, status)
  select distinct
    case trim(legacy_assignment.subject)
      when '数学' then 'math'
      when '英语' then 'english'
      else 'legacy_' || md5(trim(legacy_assignment.subject))
    end,
    trim(legacy_assignment.subject),
    'active'
  from public.teacher_assignments as legacy_assignment
  where char_length(btrim(legacy_assignment.subject)) > 0
  on conflict (code) do update
    set name = excluded.name,
        status = 'active';

  insert into public.organization_subjects (
    organization_id,
    subject_id,
    display_name,
    status
  )
  select distinct
    student.organization_id,
    subject.id,
    trim(legacy_assignment.subject),
    'active'
  from public.teacher_assignments as legacy_assignment
  join public.students as student
    on student.id = legacy_assignment.student_id
  join public.subjects as subject
    on subject.code = case trim(legacy_assignment.subject)
      when '数学' then 'math'
      when '英语' then 'english'
      else 'legacy_' || md5(trim(legacy_assignment.subject))
    end
  where char_length(btrim(legacy_assignment.subject)) > 0
  on conflict (organization_id, subject_id) do update
    set display_name = excluded.display_name,
        status = 'active';

  insert into public.membership_subject_scopes (
    organization_id,
    membership_id,
    organization_subject_id,
    scope_kind,
    status,
    active_from
  )
  select distinct
    legacy_membership.organization_id,
    canonical_membership.id,
    organization_subject.id,
    'teaching',
    'active',
    date '2026-01-01'
  from public.teacher_assignments as legacy_assignment
  join public.students as student
    on student.id = legacy_assignment.student_id
  join public.memberships as legacy_membership
    on legacy_membership.user_id = legacy_assignment.teacher_id
   and legacy_membership.organization_id = student.organization_id
   and legacy_membership.status = 'active'
  join public.organization_memberships as canonical_membership
    on canonical_membership.id = legacy_membership.id
   and canonical_membership.status = 'active'
  join public.subjects as subject
    on subject.code = case trim(legacy_assignment.subject)
      when '数学' then 'math'
      when '英语' then 'english'
      else 'legacy_' || md5(trim(legacy_assignment.subject))
    end
  join public.organization_subjects as organization_subject
    on organization_subject.organization_id = student.organization_id
   and organization_subject.subject_id = subject.id
   and organization_subject.status = 'active'
  where legacy_assignment.status = 'active'
    and not exists (
      select 1
      from public.membership_subject_scopes as existing_scope
      where existing_scope.membership_id = canonical_membership.id
        and existing_scope.organization_subject_id = organization_subject.id
        and existing_scope.scope_kind = 'teaching'
        and existing_scope.status = 'active'
    );

  insert into public.student_enrollments (
    organization_id,
    student_id,
    starts_on
  )
  select
    student.organization_id,
    student.id,
    date '2026-01-01'
  from public.students as student
  where not exists (
    select 1
    from public.student_enrollments as existing_enrollment
    where existing_enrollment.organization_id = student.organization_id
      and existing_enrollment.student_id = student.id
      and existing_enrollment.starts_on = date '2026-01-01'
  );

  insert into public.student_subject_profiles (
    organization_id,
    student_id,
    organization_subject_id,
    status
  )
  select distinct
    student.organization_id,
    student.id,
    organization_subject.id,
    'active'
  from public.teacher_assignments as legacy_assignment
  join public.students as student
    on student.id = legacy_assignment.student_id
  join public.subjects as subject
    on subject.code = case trim(legacy_assignment.subject)
      when '数学' then 'math'
      when '英语' then 'english'
      else 'legacy_' || md5(trim(legacy_assignment.subject))
    end
  join public.organization_subjects as organization_subject
    on organization_subject.organization_id = student.organization_id
   and organization_subject.subject_id = subject.id
   and organization_subject.status = 'active'
  where legacy_assignment.status = 'active'
  on conflict (
    organization_id,
    student_id,
    organization_subject_id
  ) do nothing;

  with legacy_rows as (
    select
      legacy_assignment.id,
      student.organization_id,
      profile.id as profile_id,
      canonical_membership.id as membership_id,
      row_number() over (
        partition by profile.id
        order by legacy_assignment.id
      ) as assignment_order
    from public.teacher_assignments as legacy_assignment
    join public.students as student
      on student.id = legacy_assignment.student_id
    join public.memberships as legacy_membership
      on legacy_membership.user_id = legacy_assignment.teacher_id
     and legacy_membership.organization_id = student.organization_id
     and legacy_membership.status = 'active'
    join public.organization_memberships as canonical_membership
      on canonical_membership.id = legacy_membership.id
     and canonical_membership.status = 'active'
    join public.subjects as subject
      on subject.code = case trim(legacy_assignment.subject)
        when '数学' then 'math'
        when '英语' then 'english'
        else 'legacy_' || md5(trim(legacy_assignment.subject))
      end
    join public.organization_subjects as organization_subject
      on organization_subject.organization_id = student.organization_id
     and organization_subject.subject_id = subject.id
     and organization_subject.status = 'active'
    join public.student_subject_profiles as profile
      on profile.organization_id = student.organization_id
     and profile.student_id = student.id
     and profile.organization_subject_id = organization_subject.id
     and profile.status = 'active'
    where legacy_assignment.status = 'active'
  )
  insert into public.student_teacher_assignments (
    id,
    organization_id,
    student_subject_profile_id,
    membership_id,
    assignment_role,
    status,
    active_from
  )
  select
    legacy_row.id,
    legacy_row.organization_id,
    legacy_row.profile_id,
    legacy_row.membership_id,
    case when legacy_row.assignment_order = 1 then 'lead' else 'collaborator' end,
    'active',
    date '2026-01-01'
  from legacy_rows as legacy_row
  where not exists (
    select 1
    from public.student_teacher_assignments as existing_assignment
    where existing_assignment.student_subject_profile_id = legacy_row.profile_id
      and existing_assignment.membership_id = legacy_row.membership_id
      and existing_assignment.assignment_role = case
        when legacy_row.assignment_order = 1 then 'lead'
        else 'collaborator'
      end
      and existing_assignment.status = 'active'
  )
  on conflict (id) do nothing;
end;
$backfill$;
