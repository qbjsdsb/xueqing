-- Phase 0B.0-E: retire the compatibility identity path.
--
-- The preceding backfill migration copied the fictional development fixture into
-- the canonical identity and assignment model. This migration first verifies
-- that every remaining legacy row has a canonical representation, then removes
-- the legacy API surface. It is intentionally destructive only to the disposable
-- compatibility tables; it never runs against production data.

do $preflight$
begin
  if exists (
    select 1
    from public.memberships as legacy_membership
    where not exists (
      select 1
      from public.organization_memberships as canonical_membership
      join public.membership_roles as canonical_role
        on canonical_role.membership_id = canonical_membership.id
       and canonical_role.organization_id = canonical_membership.organization_id
       and canonical_role.role = legacy_membership.role
      where canonical_membership.id = legacy_membership.id
        and canonical_membership.organization_id = legacy_membership.organization_id
        and canonical_membership.app_user_id = legacy_membership.user_id
        and canonical_membership.status = case
          when legacy_membership.status = 'active' then 'active'
          else 'disabled'
        end
    )
  ) then
    raise exception
      'Legacy memberships are not fully represented in the canonical model.';
  end if;

  if exists (
    select 1
    from public.teacher_assignments as legacy_assignment
    where legacy_assignment.status <> 'active'
       or not exists (
         select 1
         from public.students as student
         join public.memberships as legacy_membership
           on legacy_membership.user_id = legacy_assignment.teacher_id
          and legacy_membership.organization_id = student.organization_id
          and legacy_membership.status = 'active'
         join public.organization_memberships as canonical_membership
           on canonical_membership.id = legacy_membership.id
          and canonical_membership.organization_id = legacy_membership.organization_id
         join public.subjects as subject
           on subject.code = case trim(legacy_assignment.subject)
             when '数学' then 'math'
             when '英语' then 'english'
             else 'legacy_' || md5(trim(legacy_assignment.subject))
           end
         join public.organization_subjects as organization_subject
           on organization_subject.organization_id = student.organization_id
          and organization_subject.subject_id = subject.id
         join public.student_subject_profiles as profile
           on profile.organization_id = student.organization_id
          and profile.student_id = legacy_assignment.student_id
          and profile.organization_subject_id = organization_subject.id
         where student.id = legacy_assignment.student_id
           and char_length(btrim(legacy_assignment.subject)) > 0
           and exists (
             select 1
             from public.student_teacher_assignments as canonical_assignment
             where canonical_assignment.organization_id = student.organization_id
               and canonical_assignment.student_subject_profile_id = profile.id
               and canonical_assignment.membership_id = canonical_membership.id
               and canonical_assignment.status = 'active'
           )
       )
  ) then
    raise exception
      'Legacy teacher assignments are not fully represented by active canonical assignments.';
  end if;
end;
$preflight$;

-- Remove the old policies before removing the helper functions they reference.
drop policy if exists "users can read their own application identity"
  on public.app_users;
drop policy if exists "users can read their active memberships"
  on public.memberships;
drop policy if exists "teachers can read their active assignments"
  on public.teacher_assignments;

revoke all on table public.memberships from anon, authenticated;
revoke all on table public.teacher_assignments from anon, authenticated;

drop function if exists private.can_read_assignment(uuid);
drop function if exists private.can_read_student(uuid);
drop function if exists private.can_read_organization(uuid);
drop function if exists private.current_app_user_id();

drop table public.teacher_assignments;
drop table public.memberships;
