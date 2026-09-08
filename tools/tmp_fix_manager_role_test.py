from pathlib import Path

path = Path('supabase/tests/organization_invitation_access_test.sql')
text = path.read_text()
old = """select is(
  (
    select membership_role.role
    from public.membership_roles as membership_role
    join public.organization_memberships as membership
      on membership.id = membership_role.membership_id
    join public.app_users as app_user
      on app_user.id = membership.app_user_id
    where app_user.auth_subject_id = '20000000-0000-0000-0000-000000000004'
      and membership.organization_id =
        '00000000-0000-0000-0000-000000000002'
  ),
  'org_owner',
  'accepted invitations assign the requested role'
);
"""
new = """select ok(
  exists (
    select 1
    from public.membership_roles as membership_role
    join public.organization_memberships as membership
      on membership.id = membership_role.membership_id
    join public.app_users as app_user
      on app_user.id = membership.app_user_id
    where app_user.auth_subject_id = '20000000-0000-0000-0000-000000000004'
      and membership.organization_id =
        '00000000-0000-0000-0000-000000000002'
      and membership_role.role = 'org_owner'
  ),
  'accepted invitations assign the requested role'
);
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one invitation role assertion, got {count}')
path.write_text(text.replace(old, new, 1))
