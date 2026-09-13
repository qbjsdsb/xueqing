from pathlib import Path
import re


def once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'missing {label}')
    return text.replace(old, new, 1)

# Workspace shell: thread Organization management-area state to the desktop rail
# and into the embedded Organization workspace.
path = Path('lib/features/design_v2/v2_workspace_preview.dart')
text = path.read_text(encoding='utf-8')
if "../organization_management/presentation/organization_management_page.dart" not in text:
    text = once(
        text,
        "import '../../cloud/progressive_case_repository.dart';\n",
        "import '../../cloud/progressive_case_repository.dart';\nimport '../organization_management/presentation/organization_management_page.dart';\n",
        'organization management import',
    )
text = once(
    text,
    "  V2OrganizationSection section,\n  ValueChanged<V2OrganizationSection> onSectionChanged,\n);",
    "  V2OrganizationSection section,\n  ValueChanged<V2OrganizationSection> onSectionChanged,\n  OrganizationManagementArea? managementArea,\n  ValueChanged<OrganizationManagementArea> onManagementAreaChanged,\n);",
    'organization builder typedef',
)
text = once(
    text,
    "  V2OrganizationSection _organizationSection = V2OrganizationSection.learning;\n",
    "  V2OrganizationSection _organizationSection = V2OrganizationSection.learning;\n  OrganizationManagementArea? _organizationManagementArea;\n",
    'workspace management-area state',
)
text = once(
    text,
    "  void _changeOrganizationSection(V2OrganizationSection section) {\n    if (_organizationSection == section) return;\n    setState(() => _organizationSection = section);\n  }\n",
    "  void _changeOrganizationSection(V2OrganizationSection section) {\n    if (_organizationSection == section) return;\n    setState(() => _organizationSection = section);\n  }\n\n  void _openOrganizationManagementArea(OrganizationManagementArea area) {\n    setState(() {\n      if (_destination != V2WorkspaceDestination.organization) {\n        _lastPersonalDestination = _destination;\n      }\n      _organizationSection = V2OrganizationSection.management;\n      _organizationManagementArea = area;\n      _destination = V2WorkspaceDestination.organization;\n    });\n  }\n",
    'workspace management-area change',
)
# Shell construction from V2WorkspacePreviewState.
text = text.replace(
    "                    organizationSection: _organizationSection,\n",
    "                    organizationSection: _organizationSection,\n                    organizationManagementArea: _organizationManagementArea,\n                    onOrganizationManagementAreaChanged:\n                        _openOrganizationManagementArea,\n",
)
text = text.replace(
    "                  organizationSection: _organizationSection,\n",
    "                  organizationSection: _organizationSection,\n                  organizationManagementArea: _organizationManagementArea,\n                  onOrganizationManagementAreaChanged:\n                      _openOrganizationManagementArea,\n",
)
# Constructor declarations for Desktop / Medium / Compact.
text = text.replace(
    "    required this.organizationSection,\n    required this.onOrganizationSelected,\n",
    "    required this.organizationSection,\n    required this.organizationManagementArea,\n    required this.onOrganizationManagementAreaChanged,\n    required this.onOrganizationSelected,\n",
)
text = text.replace(
    "  final V2OrganizationSection organizationSection;\n  final ValueChanged<V2OrganizationSection> onOrganizationSelected;\n",
    "  final V2OrganizationSection organizationSection;\n  final OrganizationManagementArea? organizationManagementArea;\n  final ValueChanged<OrganizationManagementArea>\n  onOrganizationManagementAreaChanged;\n  final ValueChanged<V2OrganizationSection> onOrganizationSelected;\n",
)
# Rail calls in Desktop / Medium.
text = text.replace(
    "                organizationSection: organizationSection,\n                onOrganizationSelected: onOrganizationSelected,\n",
    "                organizationSection: organizationSection,\n                organizationManagementArea: organizationManagementArea,\n                onOrganizationManagementAreaChanged:\n                    onOrganizationManagementAreaChanged,\n                onOrganizationSelected: onOrganizationSelected,\n",
)
text = text.replace(
    "                      organizationSection: widget.organizationSection,\n                      onOrganizationSelected: widget.onOrganizationSelected,\n",
    "                      organizationSection: widget.organizationSection,\n                      organizationManagementArea:\n                          widget.organizationManagementArea,\n                      onOrganizationManagementAreaChanged:\n                          widget.onOrganizationManagementAreaChanged,\n                      onOrganizationSelected: widget.onOrganizationSelected,\n",
)
# Embedded organization builder calls in all adaptive shells.
text = text.replace(
    "        widget.organizationSection,\n        widget.onOrganizationSectionChanged,\n      );",
    "        widget.organizationSection,\n        widget.onOrganizationSectionChanged,\n        widget.organizationManagementArea,\n        widget.onOrganizationManagementAreaChanged,\n      );",
)
text = text.replace(
    "                  organizationSection,\n                  onOrganizationSectionChanged,\n                ),",
    "                  organizationSection,\n                  onOrganizationSectionChanged,\n                  organizationManagementArea,\n                  onOrganizationManagementAreaChanged,\n                ),",
)
text = text.replace(
    "            widget.organizationSection,\n            widget.onOrganizationSectionChanged,\n          );",
    "            widget.organizationSection,\n            widget.onOrganizationSectionChanged,\n            widget.organizationManagementArea,\n            widget.onOrganizationManagementAreaChanged,\n          );",
)
# Wider desktop sidebar.
text = text.replace('width: expandedRail ? 132 : 72,', 'width: expandedRail ? 192 : 72,')

