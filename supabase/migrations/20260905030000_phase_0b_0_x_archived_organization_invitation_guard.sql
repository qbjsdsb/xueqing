-- Phase 0B.0-X: reject invitation acceptance after an organization is archived.
-- Acceptance locks the organization row before creating identity or membership
-- records so an archive and an acceptance cannot both commit successfully.

create or replace function public.accept_organization_invitation(
  p_invite_code text,
  p_display_name text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_invitation public.organization_invitations%rowtype;
  v_auth_user_id uuid := (select auth.uid());
  v_auth_email text := lower(
    btrim(coalesce((select auth.jwt() ->> 'email'), ''))
  );
  v_organization_status text;
  v_app_user_id uuid;
  v_app_user_status text;
  v_membership_id uuid;
  v_membership_status text;
  v_resolved_display_name text;
begin
  if v_auth_user_id is null
    or v_auth_email = '' then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  if not (select private.has_live_auth_session_v2()) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  if p_invite_code is null
    or char_length(btrim(p_invite_code)) < 16 then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_invitation_input';
  end if;

  select *
  into v_invitation
  from public.organization_invitations as invitation
  where invitation.invite_code_hash =
    encode(extensions.digest(btrim(p_invite_code), 'sha256'), 'hex')
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_found';
  end if;

  if v_invitation.status = 'pending_owner_approval' then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_approved';
  end if;

  if v_invitation.status <> 'pending' then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_available';
  end if;

  if v_invitation.expires_at <= now() then
    update public.organization_invitations
    set status = 'expired',
        updated_at = now()
    where id = v_invitation.id;

    raise exception using
      errcode = 'P0001',
      message = 'invitation_expired';
  end if;

  if v_auth_email <> v_invitation.email then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_email_mismatch';
  end if;

  select organization.status
  into v_organization_status
  from public.organizations as organization
  where organization.id = v_invitation.organization_id
  for update;

  if not found or v_organization_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'organization_not_available';
  end if;

  select app_user.id, app_user.status
  into v_app_user_id, v_app_user_status
  from public.app_users as app_user
  where app_user.auth_provider = 'supabase'
    and app_user.auth_subject_id = v_auth_user_id::text
  limit 1;

  if v_app_user_id is null then
    v_resolved_display_name := nullif(
      btrim(coalesce(p_display_name, '')),
      ''
    );

    if v_resolved_display_name is null then
      v_resolved_display_name := split_part(v_auth_email, '@', 1);
    end if;

    v_resolved_display_name := left(v_resolved_display_name, 120);

    insert into public.app_users (
      auth_provider,
      auth_subject_id,
      display_name,
      status
    )
    values (
      'supabase',
      v_auth_user_id::text,
      v_resolved_display_name,
      'active'
    )
    returning id into v_app_user_id;

    insert into public.identity_links (
      app_user_id,
      provider_key,
      issuer,
      external_subject,
      status
    )
    values (
      v_app_user_id,
      'supabase',
      coalesce(
        nullif((select auth.jwt() ->> 'iss'), ''),
        'supabase'
      ),
      v_auth_user_id::text,
      'active'
    );
  elsif v_app_user_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'app_user_disabled';
  end if;

  select membership.id, membership.status
  into v_membership_id, v_membership_status
  from public.organization_memberships as membership
  where membership.organization_id = v_invitation.organization_id
    and membership.app_user_id = v_app_user_id
  for update;

  if v_membership_id is null then
    if exists (
      select 1
      from public.organization_memberships as existing_membership
      where existing_membership.app_user_id = v_app_user_id
        and existing_membership.status in ('onboarding', 'active')
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'user_already_member_elsewhere';
    end if;

    insert into public.organization_memberships (
      organization_id,
      app_user_id,
      status
    )
    values (
      v_invitation.organization_id,
      v_app_user_id,
      'active'
    )
    returning id into v_membership_id;
  elsif v_membership_status in ('disabled', 'onboarding') then
    update public.organization_memberships
    set status = 'active',
        updated_at = now()
    where id = v_membership_id;
  end if;

  if exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.membership_id = v_membership_id
      and membership_role.organization_id = v_invitation.organization_id
      and membership_role.role = v_invitation.role
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_already_member';
  end if;

  insert into public.membership_roles (
    organization_id,
    membership_id,
    role
  )
  values (
    v_invitation.organization_id,
    v_membership_id,
    v_invitation.role
  );

  update public.organization_invitations
  set status = 'accepted',
      accepted_by_app_user_id = v_app_user_id,
      accepted_at = now(),
      updated_at = now()
  where id = v_invitation.id;

  return jsonb_build_object(
    'invitation_id', v_invitation.id,
    'organization_id', v_invitation.organization_id,
    'membership_id', v_membership_id,
    'app_user_id', v_app_user_id,
    'role', v_invitation.role,
    'status', 'accepted'
  );
end
$function$;

revoke execute on function public.accept_organization_invitation(text, text)
  from public, anon;
grant execute on function public.accept_organization_invitation(text, text)
  to authenticated;
