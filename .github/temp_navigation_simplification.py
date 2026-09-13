from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, got {count}')
    return text.replace(old, new, 1)


def replace_all(text: str, old: str, new: str, minimum: int, label: str) -> str:
    count = text.count(old)
    if count < minimum:
        raise SystemExit(f'{label}: expected >= {minimum} matches, got {count}')
    return text.replace(old, new)

root = Path('.')

nav_path = root / 'lib/features/design_v2/v2_workspace_navigation.dart'
nav_path.write_text(
    "enum V2OrganizationSection { learning, management }\n",
    encoding='utf-8',
)

# ---------------------------------------------------------------------------
# Personal shell: Organization is a scope with two desktop sub-destinations.
# Compact keeps Today / Students / Learning and enters Organization from More.
# ---------------------------------------------------------------------------
path = root / 'lib/features/design_v2/v2_workspace_preview.dart'
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    "import 'v2_update_flow.dart';\n",
    "import 'v2_update_flow.dart';\nimport 'v2_workspace_navigation.dart';\n",
    'workspace navigation import',
)
text = replace_once(
    text,
    "typedef V2OrganizationWorkspaceBuilder = Widget Function(\n  BuildContext context,\n  VoidCallback onBackToPersonal,\n);",
    "typedef V2OrganizationWorkspaceBuilder = Widget Function(\n  BuildContext context,\n  VoidCallback onBackToPersonal,\n  V2OrganizationSection section,\n  ValueChanged<V2OrganizationSection> onSectionChanged,\n);",
    'organization builder typedef',
)
text = replace_once(
    text,
    "  V2WorkspaceDestination _lastPersonalDestination =\n      V2WorkspaceDestination.today;\n",
    "  V2WorkspaceDestination _lastPersonalDestination =\n      V2WorkspaceDestination.today;\n  V2OrganizationSection _organizationSection =\n      V2OrganizationSection.learning;\n",
    'organization section state',
)
text = replace_once(
    text,
    "  void _returnFromOrganization() {\n    setState(() => _destination = _lastPersonalDestination);\n  }\n",
    "  void _returnFromOrganization() {\n    setState(() => _destination = _lastPersonalDestination);\n  }\n\n  void _openOrganization(V2OrganizationSection section) {\n    setState(() {\n      if (_destination != V2WorkspaceDestination.organization) {\n        _lastPersonalDestination = _destination;\n      }\n      _organizationSection = section;\n      _destination = V2WorkspaceDestination.organization;\n    });\n  }\n\n  void _changeOrganizationSection(V2OrganizationSection section) {\n    if (_organizationSection == section) return;\n    setState(() => _organizationSection = section);\n  }\n",
    'organization navigation methods',
)
text = replace_once(
    text,
    "          children: [\n            if (widget.onRefresh != null)",
    "          children: [\n            if (widget.organizationPageBuilder != null)\n              ListTile(\n                key: const Key('v2-menu-open-organization'),\n                leading: const Icon(Icons.apartment_outlined),\n                title: const Text('进入机构工作区'),\n                subtitle: const Text('查看机构学情监督与管理'),\n                onTap: () => _afterMenuClose(\n                  menuContext,\n                  () => _openOrganization(V2OrganizationSection.learning),\n                ),\n              ),\n            if (widget.onRefresh != null)",
    'compact organization menu entry',
)
# Remove repeated Compact header entry wiring.
text = replace_all(text, "    this.onOpenOrganization,\n", "", 3, 'remove organization ctor args')
text = replace_all(text, "  final VoidCallback? onOpenOrganization;\n", "", 3, 'remove organization fields')
for block in [
    "                    if (widget.onOpenOrganization != null)\n                      TextButton.icon(\n                        key: const Key('v2-open-organization-scope'),\n                        onPressed: widget.onOpenOrganization,\n                        icon: const Icon(Icons.apartment_outlined, size: 18),\n                        label: const Text('机构'),\n                      ),\n",
    "                  if (onOpenOrganization != null)\n                    TextButton.icon(\n                      key: const Key('v2-open-organization-scope'),\n                      onPressed: onOpenOrganization,\n                      icon: const Icon(Icons.apartment_outlined, size: 18),\n                      label: const Text('机构'),\n                    ),\n",
    "                  if (widget.onOpenOrganization != null)\n                    TextButton.icon(\n                      key: const Key('v2-open-organization-scope'),\n                      onPressed: widget.onOpenOrganization,\n                      icon: const Icon(Icons.apartment_outlined, size: 18),\n                      label: const Text('机构'),\n                    ),\n",
]:
    text = text.replace(block, '')