rail_pattern = re.compile(
    r'class _NavigationRail extends StatelessWidget \{.*?\n\}\n\nclass _RailGroupLabel',
    re.S,
)
rail = r'''class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.selectedDestination,
    required this.onSelected,
    required this.onSettings,
    required this.refreshing,
    required this.showOrganization,
    required this.organizationSection,
    required this.organizationManagementArea,
    required this.onOrganizationSelected,
    required this.onOrganizationManagementAreaChanged,
    this.expanded = false,
    this.onRefresh,
    this.onManage,
  });

  final V2WorkspaceDestination selectedDestination;
  final bool expanded;
  final ValueChanged<V2WorkspaceDestination> onSelected;
  final bool showOrganization;
  final V2OrganizationSection organizationSection;
  final OrganizationManagementArea? organizationManagementArea;
  final ValueChanged<V2OrganizationSection> onOrganizationSelected;
  final ValueChanged<OrganizationManagementArea>
  onOrganizationManagementAreaChanged;
  final VoidCallback? onRefresh;
  final bool refreshing;
  final VoidCallback? onManage;
  final VoidCallback onSettings;

  bool _organizationAreaSelected(OrganizationManagementArea area) =>
      selectedDestination == V2WorkspaceDestination.organization &&
      organizationSection == V2OrganizationSection.management &&
      organizationManagementArea == area;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Column(
        children: [
          const SizedBox(height: 18),
          Text(
            '学情',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  if (showOrganization && expanded)
                    const _RailGroupLabel('我的教学'),
                  for (final destination in const <V2WorkspaceDestination>[
                    V2WorkspaceDestination.today,
                    V2WorkspaceDestination.students,
                    V2WorkspaceDestination.learning,
                  ])
                    _RailItem(
                      icon: _destinationIcon(destination),
                      tooltip: destination == V2WorkspaceDestination.students
                          ? '我的学生'
                          : _destinationLabel(destination),
                      label: _destinationLabel(destination),
                      selected: selectedDestination == destination,
                      onTap: () => onSelected(destination),
                      expanded: expanded,
                    ),
                  if (showOrganization) ...[
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        expanded ? 10 : 12,
                        14,
                        8,
                      ),
                      child: Divider(height: 1, color: scheme.outlineVariant),
                    ),
                    if (expanded) const _RailGroupLabel('机构'),
                    _RailItem(
                      key: const Key('v2-rail-organization-learning'),
                      icon: Icons.fact_check_outlined,
                      tooltip: '机构学情监督',
                      label: '学情监督',
                      selected:
                          selectedDestination ==
                              V2WorkspaceDestination.organization &&
                          organizationSection == V2OrganizationSection.learning,
                      onTap: () => onOrganizationSelected(
                        V2OrganizationSection.learning,
                      ),
                      expanded: expanded,
                    ),
                    _RailItem(
                      key: const Key('v2-rail-organization-people'),
                      icon: Icons.people_outline,
                      tooltip: '机构成员',
                      label: '成员',
                      selected: _organizationAreaSelected(
                        OrganizationManagementArea.people,
                      ),
                      onTap: () => onOrganizationManagementAreaChanged(
                        OrganizationManagementArea.people,
                      ),
                      expanded: expanded,
                    ),
                    _RailItem(
                      key: const Key('v2-rail-organization-students'),
                      icon: Icons.school_outlined,
                      tooltip: '机构学生',
                      label: '学生',
                      selected: _organizationAreaSelected(
                        OrganizationManagementArea.students,
                      ),
                      onTap: () => onOrganizationManagementAreaChanged(
                        OrganizationManagementArea.students,
                      ),
                      expanded: expanded,
                    ),
                    _RailItem(
                      key: const Key('v2-rail-organization-settings'),
                      icon: Icons.tune_outlined,
                      tooltip: '机构设置',
                      label: '设置',
                      selected: _organizationAreaSelected(
                        OrganizationManagementArea.settings,
                      ),
                      onTap: () => onOrganizationManagementAreaChanged(
                        OrganizationManagementArea.settings,
                      ),
                      expanded: expanded,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: Divider(height: 1, color: scheme.outlineVariant),
          ),
          if (onRefresh != null)
            _RailItem(
              key: const Key('v2-workspace-refresh'),
              icon: Icons.refresh_outlined,
              tooltip: refreshing ? '正在刷新' : '刷新学情',
              onTap: refreshing ? null : onRefresh,
              expanded: expanded,
            ),
          if (onManage != null)
            _RailItem(
              icon: Icons.admin_panel_settings_outlined,
              tooltip: '机构管理',
              label: '管理',
              onTap: onManage,
              expanded: expanded,
            ),
          _RailItem(
            key: const Key('v2-workspace-more'),
            icon: Icons.more_horiz,
            tooltip: '更多',
            onTap: onSettings,
            expanded: expanded,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _RailGroupLabel'''
