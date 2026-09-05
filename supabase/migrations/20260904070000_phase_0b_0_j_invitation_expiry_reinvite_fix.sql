-- Phase 0B.0-J: allow safe re-invitation after expiry.
-- This forward migration keeps invitation history while releasing expired
-- pending rows from the open-invitation uniqueness guard.

create or replace function public.create_organization_invitation(
  p_organization_id uuid,
  p_email text,
  p_role text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  normalized_email text;
  normalized_role text;
  current_app_user_id uuid;
  current_membership_id uuid;
  caller_is_owner boolean;
  invitation_status text;
  invitation_id uuid := gen_random_uuid();
  invite_code text;
  invitation_expires_at timestamptz := now() + interval '7 days';
begin
  normalized_email := lower(btrim(coalesce(p_email, '')));
  normalized_role := lower(btrim(coalesce(p_role, '')));

  if p_organization_id is null
    or char_length(normalized_email) < 3
    or char_length(normalized_email) > 320
    or position('@' in normalized_email) <= 1
    or normalized_role not in (
      'org_owner',
      'org_admin',
      'academic_admin',
      'teacher'
    ) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_invitation_input';
  end if;

  current_app_user_id := (select private.current_app_user_id_v2());
  if current_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  current_membership_id := (
    select private.current_membership_for_organization_v2(
      p_organization_id
    )
  );
  if current_membership_id is null
    or not (select private.can_manage_organization_v2(p_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  caller_is_owner := exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.membership_id = current_membership_id
      and membership_role.organization_id = p_organization_id
      and membership_role.role = 'org_owner'
  );

  if caller_is_owner then
    if normalized_role not in (
      'org_owner',
      'org_admin',
      'academic_admin',
      'teacher'
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'role_not_allowed';
    end if;
    invitation_status := 'pending';
  elsif normalized_role not in ('org_owner', 'teacher') then
    raise exception using
      errcode = 'P0001',
      message = 'role_not_allowed';
  else
    -- An admin may nominate a responsible person, but cannot activate
    -- that elevated role without an existing responsible person's approval.
    invitation_status := case
      when normalized_role = 'org_owner' then 'pending_owner_approval'
      else 'pending'
    end;
  end if;

  if exists (
    select 1
    from auth.users as auth_user
    join public.app_users as app_user
      on app_user.auth_provider = 'supabase'
     and app_user.auth_subject_id = auth_user.id::text
    join public.organization_memberships as membership
      on membership.app_user_id = app_user.id
     and membership.organization_id = p_organization_id
     and membership.status in ('onboarding', 'active')
    where lower(auth_user.email) = normalized_email
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'invitee_already_member';
  end if;

  -- Release an expired open invitation before the partial unique index
  -- can block a fresh invitation for the same email and role.
  update public.organization_invitations as invitation
  set status = 'expired',
      updated_at = now()
  where invitation.organization_id = p_organization_id
    and lower(invitation.email) = normalized_email
    and invitation.role = normalized_role
    and invitation.status in ('pending', 'pending_owner_approval')
    and invitation.expires_at <= now();

  if exists (
    select 1
    from public.organization_invitations as invitation
    where invitation.organization_id = p_organization_id
      and lower(invitation.email) = normalized_email
      and invitation.role = normalized_role
      and invitation.status in ('pending', 'pending_owner_approval')
      and invitation.expires_at > now()
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_already_exists';
  end if;

  invite_code := encode(extensions.gen_random_bytes(12), 'hex');

  insert into public.organization_invitations (
    id,
    organization_id,
    email,
    role,
    status,
    invite_code_hash,
    invited_by_app_user_id,
    invited_by_membership_id,
    expires_at
  )
  values (
    invitation_id,
    p_organization_id,
    normalized_email,
    normalized_role,
    invitation_status,
    encode(extensions.digest(invite_code, 'sha256'), 'hex'),
    current_app_user_id,
    current_membership_id,
    invitation_expires_at
  );

  return jsonb_build_object(
    'id', invitation_id,
    'email', normalized_email,
    'role', normalized_role,
    'status', invitation_status,
    'expires_at', invitation_expires_at,
    'invite_code', invite_code
  );
end
$function$;
