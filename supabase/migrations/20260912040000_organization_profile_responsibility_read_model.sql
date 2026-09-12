-- v0.3.8 D0: organization responsibility projection facts.
--
-- Extend the existing responsibility context instead of introducing a second
-- organization-only truth source. The original B1 function remains the source
-- for Personal Assignments / Case owners / Action assignees / event actors.
-- This additive wrapper contributes one server-authoritative fact needed by the
-- Organization workspace: Profile -> current valid Lead membership.
--
-- A missing Lead is represented explicitly as JSON null. The client must not
-- infer a fallback from Case ownership, collaborators, or manager authority.

create or replace function private.workspace_responsibility_context_with_profile_leads_v2(
  p_organization_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_base jsonb;
  v_profile_responsibilities jsonb;
  v_member_display_names jsonb;
begin
  -- Reuse the already-proven membership gate and existing responsibility facts.
  v_base := private.workspace_responsibility_context_v2(p_organization_id);

  with readable_profile_responsibilities as (
    select
      profile.id as profile_id,
      private.current_active_lead_membership_for_profile_v2(profile.id)
        as lead_membership_id
    from public.student_subject_profiles as profile
    where profile.organization_id = p_organization_id
      and profile.status = 'active'
      and private.can_read_profile_v2(profile.id)
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'profile_id', responsibility.profile_id,
        'lead_membership_id', responsibility.lead_membership_id
      )
      order by responsibility.profile_id
    ),
    '[]'::jsonb
  )
  into v_profile_responsibilities
  from readable_profile_responsibilities as responsibility;

  -- Preserve the existing minimal member directory and add only current Leads
  -- referenced by readable Profiles. Unrelated organization members stay out.
  with existing_names as (
    select
      item->>'membership_id' as membership_id,
      item->>'display_name' as display_name
    from jsonb_array_elements(
      coalesce(v_base->'member_display_names', '[]'::jsonb)
    ) as item
    where nullif(item->>'membership_id', '') is not null
  ),
  readable_lead_memberships as (
    select distinct
      private.current_active_lead_membership_for_profile_v2(profile.id)
        as membership_id
    from public.student_subject_profiles as profile
    where profile.organization_id = p_organization_id
      and profile.status = 'active'
      and private.can_read_profile_v2(profile.id)
  ),
  lead_names as (
    select
      membership.id::text as membership_id,
      coalesce(nullif(btrim(app_user.display_name), ''), '未命名老师')
        as display_name
    from readable_lead_memberships as lead
    join public.organization_memberships as membership
      on membership.id = lead.membership_id
     and membership.organization_id = p_organization_id
     and membership.status = 'active'
    join public.app_users as app_user
      on app_user.id = membership.app_user_id
    where lead.membership_id is not null
  ),
  merged_names as (
    select membership_id, display_name from existing_names
    union
    select membership_id, display_name from lead_names
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'membership_id', merged.membership_id,
        'display_name', merged.display_name
      )
      order by merged.membership_id
    ),
    '[]'::jsonb
  )
  into v_member_display_names
  from merged_names as merged;

  return v_base || jsonb_build_object(
    'profile_responsibilities', v_profile_responsibilities,
    'member_display_names', v_member_display_names
  );
end
$function$;

revoke all on function private.workspace_responsibility_context_with_profile_leads_v2(uuid)
  from public, anon, authenticated, service_role;
grant execute on function private.workspace_responsibility_context_with_profile_leads_v2(uuid)
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
  select private.workspace_responsibility_context_with_profile_leads_v2(
    p_organization_id
  )
$function$;

revoke all on function public.get_workspace_responsibility_context(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.get_workspace_responsibility_context(uuid)
  to authenticated;

comment on function private.workspace_responsibility_context_with_profile_leads_v2(uuid) is
  'Adds Profile -> current valid Lead responsibility to the existing responsibility snapshot while preserving the minimal member-name directory.';
comment on function public.get_workspace_responsibility_context(uuid) is
  'Returns current membership, Personal Assignment facts, learning responsibility actors, Profile current Leads, and only the minimal display names referenced by readable learning facts.';
