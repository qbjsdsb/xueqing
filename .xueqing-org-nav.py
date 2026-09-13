from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'missing {label}')
    return text.replace(old, new, 1)

areas_path = Path('lib/features/organization_management/presentation/organization_management_areas.dart')
areas = areas_path.read_text(encoding='utf-8').replace('_ManagementArea', 'OrganizationManagementArea')
areas = replace_once(
    areas,
    '    this.onProvisionInvitation,\n',
    '    this.initialArea,\n    this.onAreaChanged,\n    this.onProvisionInvitation,\n',
    'management overview optional args',
)
areas = replace_once(
    areas,
    '  final bool canManageCaseTypes;\n  final VoidCallback? onOpenCaseTypes;\n',
    '  final bool canManageCaseTypes;\n  final OrganizationManagementArea? initialArea;\n  final ValueChanged<OrganizationManagementArea>? onAreaChanged;\n  final VoidCallback? onOpenCaseTypes;\n',
    'management overview fields',
)
areas = replace_once(
    areas,
    '    _selectedArea = _initialArea(widget.snapshot);\n',
    "    _selectedArea = widget.initialArea ?? _initialArea(widget.snapshot);\n    if (widget.initialArea == null && widget.onAreaChanged != null) {\n      WidgetsBinding.instance.addPostFrameCallback((_) {\n        if (mounted) widget.onAreaChanged?.call(_selectedArea);\n      });\n    }\n",
    'initial management area',
)
areas = replace_once(
    areas,
    '  @override\n  void dispose() {\n',
    "  @override\n  void didUpdateWidget(covariant _ManagementOverview oldWidget) {\n    super.didUpdateWidget(oldWidget);\n    final requested = widget.initialArea;\n    if (requested != null && requested != _selectedArea) {\n      _selectedArea = requested;\n    }\n  }\n\n  @override\n  void dispose() {\n",
    'management didUpdateWidget',
)
areas = replace_once(
    areas,
    '            setState(() => _selectedArea = area);\n',
    '            setState(() => _selectedArea = area);\n            widget.onAreaChanged?.call(area);\n',
    'management area callback',
)
areas_path.write_text(areas, encoding='utf-8')

page_path = Path('lib/features/organization_management/presentation/organization_management_page.dart')
page = page_path.read_text(encoding='utf-8')
page = replace_once(
    page,
    '    this.refreshRevision = 0,\n    super.key,\n',
    '    this.refreshRevision = 0,\n    this.initialArea,\n    this.onAreaChanged,\n    super.key,\n',
    'management page constructor',
)
page = replace_once(
    page,
    '  final int refreshRevision;\n',
    '  final int refreshRevision;\n  final OrganizationManagementArea? initialArea;\n  final ValueChanged<OrganizationManagementArea>? onAreaChanged;\n',
    'management page area fields',
)
page = replace_once(
    page,
    '                              snapshot: snapshotState.data!,\n',
    '                              snapshot: snapshotState.data!,\n                              initialArea: widget.initialArea,\n                              onAreaChanged: widget.onAreaChanged,\n',
    'management overview area wiring',
)
page_path.write_text(page, encoding='utf-8')

org_path = Path('lib/features/design_v2/v2_organization_workspace_page.dart')
org = org_path.read_text(encoding='utf-8')
org = replace_once(
    org,
    '  V2OrganizationSection _section = V2OrganizationSection.learning;\n',
    '  V2OrganizationSection _section = V2OrganizationSection.learning;\n  OrganizationManagementArea? _managementArea;\n',
    'organization management area state',
)
org = replace_once(
    org,
    '  @override\n  void dispose() {\n    _managementScrollController.dispose();\n',
    "  void _handleManagementAreaChanged(OrganizationManagementArea area) {\n    if (_managementArea == area) return;\n    setState(() => _managementArea = area);\n  }\n\n  @override\n  void dispose() {\n    _managementScrollController.dispose();\n",
    'organization area callback',
)
org = replace_once(
    org,
    '      refreshRevision: _managementRefreshRevision,\n',
    '      refreshRevision: _managementRefreshRevision,\n      initialArea: _managementArea,\n      onAreaChanged: _handleManagementAreaChanged,\n',
    'organization management page wiring',
)
org_path.write_text(org, encoding='utf-8')

contract_path = Path('test/features/organization_navigation_state_contract_test.dart')
contract_path.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Organization workspace owns the selected management area', () {
    final areas = File(
      'lib/features/organization_management/presentation/organization_management_areas.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/organization_management/presentation/organization_management_page.dart',
    ).readAsStringSync();
    final organization = File(
      'lib/features/design_v2/v2_organization_workspace_page.dart',
    ).readAsStringSync();

    expect(areas, contains('enum OrganizationManagementArea'));
    expect(areas, contains('widget.initialArea ?? _initialArea(widget.snapshot)'));
    expect(areas, contains('widget.onAreaChanged?.call(area)'));
    expect(page, contains('final OrganizationManagementArea? initialArea;'));
    expect(organization, contains('OrganizationManagementArea? _managementArea;'));
    expect(organization, contains('initialArea: _managementArea'));
    expect(organization, contains('onAreaChanged: _handleManagementAreaChanged'));
  });
}
""", encoding='utf-8')

doc_path = Path('docs/design/NAVIGATION_STATE_AUDIT.md')
doc = doc_path.read_text(encoding='utf-8')
marker = '\n## Organization management area continuity\n'
if marker not in doc:
    doc += """

## Organization management area continuity

Members / Students / Settings is now explicit Organization workspace navigation state instead of private state owned only by the Management body. The Management body still chooses its existing setup-aware initial area when no area has been established, then reports that resolved area upward. Refresh and Learning / Management round trips therefore preserve the manager's current area without changing Organization authority, teaching responsibility, or persistence semantics.
"""
doc_path.write_text(doc, encoding='utf-8')