# Compact no longer creates an Organization header action.
text = re.sub(
    r"\n    final VoidCallback\? onOpenOrganization =\n        widget\.organizationPageBuilder == null\n        \? null\n        : \(\) \{\n            widget\.onDestinationChanged\(V2WorkspaceDestination\.organization\);\n          \};",
    '',
    text,
    count=1,
)
text = text.replace("        onOpenOrganization: onOpenOrganization,\n", '')
# Pass the controlled Organization section through every adaptive shell.
text = text.replace(
    "                  organizationPageBuilder: widget.organizationPageBuilder,\n                  onBackFromOrganization: _returnFromOrganization,",
    "                  organizationPageBuilder: widget.organizationPageBuilder,\n                  organizationSection: _organizationSection,\n                  onOrganizationSelected: _openOrganization,\n                  onOrganizationSectionChanged: _changeOrganizationSection,\n                  onBackFromOrganization: _returnFromOrganization,",
)
# Desktop constructor and fields.
text = text.replace(
    "    required this.organizationPageBuilder,\n    required this.onBackFromOrganization,",
    "    required this.organizationPageBuilder,\n    required this.organizationSection,\n    required this.onOrganizationSelected,\n    required this.onOrganizationSectionChanged,\n    required this.onBackFromOrganization,",
)
text = text.replace(
    "  final V2OrganizationWorkspaceBuilder? organizationPageBuilder;\n  final VoidCallback onBackFromOrganization;",
    "  final V2OrganizationWorkspaceBuilder? organizationPageBuilder;\n  final V2OrganizationSection organizationSection;\n  final ValueChanged<V2OrganizationSection> onOrganizationSelected;\n  final ValueChanged<V2OrganizationSection> onOrganizationSectionChanged;\n  final VoidCallback onBackFromOrganization;",
)
# The above appears in all 3 shells; ensure all received the fields.
if text.count('final V2OrganizationSection organizationSection;') != 3:
    raise SystemExit('adaptive shell organization section fields were not applied to all shells')