text, count = rail_pattern.subn(lambda _: rail, text, count=1)
if count != 1:
    raise SystemExit(f'rail block replacement count={count}')

item_pattern = re.compile(
    r'class _RailItem extends StatelessWidget \{.*?\n\}\n\nclass _StudentListPane',
    re.S,
)
item = r'''class _RailItem extends StatelessWidget {
  const _RailItem({
    super.key,
    required this.icon,
    required this.tooltip,
    this.label,
    this.selected = false,
    this.expanded = false,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final String? label;
  final bool selected;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    final displayLabel = label ?? tooltip;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      child: Semantics(
        label: tooltip,
        button: true,
        selected: selected,
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: selected ? scheme.surfaceContainerHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: SizedBox(
                width: expanded ? 168 : 48,
                height: expanded ? 44 : 48,
                child: Row(
                  children: [
                    SizedBox(
                      width: 3,
                      height: 22,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: selected ? scheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (expanded) const SizedBox(width: 10) else const Spacer(),
                    Icon(icon, size: 20, color: foreground),
                    if (expanded) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          displayLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: foreground,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ] else
                      const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentListPane'''
text, count = item_pattern.subn(lambda _: item, text, count=1)
if count != 1:
    raise SystemExit(f'rail item replacement count={count}')
path.write_text(text, encoding='utf-8')

# Loader builder signature and Organization page wiring.
path = Path('lib/features/design_v2/v2_workspace_loader.dart')
text = path.read_text(encoding='utf-8')
text = text.replace(
    '? (context, onBackToPersonal, section, onSectionChanged) =>',
    '? (\n                  context,\n                  onBackToPersonal,\n                  section,\n                  onSectionChanged,\n                  managementArea,\n                  onManagementAreaChanged,\n                ) =>',
)
text = text.replace(
    '                    section: section,\n                    onSectionChanged: onSectionChanged,\n',
    '                    section: section,\n                    onSectionChanged: onSectionChanged,\n                    managementArea: managementArea,\n                    onManagementAreaChanged: onManagementAreaChanged,\n',
)
path.write_text(text, encoding='utf-8')

