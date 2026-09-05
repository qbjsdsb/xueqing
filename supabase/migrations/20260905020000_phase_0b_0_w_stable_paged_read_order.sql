-- Phase 0B.0-W: make offset-paged management reads deterministic.
-- Existing student, scope, and assignment readers already end their order by
-- a unique id. This migration adds the missing tie-breakers for members and
-- invitations without changing their authorization or result shape.

create or replace function public.list_organization_members(
  p_organization_id uuid
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
begin
  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  if p_organization_id is null
    or not (select private.can_manage_organization_v2(p_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  return query
  select jsonb_build_object(
    'app_user_id', app_user.id,
    'membership_id', membership.id,
    'email', coalesce(auth_user.email, ''),
    'display_name', app_user.display_name,
    'status', membership.status,
    'version', membership.version,
    'onboarding_expires_at', membership.onboarding_expires_at,
    'roles', coalesce(
      (
        select jsonb_agg(
          membership_role.role
          order by membership_role.role
        )
        from public.membership_roles as membership_role
        where membership_role.membership_id = membership.id
          and membership_role.organization_id = membership.organization_id
      ),
      '[]'::jsonb
    )
  )
  from public.organization_memberships as membership
  join public.app_users as app_user
    on app_user.id = membership.app_user_id
  left join auth.users as auth_user
    on auth_user.id::text = app_user.auth_subject_id
   and app_user.auth_provider = 'supabase'
  where membership.organization_id = p_organization_id
  order by app_user.display_name, auth_user.email, membership.id;
end
$function$;

create or replace function public.list_organization_invitations(
  p_organization_id uuid
)
returns setof jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
begin
  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  if p_organization_id is null
    or not (select private.can_manage_organization_v2(p_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  update public.organization_invitations
  set status = 'expired',
      updated_at = now()
  where organization_id = p_organization_id
    and status in ('pending', 'pending_owner_approval')
    and expires_at <= now();

  return query
  select jsonb_build_object(
    'id', invitation.id,
    'email', invitation.email,
    'role', invitation.role,
    'status', invitation.status,
    'expires_at', invitation.expires_at,
    'created_at', invitation.created_at,
    'invited_by_name', inviter.display_name
  )
  from public.organization_invitations as invitation
  join public.app_users as inviter
    on inviter.id = invitation.invited_by_app_user_id
  where invitation.organization_id = p_organization_id
    and invitation.status not in ('accepted', 'revoked')
  order by invitation.created_at desc, invitation.id desc;
end
$function$;