# Rail calls.
text = text.replace(
    "                showOrganization: organizationPageBuilder != null,\n",
    "                showOrganization: organizationPageBuilder != null,\n                organizationSection: organizationSection,\n                onOrganizationSelected: onOrganizationSelected,\n",
)
text = text.replace(
    "                      showOrganization: widget.organizationPageBuilder != null,\n",
    "                      showOrganization: widget.organizationPageBuilder != null,\n                      organizationSection: widget.organizationSection,\n                      onOrganizationSelected: widget.onOrganizationSelected,\n",
)
# Organization builder invocations.
text = text.replace(
    "                child: organizationPageBuilder!(\n                  context,\n                  onBackFromOrganization,\n                ),",
    "                child: organizationPageBuilder!(\n                  context,\n                  onBackFromOrganization,\n                  organizationSection,\n                  onOrganizationSectionChanged,\n                ),",
)
text = text.replace(
    "          body = widget.organizationPageBuilder!(\n            context,\n            widget.onBackFromOrganization,\n          );",
    "          body = widget.organizationPageBuilder!(\n            context,\n            widget.onBackFromOrganization,\n            widget.organizationSection,\n            widget.onOrganizationSectionChanged,\n          );",
)
text = text.replace(
    "      body = widget.organizationPageBuilder!(\n        context,\n        widget.onBackFromOrganization,\n      );",
    "      body = widget.organizationPageBuilder!(\n        context,\n        widget.onBackFromOrganization,\n        widget.organizationSection,\n        widget.onOrganizationSectionChanged,\n      );",
)
# Rail API and organization group.
text = replace_once(
    text,
    "    required this.showOrganization,\n    this.expanded = false,",
    "    required this.showOrganization,\n    required this.organizationSection,\n    required this.onOrganizationSelected,\n    this.expanded = false,",
    'rail ctor',
)
text = replace_once(
    text,
    "  final bool showOrganization;\n  final VoidCallback? onRefresh;",
    "  final bool showOrganization;\n  final V2OrganizationSection organizationSection;\n  final ValueChanged<V2OrganizationSection> onOrganizationSelected;\n  final VoidCallback? onRefresh;",
    'rail fields',
)
old_org_rail = """          if (showOrganization) ...[\n            Padding(\n              padding: EdgeInsets.fromLTRB(14, expanded ? 8 : 10, 14, 8),\n              child: Divider(height: 1, color: scheme.outlineVariant),\n            ),\n            if (expanded) const _RailGroupLabel('机构视角'),\n            _RailItem(\n              key: const Key('v2-rail-organization'),\n              icon: _destinationIcon(V2WorkspaceDestination.organization),\n              tooltip: _destinationLabel(V2WorkspaceDestination.organization),\n              selected:\n                  selectedDestination == V2WorkspaceDestination.organization,\n              onTap: () => onSelected(V2WorkspaceDestination.organization),\n              expanded: expanded,\n            ),\n          ],"""
new_org_rail = """          if (showOrganization) ...[\n            Padding(\n              padding: EdgeInsets.fromLTRB(14, expanded ? 8 : 10, 14, 8),\n              child: Divider(height: 1, color: scheme.outlineVariant),\n            ),\n            if (expanded) const _RailGroupLabel('机构'),\n            _RailItem(\n              key: const Key('v2-rail-organization-learning'),\n              icon: Icons.fact_check_outlined,\n              tooltip: '学情监督',\n              selected:\n                  selectedDestination == V2WorkspaceDestination.organization &&\n                  organizationSection == V2OrganizationSection.learning,\n              onTap: () =>\n                  onOrganizationSelected(V2OrganizationSection.learning),\n              expanded: expanded,\n            ),\n            _RailItem(\n              key: const Key('v2-rail-organization-management'),\n              icon: Icons.admin_panel_settings_outlined,\n              tooltip: '管理',\n              selected:\n                  selectedDestination == V2WorkspaceDestination.organization &&\n                  organizationSection == V2OrganizationSection.management,\n              onTap: () =>\n                  onOrganizationSelected(V2OrganizationSection.management),\n              expanded: expanded,\n            ),\n          ],"""
text = replace_once(text, old_org_rail, new_org_rail, 'organization rail group')
path.write_text(text, encoding='utf-8')

# ---------------------------------------------------------------------------
# Loader: bridge outer section state into the stable embedded Organization page.
# ---------------------------------------------------------------------------
path = root / 'lib/features/design_v2/v2_workspace_loader.dart'
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    "import 'v2_workspace_data.dart';\n",
    "import 'v2_workspace_data.dart';\nimport 'v2_workspace_navigation.dart';\n",
    'loader navigation import',
)
text = replace_once(
    text,
    "            ? (context, onBackToPersonal) => V2OrganizationWorkspacePage(\n",
    "            ? (context, onBackToPersonal, section, onSectionChanged) =>\n                V2OrganizationWorkspacePage(\n",
    'loader builder signature',
)
text = replace_once(
    text,
    "                embedded: true,\n                onBackFromRoot: onBackToPersonal,\n",
    "                embedded: true,\n                section: section,\n                onSectionChanged: onSectionChanged,\n                onBackFromRoot: onBackToPersonal,\n",
    'loader section bridge',
)
path.write_text(text, encoding='utf-8')

