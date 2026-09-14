from pathlib import Path

AREAS = Path('lib/features/organization_management/presentation/organization_management_areas.dart')
SURFACE_TEST = Path('test/features/v2_surface_hierarchy_contract_test.dart')
WORKFLOW = Path('.github/workflows/quiet-professional-management-hierarchy-v9.yml')
SCRIPT = Path('.github/scripts/quiet_professional_management_v9.py')

areas = AREAS.read_text()
old = '''    return Container(\n      width: double.infinity,\n      padding: const EdgeInsets.all(AppSpacing.md),\n      decoration: BoxDecoration(\n        color: colorScheme.surfaceContainerLow,\n        border: Border(left: BorderSide(color: colorScheme.primary, width: 2)),\n      ),'''
new = '''    return Container(\n      key: const Key('management-setup-next-step'),\n      width: double.infinity,\n      padding: const EdgeInsets.symmetric(\n        horizontal: AppSpacing.md,\n        vertical: AppSpacing.sm,\n      ),\n      decoration: BoxDecoration(\n        color: Colors.transparent,\n        border: Border(left: BorderSide(color: colorScheme.primary, width: 2)),\n      ),'''
assert areas.count(old) == 1, 'setup-next-step surface block changed unexpectedly'
areas = areas.replace(old, new, 1)
AREAS.write_text(areas)

test = SURFACE_TEST.read_text()
needle = '''  test('management utility cues use line and spacing before extra fills', () {\n    final management = File(\n      'lib/features/organization_management/presentation/organization_management_layout.dart',\n    ).readAsStringSync();\n'''
replacement = '''  test('management utility cues use line and spacing before extra fills', () {\n    final management = File(\n      'lib/features/organization_management/presentation/organization_management_layout.dart',\n    ).readAsStringSync();\n    final managementAreas = File(\n      'lib/features/organization_management/presentation/organization_management_areas.dart',\n    ).readAsStringSync();\n'''
assert test.count(needle) == 1, 'surface hierarchy test setup changed unexpectedly'
test = test.replace(needle, replacement, 1)

insert_before = '''    final setupHint = _slice(\n      management,\n      'class _ManagementSetupHint',\n      'class _ManagementEmptyState',\n    );\n    expect(setupHint, contains('color: Colors.transparent,'));\n    expect(setupHint, isNot(contains('surfaceContainerLow')));\n  });\n}'''
insert_after = '''    final setupHint = _slice(\n      management,\n      'class _ManagementSetupHint',\n      'class _ManagementEmptyState',\n    );\n    expect(setupHint, contains('color: Colors.transparent,'));\n    expect(setupHint, isNot(contains('surfaceContainerLow')));\n\n    final setupNextStep = _slice(\n      managementAreas,\n      'Widget? _buildSetupNextStep()',\n      'OrganizationManagementArea _initialArea',\n    );\n    expect(\n      setupNextStep,\n      contains("key: const Key('management-setup-next-step')"),\n    );\n    expect(setupNextStep, contains('color: Colors.transparent,'));\n    expect(setupNextStep, isNot(contains('surfaceContainerLow')));\n    expect(setupNextStep, contains('FilledButton.tonal('));\n  });\n}'''
assert test.count(insert_before) == 1, 'surface hierarchy test ending changed unexpectedly'
test = test.replace(insert_before, insert_after, 1)
SURFACE_TEST.write_text(test)

if WORKFLOW.exists():
    WORKFLOW.unlink()
if SCRIPT.exists():
    SCRIPT.unlink()
