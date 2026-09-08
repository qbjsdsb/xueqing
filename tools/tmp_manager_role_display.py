from pathlib import Path

rows = Path('lib/features/organization_management/presentation/organization_management_rows.dart')
text = rows.read_text()
old = """          Wrap(\n            spacing: AppSpacing.xs,\n            runSpacing: AppSpacing.xxs,\n            children: [\n              for (final role in member.roles)\n                _ManagementRoleChip(label: _roleLabel(role)),\n              _ManagementStatusChip(\n"""
new = """          Wrap(\n            spacing: AppSpacing.xs,\n            runSpacing: AppSpacing.xxs,\n            children: [\n              for (final label in _memberRoleLabels(member.roles))\n                _ManagementRoleChip(label: label),\n              _ManagementStatusChip(\n"""
if text.count(old) != 1:
    raise SystemExit(f'member role chips anchor mismatch: {text.count(old)}')
text = text.replace(old, new, 1)
rows.write_text(text)

helpers = Path('lib/features/organization_management/presentation/organization_management_helpers.dart')
h = helpers.read_text()
anchor = """String _roleLabel(String role) {\n"""
helper = """List<String> _memberRoleLabels(List<String> roles) {\n  final roleSet = roles.toSet();\n  final labels = <String>[];\n  final isOwner = roleSet.contains('org_owner');\n  final isAdmin = roleSet.contains('org_admin');\n  final canTeach = roleSet.contains('teacher');\n\n  if (isOwner) {\n    labels.add('负责人');\n  } else if (isAdmin) {\n    labels.add('管理员');\n  } else if (canTeach) {\n    labels.add('老师');\n  }\n\n  if ((isOwner || isAdmin) && canTeach) {\n    labels.add('兼任教学');\n  }\n\n  for (final role in roles) {\n    if (role == 'org_owner' || role == 'org_admin' || role == 'teacher') {\n      continue;\n    }\n    labels.add(_roleLabel(role));\n  }\n  return labels.isEmpty ? const <String>['机构成员'] : labels;\n}\n\nString _roleLabel(String role) {\n"""
if h.count(anchor) != 1:
    raise SystemExit(f'role helper anchor mismatch: {h.count(anchor)}')
h = h.replace(anchor, helper, 1)
helpers.write_text(h)

# Add a regression against the manager+teacher combination now used by the backend.
test = Path('test/features/organization_management_test.dart')
t = test.read_text()
insert_before = """  testWidgets('"""
idx = t.find(insert_before)
if idx < 0:
    raise SystemExit('no widget-test insertion anchor')
case = """  testWidgets('manager teaching capability is shown as a responsibility, not a duplicate role', (tester) async {\n    final repository = _FakeOrganizationManagementRepository()\n      ..members = [\n        _memberFixture(\n          email: 'owner-teacher@example.com',\n          roles: const ['org_owner', 'teacher'],\n        ),\n      ];\n\n    await _pumpManagement(\n      tester,\n      repository,\n      roles: const ['org_owner', 'teacher'],\n    );\n\n    expect(find.text('负责人'), findsOneWidget);\n    expect(find.text('兼任教学'), findsOneWidget);\n  });\n\n"""
t = t[:idx] + case + t[idx:]
test.write_text(t)
