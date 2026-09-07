-- UX support: let organization managers repair or maintain a member's
-- human-readable display name without changing roles, credentials, or
-- teaching relationships.

create or replace function private.update_organization_member_display_name(
  p_organization_id uuid,
  p_membership_id uuid,
  p_display_name text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_current_app_user_id uuid;
  v_target_app_user_id uuid;
  v_display_name text;
begin
  v_display_name := nullif(btrim(coalesce(p_display_name, '')), '');
  if p_organization_id is null
    or p_membership_id is null
    or v_display_name is null
    or char_length(v_display_name) > 120 then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_member_display_name';
  end if;

  v_current_app_user_id := (select private.current_app_user_id_v2());
  if v_current_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  if not (select private.can_manage_organization_v2(p_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  select membership.app_user_id
  into v_target_app_user_id
  from public.organization_memberships as membership
  where membership.id = p_membership_id
    and membership.organization_id = p_organization_id;

  if v_target_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'membership_not_found';
  end if;

  update public.app_users as app_user
  set display_name = v_display_name
  where app_user.id = v_target_app_user_id;

  return jsonb_build_object(
    'organization_id', p_organization_id,
    'membership_id', p_membership_id,
    'app_user_id', v_target_app_user_id,
    'display_name', v_display_name
  );
end
$function$;

revoke all on function private.update_organization_member_display_name(uuid, uuid, text)
  from public, anon, authenticated, service_role;
grant execute on function private.update_organization_member_display_name(uuid, uuid, text)
  to authenticated, service_role;

create or replace function public.update_organization_member_display_name(
  p_organization_id uuid,
  p_membership_id uuid,
  p_display_name text
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.update_organization_member_display_name(
    p_organization_id,
    p_membership_id,
    p_display_name
  )
$function$;

revoke all on function public.update_organization_member_display_name(uuid, uuid, text)
  from public, anon, authenticated, service_role;
grant execute on function public.update_organization_member_display_name(uuid, uuid, text)
  to authenticated, service_role;