# ---------------------------------------------------------------------------
# Organization page: controlled section on embedded layouts, lighter header,
# progressive filters, and less repeated responsibility metadata.
# ---------------------------------------------------------------------------
path = root / 'lib/features/design_v2/v2_organization_workspace_page.dart'
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    "import 'v2_workspace_data.dart';\n\nenum _OrganizationSection { learning, management }\n",
    "import 'v2_workspace_data.dart';\nimport 'v2_workspace_navigation.dart';\n",
    'organization navigation import',
)
text = replace_once(
    text,
    "    this.embedded = false,\n    this.onBackFromRoot,",
    "    this.embedded = false,\n    this.section,\n    this.onSectionChanged,\n    this.onBackFromRoot,",
    'organization widget ctor section',
)
text = replace_once(
    text,
    "  final bool embedded;\n  final VoidCallback? onBackFromRoot;",
    "  final bool embedded;\n  final V2OrganizationSection? section;\n  final ValueChanged<V2OrganizationSection>? onSectionChanged;\n  final VoidCallback? onBackFromRoot;",
    'organization widget fields section',
)
text = replace_once(
    text,
    "  final ScrollController _managementScrollController = ScrollController();\n  _OrganizationSection _section = _OrganizationSection.learning;",
    "  final ScrollController _managementScrollController = ScrollController();\n  V2OrganizationSection _section = V2OrganizationSection.learning;",
    'organization section state type',
)
# Add init/didUpdate and one transition method before dispose.
text = replace_once(
    text,
    "  @override\n  void dispose() {",
    "  @override\n  void initState() {\n    super.initState();\n    _section = widget.section ?? V2OrganizationSection.learning;\n    _managementActivated = _section == V2OrganizationSection.management;\n  }\n\n  @override\n  void didUpdateWidget(covariant V2OrganizationWorkspacePage oldWidget) {\n    super.didUpdateWidget(oldWidget);\n    final requested = widget.section;\n    if (requested != null && requested != _section) {\n      _section = requested;\n      if (requested == V2OrganizationSection.management) {\n        _managementActivated = true;\n      }\n    }\n  }\n\n  void _selectSection(V2OrganizationSection section) {\n    if (_section == section) return;\n    setState(() {\n      _section = section;\n      if (section == V2OrganizationSection.management) {\n        _managementActivated = true;\n      }\n    });\n    widget.onSectionChanged?.call(section);\n  }\n\n  @override\n  void dispose() {",
    'organization lifecycle section sync',
)
text = text.replace('_OrganizationSection.', 'V2OrganizationSection.')
text = text.replace('SegmentedButton<_OrganizationSection>', 'SegmentedButton<V2OrganizationSection>')
text = text.replace('ButtonSegment<_OrganizationSection>', 'ButtonSegment<V2OrganizationSection>')
# Back transitions must notify parent section state too.
text = text.replace(
    "      setState(() => _section = V2OrganizationSection.learning);\n      return;",
    "      _selectSection(V2OrganizationSection.learning);\n      return;",
)
text = text.replace(
    "              setState(() => _section = V2OrganizationSection.learning);\n              return;",
    "              _selectSection(V2OrganizationSection.learning);\n              return;",
)
# Replace section switch callback implementation everywhere.
text = re.sub(
    r"onSelectionChanged: \(selection\) \{\n\s+final nextSection = selection\.single;\n\s+setState\(\(\) \{\n\s+_section = nextSection;\n\s+if \(nextSection ==\n\s+V2OrganizationSection\.management\) \{\n\s+_managementActivated = true;\n\s+\}\n\s+\}\);\n\s+\},",
    "onSelectionChanged: (selection) => _selectSection(selection.single),",
    text,
)
# Header: embedded desktops use rail hierarchy, compact keeps a small local switch.
text = replace_once(
    text,
    "                          title: '机构',\n                          meta: _organizationMeta,\n                          description: _section == V2OrganizationSection.learning\n                              ? '从全机构视角查看学生问题、主责与下一步。'\n                              : '维护成员、学生、学科与机构设置。',",
    "                          title: widget.embedded\n                              ? (_section == V2OrganizationSection.learning\n                                    ? '学情监督'\n                                    : '管理')\n                              : '机构',\n                          meta: widget.embedded ? null : _organizationMeta,",
    'organization compact header copy',
)
# Footer only where there is no outer desktop rail; labels clarify supervision.
old_footer = """                          footer: Align(\n                            alignment: Alignment.centerLeft,\n                            child: SegmentedButton<V2OrganizationSection>(\n                              key: const Key('v2-organization-section-switch'),\n                              showSelectedIcon: false,\n                              segments: const [\n                                ButtonSegment<V2OrganizationSection>(\n                                  value: V2OrganizationSection.learning,\n                                  icon: Icon(Icons.fact_check_outlined),\n                                  label: Text('学情'),\n                                ),\n                                ButtonSegment<V2OrganizationSection>(\n                                  value: V2OrganizationSection.management,\n                                  icon: Icon(\n                                    Icons.admin_panel_settings_outlined,\n                                  ),\n                                  label: Text('管理'),\n                                ),\n                              ],\n                              selected: {_section},\n                              onSelectionChanged: (selection) => _selectSection(selection.single),\n                            ),\n                          ),"""
new_footer = """                          footer: widget.embedded && !compact\n                              ? null\n                              : Align(\n                                  alignment: Alignment.centerLeft,\n                                  child: SegmentedButton<V2OrganizationSection>(\n                                    key: const Key(\n                                      'v2-organization-section-switch',\n                                    ),\n                                    showSelectedIcon: false,\n                                    segments: const [\n                                      ButtonSegment<V2OrganizationSection>(\n                                        value: V2OrganizationSection.learning,\n                                        icon: Icon(Icons.fact_check_outlined),\n                                        label: Text('学情监督'),\n                                      ),\n                                      ButtonSegment<V2OrganizationSection>(\n                                        value: V2OrganizationSection.management,\n                                        icon: Icon(\n                                          Icons.admin_panel_settings_outlined,\n                                        ),\n                                        label: Text('管理'),\n                                      ),\n                                    ],\n                                    selected: {_section},\n                                    onSelectionChanged: (selection) =>\n                                        _selectSection(selection.single),\n                                  ),\n                                ),"""
text = replace_once(text, old_footer, new_footer, 'organization header footer')
# Drop recurring explanatory sentence from supervision body.
text = re.sub(
    r"\n\s+const SizedBox\(height: 5\),\n\s+Text\(\n\s+'查看全机构当前问题、主责与下一步；机构操作不会自动改变教师主责。',\n\s+style: [\s\S]*?\n\s+\),",
    '',
    text,
    count=2,
)
# Progressive filter bar helper before expanded workspace.
marker = "  Widget _buildExpandedWorkspace(\n"
filter_helper = """  Widget _filterControls(BuildContext context) {\n    const advanced = <_OrganizationLearningFilter>[\n      _OrganizationLearningFilter.pendingVerification,\n      _OrganizationLearningFilter.overdue,\n      _OrganizationLearningFilter.unassigned,\n    ];\n    final advancedSelected = advanced.contains(_filter);\n    return Wrap(\n      spacing: 8,\n      runSpacing: 8,\n      crossAxisAlignment: WrapCrossAlignment.center,\n      children: [\n        ChoiceChip(\n          key: const Key('v2-organization-filter-all'),\n          label: const Text('全部'),\n          selected: _filter == _OrganizationLearningFilter.all,\n          onSelected: (_) =>\n              setState(() => _filter = _OrganizationLearningFilter.all),\n        ),\n        ChoiceChip(\n          key: const Key('v2-organization-filter-attention'),\n          label: const Text('需关注'),\n          selected: _filter == _OrganizationLearningFilter.attention,\n          onSelected: (_) =>\n              setState(() => _filter = _OrganizationLearningFilter.attention),\n        ),\n        PopupMenuButton<_OrganizationLearningFilter>(\n          key: const Key('v2-organization-filter-more'),\n          tooltip: '更多筛选',\n          initialValue: advancedSelected ? _filter : null,\n          onSelected: (filter) => setState(() => _filter = filter),\n          itemBuilder: (_) => [\n            for (final filter in advanced)\n              PopupMenuItem<_OrganizationLearningFilter>(\n                key: ValueKey<String>(\n                  'v2-organization-filter-${filter.name}',\n                ),\n                value: filter,\n                child: Text(_filterLabel(filter)),\n              ),\n          ],\n          child: Container(\n            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),\n            decoration: BoxDecoration(\n              border: Border.all(\n                color: advancedSelected\n                    ? Theme.of(context).colorScheme.primary\n                    : Theme.of(context).colorScheme.outlineVariant,\n              ),\n              borderRadius: BorderRadius.circular(999),\n            ),\n            child: Row(\n              mainAxisSize: MainAxisSize.min,\n              children: [\n                const Icon(Icons.tune, size: 16),\n                const SizedBox(width: 6),\n                Text(advancedSelected ? _filterLabel(_filter) : '筛选'),\n              ],\n            ),\n          ),\n        ),\n      ],\n    );\n  }\n\n"""
text = replace_once(text, marker, filter_helper + marker, 'filter helper insertion')
# Replace both full five-chip surfaces.
text = re.sub(
    r"Wrap\(\n\s+spacing: 8,\n\s+runSpacing: 8,\n\s+children: \[\n\s+for \(final filter\n\s+in _OrganizationLearningFilter\.values\)\n\s+ChoiceChip\([\s\S]*?\n\s+\],\n\s+\),",
    "_filterControls(context),",
    text,
    count=1,
)
text = re.sub(
    r"SingleChildScrollView\(\n\s+scrollDirection: Axis\.horizontal,\n\s+child: Row\(\n\s+children: \[\n\s+for \(final filter\n\s+in _OrganizationLearningFilter\.values\) \.\.\.\[[\s\S]*?\n\s+\],\n\s+\),\n\s+\),",
    "_filterControls(context),",
    text,
    count=1,
)
# Reduce normal responsibility repetition in expanded selection rows.
text = replace_once(
    text,
    "              const SizedBox(height: 4),\n              Text(\n                responsibilitySummary,\n                maxLines: 2,\n                overflow: TextOverflow.ellipsis,\n                style: theme.textTheme.bodySmall?.copyWith(\n                  color: scheme.onSurfaceVariant,\n                ),\n              ),",
    "              if (responsibilitySummary.contains('未')) ...[\n                const SizedBox(height: 4),\n                Text(\n                  responsibilitySummary,\n                  maxLines: 2,\n                  overflow: TextOverflow.ellipsis,\n                  style: theme.textTheme.bodySmall?.copyWith(\n                    color: scheme.error,\n                    fontWeight: FontWeight.w600,\n                  ),\n                ),\n              ],",
    'selection responsibility exception',
)
# Compact/detail responsibility becomes one normal line; breakdown only for exceptions/mixed leads.
text = replace_once(
    text,
    "    final closedItems = items\n        .where((item) => item.closed)\n        .toList(growable: false);\n\n    return ListView(",
    "    final closedItems = items\n        .where((item) => item.closed)\n        .toList(growable: false);\n    final leadLabels = profiles.map(leadLabelForProfile).toSet();\n    final showResponsibilityBreakdown =\n        leadLabels.length > 1 || leadLabels.contains('未设置主责');\n\n    return ListView(",
    'detail responsibility state',
)
old_resp = """        const SizedBox(height: 18),\n        Text('教学责任', style: theme.textTheme.labelLarge),\n        const SizedBox(height: 6),\n        Text(responsibilitySummary, style: theme.textTheme.bodyMedium),\n        if (profiles.isNotEmpty) ...[\n          const SizedBox(height: 10),\n          Wrap(\n            spacing: 18,\n            runSpacing: 6,\n            children: [\n              for (final profile in profiles)\n                Text(\n                  '${profile.subject} · ${leadLabelForProfile(profile)}',\n                  style: theme.textTheme.bodySmall?.copyWith(\n                    color: scheme.onSurfaceVariant,\n                  ),\n                ),\n            ],\n          ),\n        ],"""
new_resp = """        const SizedBox(height: 14),\n        Text(\n          '主责：$responsibilitySummary',\n          style: theme.textTheme.bodySmall?.copyWith(\n            color: responsibilitySummary.contains('未')\n                ? scheme.error\n                : scheme.onSurfaceVariant,\n            fontWeight: responsibilitySummary.contains('未')\n                ? FontWeight.w600\n                : null,\n          ),\n        ),\n        if (showResponsibilityBreakdown && profiles.isNotEmpty) ...[\n          const SizedBox(height: 8),\n          Wrap(\n            spacing: 16,\n            runSpacing: 5,\n            children: [\n              for (final profile in profiles)\n                Text(\n                  '${profile.subject} · ${leadLabelForProfile(profile)}',\n                  style: theme.textTheme.bodySmall?.copyWith(\n                    color: leadLabelForProfile(profile) == '未设置主责'\n                        ? scheme.error\n                        : scheme.onSurfaceVariant,\n                  ),\n                ),\n            ],\n          ),\n        ],"""
text = replace_once(text, old_resp, new_resp, 'detail responsibility density')
path.write_text(text, encoding='utf-8')

