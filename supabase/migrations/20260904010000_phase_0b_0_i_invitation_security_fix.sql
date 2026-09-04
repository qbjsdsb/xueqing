-- Phase 0B.0-I: invitation security and role-boundary forward fix.
-- This migration repairs the already-applied H migration without rewriting
-- migration history. It is for the fictional Remote Development path only.
--
-- The H migration revoked PUBLIC on exposed invitation functions, but the
-- explicit anon grant inherited by Supabase remained. The acceptance function
-- also used app_user_id as both a PL/pgSQL variable and a column reference.
-- Keep the invitation table private to guarded RPCs.

create or replace function private.can_manage_organization_v2(
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
    join public.membership_roles as membership_role
      on membership_role.membership_id = membership.id
     and membership_role.organization_id = membership.organization_id
     and membership_role.role in (
       'org_owner',
       'org_admin'
     )
    join public.organizations as organization
      on organization.id = membership.organization_id
     and organization.status = 'active'
    where membership.organization_id = target_organization_id
      and membership.app_user_id =
        (select private.current_app_user_id_v2())
      and membership.status = 'active'
  )
$function$;

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
    encode(digest(btrim(p_invite_code), 'sha256'), 'hex')
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

-- Private helpers are not client entry points.
revoke all on function private.can_manage_organization_v2(uuid)
  from public, anon, authenticated;
revoke all on function private.current_membership_for_organization_v2(uuid)
  from public, anon, authenticated;
revoke all on function private.can_manage_case_types_v2(uuid)
  from public, anon, authenticated;

-- Public RPCs are still guarded by their own live-session and role checks,
-- but anonymous clients must not be able to invoke them at all.
revoke execute on function public.create_organization_invitation(uuid, text, text)
  from public, anon;
revoke execute on function public.list_organization_members(uuid)
  from public, anon;
revoke execute on function public.list_organization_invitations(uuid)
  from public, anon;
revoke execute on function public.approve_organization_invitation(uuid)
  from public, anon;
revoke execute on function public.revoke_organization_invitation(uuid)
  from public, anon;
revoke execute on function public.accept_organization_invitation(text, text)
  from public, anon;

grant execute on function public.create_organization_invitation(uuid, text, text)
  to authenticated;
grant execute on function public.list_organization_members(uuid)
  to authenticated;
grant execute on function public.list_organization_invitations(uuid)
  to authenticated;
grant execute on function public.approve_organization_invitation(uuid)
  to authenticated;
grant execute on function public.revoke_organization_invitation(uuid)
  to authenticated;
grant execute on function public.accept_organization_invitation(text, text)
  to authenticated;

alter table public.organization_invitations enable row level security;
revoke all on table public.organization_invitations
  from public, anon, authenticated;