# Organization workspace becomes controllable by the outer workspace while still
# preserving the B-stage setup-aware fallback for Compact entry.
path = Path('lib/features/design_v2/v2_organization_workspace_page.dart')
text = path.read_text(encoding='utf-8')
text = once(
    text,
    '    this.onSectionChanged,\n    this.onBackFromRoot,\n',
    '    this.onSectionChanged,\n    this.managementArea,\n    this.onManagementAreaChanged,\n    this.onBackFromRoot,\n',
    'organization page constructor area',
)
text = once(
    text,
    '  final ValueChanged<V2OrganizationSection>? onSectionChanged;\n  final VoidCallback? onBackFromRoot;\n',
    '  final ValueChanged<V2OrganizationSection>? onSectionChanged;\n  final OrganizationManagementArea? managementArea;\n  final ValueChanged<OrganizationManagementArea>? onManagementAreaChanged;\n  final VoidCallback? onBackFromRoot;\n',
    'organization page area fields',
)
text = once(
    text,
    '    _section = widget.section ?? V2OrganizationSection.learning;\n    _managementActivated = _section == V2OrganizationSection.management;\n',
    '    _section = widget.section ?? V2OrganizationSection.learning;\n    _managementArea = widget.managementArea;\n    _managementActivated = _section == V2OrganizationSection.management;\n',
    'organization init area',
)
text = once(
    text,
    '    final requested = widget.section;\n',
    '    final requestedArea = widget.managementArea;\n    if (requestedArea != null && requestedArea != _managementArea) {\n      _managementArea = requestedArea;\n    }\n    final requested = widget.section;\n',
    'organization update area',
)
text = once(
    text,
    '    setState(() => _managementArea = area);\n  }\n',
    '    setState(() => _managementArea = area);\n    widget.onManagementAreaChanged?.call(area);\n  }\n',
    'organization area propagation',
)
text = once(
    text,
    '  Widget _managementContent() {\n',
    '  String get _embeddedSectionTitle {\n    if (_section == V2OrganizationSection.learning) return \'学情监督\';\n    return switch (_managementArea) {\n      OrganizationManagementArea.people => \'成员\',\n      OrganizationManagementArea.students => \'学生\',\n      OrganizationManagementArea.settings => \'设置\',\n      null => \'管理\',\n    };\n  }\n\n  Widget _managementContent({required bool showAreaSwitcher}) {\n',
    'management content signature',
)
text = once(
    text,
    '      onAreaChanged: _handleManagementAreaChanged,\n',
    '      onAreaChanged: _handleManagementAreaChanged,\n      showAreaSwitcher: showAreaSwitcher,\n',
    'management switcher flag',
)
text = text.replace(
    "                          title: widget.embedded\n                              ? (_section == V2OrganizationSection.learning\n                                    ? '学情监督'\n                                    : '管理')\n                              : '机构',",
    "                          title: widget.embedded\n                              ? _embeddedSectionTitle\n                              : '机构',",
)
text = text.replace('_managementContent())', '_managementContent(showAreaSwitcher: compact))')
path.write_text(text, encoding='utf-8')

# Management presentation: allow desktop Organization to hide the duplicate
# Members / Students / Settings switch while Compact retains it.
path = Path('lib/features/organization_management/presentation/organization_management_page.dart')
text = path.read_text(encoding='utf-8')
text = once(
    text,
    '    this.onAreaChanged,\n    super.key,\n',
    '    this.onAreaChanged,\n    this.showAreaSwitcher = true,\n    super.key,\n',
    'management show switcher constructor',
)
text = once(
    text,
    '  final ValueChanged<OrganizationManagementArea>? onAreaChanged;\n',
    '  final ValueChanged<OrganizationManagementArea>? onAreaChanged;\n  final bool showAreaSwitcher;\n',
    'management show switcher field',
)
text = once(
    text,
    '                              onAreaChanged: widget.onAreaChanged,\n',
    '                              onAreaChanged: widget.onAreaChanged,\n                              showAreaSwitcher: widget.showAreaSwitcher,\n',
    'management overview show switcher',
)
path.write_text(text, encoding='utf-8')