# ---------------------------------------------------------------------------
# Tests: update fake builder signatures and the navigation contracts that are
# intentionally changing. Other stale expectations are left for CI to expose.
# ---------------------------------------------------------------------------
for p in (root / 'test').rglob('*.dart'):
    t = p.read_text(encoding='utf-8')
    t = t.replace(
        '(context, onBackToPersonal) =>',
        '(context, onBackToPersonal, section, onSectionChanged) =>',
    )
    p.write_text(t, encoding='utf-8')

# Typed navigation expectations.
p = root / 'test/features/v2_typed_organization_navigation_test.dart'
t = p.read_text(encoding='utf-8')
t = t.replace("expect(find.widgetWithText(TextButton, '机构'), findsOneWidget);", "expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);")
t = t.replace("await tester.tap(find.byKey(const Key('v2-open-organization-scope')));", "await tester.tap(find.byKey(const Key('v2-compact-more')));\n      await tester.pumpAndSettle();\n      await tester.tap(find.byKey(const Key('v2-menu-open-organization')));")
t = t.replace("await tester.tap(find.byTooltip('机构'));", "await tester.tap(find.byTooltip('学情监督'));")
t = t.replace("find.byKey(const Key('v2-rail-organization'))", "find.byKey(const Key('v2-rail-organization-learning'))")
t = t.replace("expect(find.widgetWithText(TextButton, '机构'), findsOneWidget);\n    expect(find.byType(NavigationBar), findsOneWidget);", "expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);\n    expect(find.byType(NavigationBar), findsOneWidget);\n    await tester.tap(find.byKey(const Key('v2-compact-more')));\n    await tester.pumpAndSettle();\n    expect(find.byKey(const Key('v2-menu-open-organization')), findsOneWidget);")
p.write_text(t, encoding='utf-8')

