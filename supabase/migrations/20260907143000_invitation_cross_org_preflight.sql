-- Reject invitations that cannot be completed under the current one-organization
-- membership model. Previously the invite could be created successfully and only
-- fail during account provisioning, leaving operators with a dead-end "开通失败".

create or replace function private.create_organization_invitation(
  p_organization_id uuid,
  p_email text,
  p_role text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
begin
  if not (select private.can_manage_member_accounts_v2(p_organization_id)) then
    raise exception using errcode = 'P0001', message = 'organization_owner_required';
  end if;

  -- Keep the legacy function authoritative for ordinary input validation and
  -- same-organization duplicate handling. This preflight only catches the
  -- cross-organization state that makes provisioning impossible.
  if p_organization_id is not null
    and char_length(v_email) between 3 and 320
    and position('@' in v_email) > 1
    and exists (
      select 1
      from auth.users as auth_user
      join public.app_users as app_user
        on app_user.auth_provider = 'supabase'
       and app_user.auth_subject_id = auth_user.id::text
       and app_user.status = 'active'
      join public.organization_memberships as membership
        on membership.app_user_id = app_user.id
       and membership.status in ('onboarding', 'active')
      where lower(auth_user.email) = v_email
        and membership.organization_id <> p_organization_id
    ) then
    raise exception using
      errcode = 'P0001',
      message = 'user_already_member_elsewhere';
  end if;

  return private.create_organization_invitation_manager_legacy(
    p_organization_id,
    p_email,
    p_role
  );
end
$function$;

-- Clean up only invitations that are provably impossible to complete for the
-- same reason. Historical accepted/revoked rows are untouched.
update public.organization_invitations as invitation
set status = 'revoked',
    revoked_at = coalesce(invitation.revoked_at, timezone('utc', now())),
    updated_at = timezone('utc', now())
where invitation.status in ('pending', 'pending_owner_approval')
  and exists (
    select 1
    from auth.users as auth_user
    join public.app_users as app_user
      on app_user.auth_provider = 'supabase'
     and app_user.auth_subject_id = auth_user.id::text
     and app_user.status = 'active'
    join public.organization_memberships as membership
      on membership.app_user_id = app_user.id
     and membership.status in ('onboarding', 'active')
    where lower(auth_user.email) = lower(invitation.email)
      and membership.organization_id <> invitation.organization_id
  );