path = Path('lib/features/organization_management/presentation/organization_management_areas.dart')
text = path.read_text(encoding='utf-8')
text = once(
    text,
    '    this.onAreaChanged,\n    this.onProvisionInvitation,\n',
    '    this.onAreaChanged,\n    this.showAreaSwitcher = true,\n    this.onProvisionInvitation,\n',
    'overview show switcher constructor',
)
text = once(
    text,
    '  final ValueChanged<OrganizationManagementArea>? onAreaChanged;\n  final VoidCallback? onOpenCaseTypes;\n',
    '  final ValueChanged<OrganizationManagementArea>? onAreaChanged;\n  final bool showAreaSwitcher;\n  final VoidCallback? onOpenCaseTypes;\n',
    'overview show switcher field',
)
text = once(
    text,
    '          onExport:\n',
    '          showAreaSwitcher: widget.showAreaSwitcher,\n          onExport:\n',
    'toolbar switcher flag',
)
path.write_text(text, encoding='utf-8')

path = Path('lib/features/organization_management/presentation/organization_management_layout.dart')
text = path.read_text(encoding='utf-8')
text = once(
    text,
    '    required this.busy,\n    this.onExport,\n',
    '    required this.busy,\n    this.showAreaSwitcher = true,\n    this.onExport,\n',
    'toolbar constructor flag',
)
text = once(
    text,
    '  final bool busy;\n  final VoidCallback? onExport;\n',
    '  final bool busy;\n  final bool showAreaSwitcher;\n  final VoidCallback? onExport;\n',
    'toolbar flag field',
)
old = '''        final switcher = _ManagementAreaSwitcher(
          selectedArea: selectedArea,
          onChanged: onChanged,
        );
        if (onExport == null) return switcher;
'''
new = '''        final Widget? switcher = showAreaSwitcher
            ? _ManagementAreaSwitcher(
                selectedArea: selectedArea,
                onChanged: onChanged,
              )
            : null;
        if (onExport == null) return switcher ?? const SizedBox.shrink();
'''
text = once(text, old, new, 'toolbar optional switcher')
text = once(
    text,
    '        return Row(\n          crossAxisAlignment: CrossAxisAlignment.center,\n          children: [\n            Expanded(child: switcher),\n',
    '        if (switcher == null) {\n          return Align(alignment: Alignment.centerRight, child: exportAction);\n        }\n        return Row(\n          crossAxisAlignment: CrossAxisAlignment.center,\n          children: [\n            Expanded(child: switcher),\n',
    'toolbar export-only layout',
)
path.write_text(text, encoding='utf-8')

# Source-level contract for the desktop projection; behavior remains covered by
# the existing workspace/management tests and the full suite.
Path('test/features/windows_organization_navigation_contract_test.dart').write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows Organization rail exposes direct peer destinations', () {
    final workspace = File(
      'lib/features/design_v2/v2_workspace_preview.dart',
    ).readAsStringSync();
    final organization = File(
      'lib/features/design_v2/v2_organization_workspace_page.dart',
    ).readAsStringSync();

    expect(workspace, contains("Key('v2-rail-organization-people')"));
    expect(workspace, contains("Key('v2-rail-organization-students')"));
    expect(workspace, contains("Key('v2-rail-organization-settings')"));
    expect(workspace, contains("Key('v2-workspace-more')"));
    expect(workspace, contains('width: expandedRail ? 192 : 72'));
    expect(workspace, contains('SingleChildScrollView('));
    expect(organization, contains('showAreaSwitcher: showAreaSwitcher'));
    expect(organization, contains('_embeddedSectionTitle'));
  });
}
""", encoding='utf-8')
