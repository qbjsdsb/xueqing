-- v0.3.8 responsibility-aware read model.
--
-- This migration is intentionally additive. It does not change any Case write
-- command. It only exposes server-authoritative responsibility facts so the
-- client can distinguish Personal Projection from organization supervision.

create or replace view public.teacher_workspace_personal_assignments
with (security_invoker = true)
as
select
  assignment.id as assignment_id,
  assignment.organization_id,
  membership.id as membership_id,
  profile.id as student_subject_profile_id,
  assignment.assignment_role,
  (now() at time zone organization.time_zone)::date as business_date
from public.student_teacher_assignments as assignment
join public.student_subject_profiles as profile
  on profile.id = assignment.student_subject_profile_id
 and profile.organization_id = assignment.organization_id
join public.students as student
  on student.id = profile.student_id
 and student.organization_id = profile.organization_id
join public.organization_subjects as organization_subject
  on organization_subject.id = profile.organization_subject_id
 and organization_subject.organization_id = profile.organization_id
join public.subjects as subject
  on subject.id = organization_subject.subject_id
join public.organizations as organization
  on organization.id = assignment.organization_id
join public.organization_memberships as membership
  on membership.id = assignment.membership_id
 and membership.organization_id = assignment.organization_id
join public.membership_roles as teacher_role
  on teacher_role.membership_id = membership.id
 and teacher_role.organization_id = membership.organization_id
 and teacher_role.role = 'teacher'
join public.membership_subject_scopes as scope
  on scope.membership_id = membership.id
 and scope.organization_id = membership.organization_id
 and scope.organization_subject_id = profile.organization_subject_id
 and scope.scope_kind = 'teaching'
where organization.status = 'active'
  and membership.status = 'active'
  and membership.app_user_id = (select private.current_app_user_id_v2())
  and assignment.status = 'active'
  and assignment.active_from <=
    (now() at time zone organization.time_zone)::date
  and (
    assignment.active_to is null
    or assignment.active_to >=
      (now() at time zone organization.time_zone)::date
  )
  and profile.status = 'active'
  and student.status = 'active'
  and organization_subject.status = 'active'
  and subject.status = 'active'
  and scope.status = 'active'
  and scope.active_from <=
    (now() at time zone organization.time_zone)::date
  and (
    scope.active_to is null
    or scope.active_to >=
      (now() at time zone organization.time_zone)::date
  );

comment on view public.teacher_workspace_personal_assignments is
  'RLS-aware Personal Projection source. A manager appears only when that same membership has a real current teaching scope and Student Teacher Assignment.';

revoke all on table public.teacher_workspace_personal_assignments
  from anon, authenticated;
grant select on table public.teacher_workspace_personal_assignments
  to authenticated;