# Page rhythm: compact headers should be quiet, Organization lives in More.
p = root / 'test/features/v2_page_rhythm_test.dart'
t = p.read_text(encoding='utf-8')
t = t.replace(
    "      expect(\n        find.byKey(const Key('v2-open-organization-scope')),\n        findsOneWidget,\n      );",
    "      expect(\n        find.byKey(const Key('v2-open-organization-scope')),\n        findsNothing,\n      );",
)
t = t.replace(
    "      expect(\n        find.byKey(const Key('v2-open-organization-scope')),\n        findsOneWidget,\n      );",
    "      expect(\n        find.byKey(const Key('v2-open-organization-scope')),\n        findsNothing,\n      );",
)
t = t.replace(
    "      expect(\n        find.byKey(const Key('v2-open-organization-scope')),\n        findsOneWidget,\n      );",
    "      expect(\n        find.byKey(const Key('v2-open-organization-scope')),\n        findsNothing,\n      );",
)
t = t.replace(
    "    expect(workspace, contains(\"Key('v2-learning-page-header')\"));",
    "    expect(workspace, contains(\"Key('v2-learning-page-header')\"));\n    expect(workspace, contains(\"Key('v2-menu-open-organization')\"));\n    expect(workspace, isNot(contains(\"Key('v2-open-organization-scope')\")));",
)
p.write_text(t, encoding='utf-8')

# Adaptive + organization tests use the new desktop labels and progressive filter menu.
for name in ['v2_adaptive_workspace_test.dart', 'v2_organization_workspace_test.dart']:
    p = root / 'test/features' / name
    t = p.read_text(encoding='utf-8')
    t = t.replace("find.byTooltip('机构')", "find.byTooltip('学情监督')")
    t = t.replace("find.byKey(const Key('v2-rail-organization'))", "find.byKey(const Key('v2-rail-organization-learning'))")
    p.write_text(t, encoding='utf-8')

p = root / 'test/features/v2_organization_workspace_test.dart'
t = p.read_text(encoding='utf-8')
t = t.replace("      expect(find.textContaining('机构操作不会自动改变教师主责'), findsOneWidget);\n", "      expect(find.textContaining('机构操作不会自动改变教师主责'), findsNothing);\n")
t = t.replace(
    "    await tester.tap(\n      find.byKey(const Key('v2-organization-filter-unassigned')),\n    );",
    "    await tester.tap(find.byKey(const Key('v2-organization-filter-more')));\n    await tester.pumpAndSettle();\n    await tester.tap(\n      find.byKey(const Key('v2-organization-filter-unassigned')),\n    );",
)
t = t.replace(
    "    await tester.tap(find.byKey(const Key('v2-organization-filter-overdue')));",
    "    await tester.tap(find.byKey(const Key('v2-organization-filter-more')));\n    await tester.pumpAndSettle();\n    await tester.tap(find.byKey(const Key('v2-organization-filter-overdue')));",
)
p.write_text(t, encoding='utf-8')