create or replace function private.workspace_responsibility_context_v2(
  p_organization_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_app_user_id uuid;
  v_membership_id uuid;
  v_personal_assignments jsonb;
  v_case_owners jsonb;
  v_action_assignees jsonb;
  v_event_actors jsonb;
  v_member_display_names jsonb;
begin
  if p_organization_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_organization_id';
  end if;

  v_app_user_id := (select private.current_app_user_id_v2());
  if v_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select membership.id
  into v_membership_id
  from public.organization_memberships as membership
  join public.organizations as organization
    on organization.id = membership.organization_id
   and organization.status = 'active'
  where membership.organization_id = p_organization_id
    and membership.app_user_id = v_app_user_id
    and membership.status = 'active'
  order by membership.id
  limit 1;

  if v_membership_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'organization_membership_required';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'assignment_id', personal.assignment_id,
        'profile_id', personal.student_subject_profile_id,
        'membership_id', personal.membership_id,
        'assignment_role', personal.assignment_role,
        'business_date', personal.business_date
      )
      order by personal.student_subject_profile_id, personal.assignment_id
    ),
    '[]'::jsonb
  )
  into v_personal_assignments
  from public.teacher_workspace_personal_assignments as personal
  where personal.organization_id = p_organization_id
    and personal.membership_id = v_membership_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'case_id', learning_case.id,
        'membership_id', learning_case.owner_membership_id
      )
      order by learning_case.id
    ) filter (where learning_case.owner_membership_id is not null),
    '[]'::jsonb
  )
  into v_case_owners
  from public.learning_cases as learning_case
  where learning_case.organization_id = p_organization_id
    and (select private.can_read_profile_v2(
      learning_case.student_subject_profile_id
    ));

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'action_id', action.id,
        'membership_id', action.assigned_membership_id
      )
      order by action.id
    ) filter (where action.assigned_membership_id is not null),
    '[]'::jsonb
  )
  into v_action_assignees
  from public.case_actions as action
  join public.learning_cases as learning_case
    on learning_case.id = action.learning_case_id
   and learning_case.organization_id = action.organization_id
  where action.organization_id = p_organization_id
    and (select private.can_read_profile_v2(
      learning_case.student_subject_profile_id
    ));

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'event_id', event.id,
        'membership_id', event.actor_membership_id
      )
      order by event.occurred_at, event.id
    ) filter (where event.actor_membership_id is not null),
    '[]'::jsonb
  )
  into v_event_actors
  from public.case_events as event
  join public.learning_cases as learning_case
    on learning_case.id = event.learning_case_id
   and learning_case.organization_id = event.organization_id
  where event.organization_id = p_organization_id
    and (select private.can_read_profile_v2(
      learning_case.student_subject_profile_id
    ));

  with candidate_memberships as (
    select v_membership_id as membership_id

    union

    select personal.membership_id
    from public.teacher_workspace_personal_assignments as personal
    where personal.organization_id = p_organization_id
      and personal.membership_id = v_membership_id

    union

    select learning_case.owner_membership_id
    from public.learning_cases as learning_case
    where learning_case.organization_id = p_organization_id
      and learning_case.owner_membership_id is not null
      and (select private.can_read_profile_v2(
        learning_case.student_subject_profile_id
      ))

    union

    select action.assigned_membership_id
    from public.case_actions as action
    join public.learning_cases as learning_case
      on learning_case.id = action.learning_case_id
     and learning_case.organization_id = action.organization_id
    where action.organization_id = p_organization_id
      and action.assigned_membership_id is not null
      and (select private.can_read_profile_v2(
        learning_case.student_subject_profile_id
      ))

    union

    select event.actor_membership_id
    from public.case_events as event
    join public.learning_cases as learning_case
      on learning_case.id = event.learning_case_id
     and learning_case.organization_id = event.organization_id
    where event.organization_id = p_organization_id
      and event.actor_membership_id is not null
      and (select private.can_read_profile_v2(
        learning_case.student_subject_profile_id
      ))
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'membership_id', membership.id,
        'display_name', coalesce(
          nullif(btrim(app_user.display_name), ''),
          '未命名老师'
        )
      )
      order by membership.id
    ),
    '[]'::jsonb
  )
  into v_member_display_names
  from candidate_memberships as candidate
  join public.organization_memberships as membership
    on membership.id = candidate.membership_id
   and membership.organization_id = p_organization_id
  join public.app_users as app_user
    on app_user.id = membership.app_user_id;

  return jsonb_build_object(
    'organization_id', p_organization_id,
    'current_membership_id', v_membership_id,
    'personal_assignments', v_personal_assignments,
    'case_owners', v_case_owners,
    'action_assignees', v_action_assignees,
    'event_actors', v_event_actors,
    'member_display_names', v_member_display_names
  );
end
$function$;

revoke all on function private.workspace_responsibility_context_v2(uuid)
  from public, anon, authenticated, service_role;
grant execute on function private.workspace_responsibility_context_v2(uuid)
  to authenticated;

create or replace function public.get_workspace_responsibility_context(
  p_organization_id uuid
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select private.workspace_responsibility_context_v2(p_organization_id)
$function$;

revoke all on function public.get_workspace_responsibility_context(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.get_workspace_responsibility_context(uuid)
  to authenticated;

comment on function public.get_workspace_responsibility_context(uuid) is
  'Returns current membership, Personal Assignment facts, responsibility membership ids, and minimal display names for learning records the caller may already read.';