# Contract docs: document the intentional hierarchy change.
p = root / 'docs/design/NAVIGATION_STATE_AUDIT.md'
t = p.read_text(encoding='utf-8')
t += """\n\n## Navigation simplification after v0.3.10\n\nOrganization is a work scope, not a fourth Personal page. Personal continues to own Today / Students / Learning. On Compact, managers enter Organization from the More menu instead of repeating an Organization action in every page header. On Medium/Expanded, the rail exposes an Organization group with Learning supervision and Management as sibling sub-destinations. The embedded Organization header therefore does not repeat the desktop section switch.\n\nThe existing cross-scope continuity contract remains unchanged: returning from Organization restores the Personal destination and any still-valid student/case drill-down state.\n"""
p.write_text(t, encoding='utf-8')

p = root / 'docs/design/PAGE_RHYTHM_AUDIT.md'
t = p.read_text(encoding='utf-8')
t += """\n\n## Reduced scope chrome after v0.3.10\n\nCompact Personal headers no longer repeat a visible Organization button on Today, Students, and Learning. Managers use the first item in More to enter Organization. Medium/Expanded express Organization hierarchy in the rail. Embedded Organization pages use a compact title/action header; metadata and the local Learning/Management switch are not repeated when the outer rail already carries that context.\n"""
p.write_text(t, encoding='utf-8')

print('navigation simplification patch prepared')
