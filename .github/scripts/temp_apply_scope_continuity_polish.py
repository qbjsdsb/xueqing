from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one anchor, found {count}\nANCHOR:\n{old}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


workspace = "lib/features/design_v2/v2_workspace_preview.dart"

replace_once(
    workspace,
    "  V2WorkspaceDestination _destination = V2WorkspaceDestination.today;\n  V2Student? _selectedStudent;",
    "  V2WorkspaceDestination _destination = V2WorkspaceDestination.today;\n  V2WorkspaceDestination _lastPersonalDestination =\n      V2WorkspaceDestination.today;\n  V2Student? _selectedStudent;",
)

replace_once(
    workspace,
    "      _destination = V2WorkspaceDestination.today;\n      _showCase = false;\n      _showStudentDetail = false;",
    "      _destination = V2WorkspaceDestination.today;\n      _lastPersonalDestination = V2WorkspaceDestination.today;\n      _showCase = false;\n      _showStudentDetail = false;",
)

replace_once(
    workspace,
    "  void _changeDestination(V2WorkspaceDestination value) {\n    setState(() {\n      _destination = value;\n      _showCase = false;\n      if (value != V2WorkspaceDestination.students) {\n        _showStudentDetail = false;\n      }\n    });\n  }\n",
    "  void _changeDestination(V2WorkspaceDestination value) {\n    setState(() {\n      if (value == V2WorkspaceDestination.organization) {\n        if (_destination != V2WorkspaceDestination.organization) {\n          _lastPersonalDestination = _destination;\n        }\n        _destination = value;\n        return;\n      }\n\n      _lastPersonalDestination = value;\n      _destination = value;\n      _showCase = false;\n      if (value != V2WorkspaceDestination.students) {\n        _showStudentDetail = false;\n      }\n    });\n  }\n\n  void _returnFromOrganization() {\n    setState(() => _destination = _lastPersonalDestination);\n  }\n",
)

# Parent -> adaptive shell callbacks.
for old, new in [
    (
        "                    organizationPageBuilder: widget.organizationPageBuilder,\n                    onOpenMore: () => _showWorkspaceMenu(context),",
        "                    organizationPageBuilder: widget.organizationPageBuilder,\n                    onBackFromOrganization: _returnFromOrganization,\n                    onOpenMore: () => _showWorkspaceMenu(context),",
    ),
    (
        "                    organizationPageBuilder: widget.organizationPageBuilder,\n                    onRefresh: widget.onRefresh == null",
        "                    organizationPageBuilder: widget.organizationPageBuilder,\n                    onBackFromOrganization: _returnFromOrganization,\n                    onRefresh: widget.onRefresh == null",
    ),
]:
    # The second anchor appears twice (Medium + Desktop), so handle separately below.
    if old.count("onRefresh") == 0:
        replace_once(workspace, old, new)

file = Path(workspace)
text = file.read_text(encoding="utf-8")
old = "                    organizationPageBuilder: widget.organizationPageBuilder,\n                    onRefresh: widget.onRefresh == null"
new = "                    organizationPageBuilder: widget.organizationPageBuilder,\n                    onBackFromOrganization: _returnFromOrganization,\n                    onRefresh: widget.onRefresh == null"
if text.count(old) != 2:
    raise SystemExit(f"{workspace}: expected two adaptive onRefresh anchors, found {text.count(old)}")
text = text.replace(old, new)
file.write_text(text, encoding="utf-8")

# Desktop contract + callback.
replace_once(
    workspace,
    "    required this.organizationPageBuilder,\n    required this.onSettings,",
    "    required this.organizationPageBuilder,\n    required this.onBackFromOrganization,\n    required this.onSettings,",
)
replace_once(
    workspace,
    "  final V2OrganizationWorkspaceBuilder? organizationPageBuilder;\n  final VoidCallback? onRefresh;",
    "  final V2OrganizationWorkspaceBuilder? organizationPageBuilder;\n  final VoidCallback onBackFromOrganization;\n  final VoidCallback? onRefresh;",
)
replace_once(
    workspace,
    "                child: organizationPageBuilder!(\n                  context,\n                  () => onDestinationChanged(V2WorkspaceDestination.today),\n                ),",
    "                child: organizationPageBuilder!(\n                  context,\n                  onBackFromOrganization,\n                ),",
)

# Medium contract + callback. Anchors are now distinct after Desktop replacement.
replace_once(
    workspace,
    "    required this.organizationPageBuilder,\n    required this.onSettings,\n    required this.refreshing,\n    this.onRefresh,\n    this.onManage,\n  });\n\n  final V2WorkspaceDestination destination;",
    "    required this.organizationPageBuilder,\n    required this.onBackFromOrganization,\n    required this.onSettings,\n    required this.refreshing,\n    this.onRefresh,\n    this.onManage,\n  });\n\n  final V2WorkspaceDestination destination;",
)
# The medium final-fields organizationPageBuilder is the remaining occurrence.
replace_once(
    workspace,
    "  final V2OrganizationWorkspaceBuilder? organizationPageBuilder;\n  final VoidCallback? onRefresh;\n  final bool refreshing;\n  final VoidCallback? onManage;",
    "  final V2OrganizationWorkspaceBuilder? organizationPageBuilder;\n  final VoidCallback onBackFromOrganization;\n  final VoidCallback? onRefresh;\n  final bool refreshing;\n  final VoidCallback? onManage;",
)
replace_once(
    workspace,
    "        if (widget.showCase && widget.selectedCase != null) {",
    "        if (widget.destination == V2WorkspaceDestination.students &&\n            widget.showCase &&\n            widget.selectedCase != null) {",
)
replace_once(
    workspace,
    "          body = widget.organizationPageBuilder!(context, () {\n            widget.onDestinationChanged(V2WorkspaceDestination.today);\n          });",
    "          body = widget.organizationPageBuilder!(\n            context,\n            widget.onBackFromOrganization,\n          );",
)
replace_once(
    workspace,
    "        final hasInternalHistory = widget.showCase || widget.showStudentDetail;",
    "        final hasInternalHistory =\n            widget.destination == V2WorkspaceDestination.students &&\n            (widget.showCase || widget.showStudentDetail);",
)

# Compact contract + callback.
replace_once(
    workspace,
    "    required this.organizationPageBuilder,\n    required this.onOpenMore,\n  });",
    "    required this.organizationPageBuilder,\n    required this.onBackFromOrganization,\n    required this.onOpenMore,\n  });",
)
replace_once(
    workspace,
    "  final V2OrganizationWorkspaceBuilder? organizationPageBuilder;\n  final VoidCallback? onOpenMore;",
    "  final V2OrganizationWorkspaceBuilder? organizationPageBuilder;\n  final VoidCallback onBackFromOrganization;\n  final VoidCallback? onOpenMore;",
)
replace_once(
    workspace,
    "    if (widget.showCase && widget.selectedCase != null) {",
    "    if (widget.destination == V2WorkspaceDestination.students &&\n        widget.showCase &&\n        widget.selectedCase != null) {",
)
replace_once(
    workspace,
    "      body = widget.organizationPageBuilder!(context, () {\n        widget.onDestinationChanged(V2WorkspaceDestination.today);\n      });",
    "      body = widget.organizationPageBuilder!(\n        context,\n        widget.onBackFromOrganization,\n      );",
)
replace_once(
    workspace,
    "    final hasInternalHistory = widget.showCase || widget.showStudentDetail;",
    "    final hasInternalHistory =\n        widget.destination == V2WorkspaceDestination.students &&\n        (widget.showCase || widget.showStudentDetail);",
)

# Make compact touch entry discoverable without restoring the old permanent scope strip.
icon_action = """                    if (widget.onOpenOrganization != null)\n                      IconButton(\n                        key: const Key('v2-open-organization-scope'),\n                        tooltip: '进入机构视角',\n                        onPressed: widget.onOpenOrganization,\n                        icon: const Icon(Icons.apartment_outlined),\n                      ),"""
text_action = """                    if (widget.onOpenOrganization != null)\n                      TextButton.icon(\n                        key: const Key('v2-open-organization-scope'),\n                        onPressed: widget.onOpenOrganization,\n                        icon: const Icon(Icons.apartment_outlined, size: 18),\n                        label: const Text('机构'),\n                      ),"""
file = Path(workspace)
text = file.read_text(encoding="utf-8")
count = text.count(icon_action)
if count != 2:
    raise SystemExit(f"{workspace}: expected two widget Organization icon actions, found {count}")
text = text.replace(icon_action, text_action)

today_icon_action = """                  if (onOpenOrganization != null)\n                    IconButton(\n                      key: const Key('v2-open-organization-scope'),\n                      tooltip: '进入机构视角',\n                      onPressed: onOpenOrganization,\n                      icon: const Icon(Icons.apartment_outlined),\n                    ),"""
today_text_action = """                  if (onOpenOrganization != null)\n                    TextButton.icon(\n                      key: const Key('v2-open-organization-scope'),\n                      onPressed: onOpenOrganization,\n                      icon: const Icon(Icons.apartment_outlined, size: 18),\n                      label: const Text('机构'),\n                    ),"""
if text.count(today_icon_action) != 1:
    raise SystemExit(f"{workspace}: Today Organization icon action anchor not found exactly once")
text = text.replace(today_icon_action, today_text_action, 1)
file.write_text(text, encoding="utf-8")

# Tests: visible touch entry, previous Personal destination, and hidden detail continuity.
test_path = "test/features/v2_typed_organization_navigation_test.dart"
replace_once(
    test_path,
    "      expect(\n        find.byKey(const Key('v2-open-organization-scope')),\n        findsOneWidget,\n      );\n\n      await tester.tap(find.byKey(const Key('v2-open-organization-scope')));",
    "      expect(\n        find.byKey(const Key('v2-open-organization-scope')),\n        findsOneWidget,\n      );\n      expect(find.widgetWithText(TextButton, '机构'), findsOneWidget);\n\n      await tester.tap(find.byKey(const Key('v2-open-organization-scope')));",
)

new_tests = r'''

  testWidgets(
    'compact Organization visit returns to the previous Personal destination',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_previewApp(withOrganization: true));
      await tester.pumpAndSettle();

      var navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      navigation.onDestinationSelected!(1);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-student-search')), findsOneWidget);
      expect(find.widgetWithText(TextButton, '机构'), findsOneWidget);

      await tester.tap(find.byKey(const Key('v2-open-organization-scope')));
      await tester.pumpAndSettle();
      expect(find.text('机构测试页'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigation.selectedIndex, 1);
      expect(find.byKey(const Key('v2-student-search')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'medium Organization visit preserves an open Personal student detail',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_previewApp(withOrganization: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('学生'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('林同学').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-student-search')), findsNothing);
      expect(find.text('现在最重要'), findsOneWidget);

      await tester.tap(find.byTooltip('机构'));
      await tester.pumpAndSettle();
      expect(find.text('机构测试页'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('v2-medium-shell')), findsOneWidget);
      expect(find.byKey(const Key('v2-student-search')), findsNothing);
      expect(find.text('现在最重要'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact manager Organization entry stays visible at 320px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_previewApp(withOrganization: true));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, '机构'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
'''
replace_once(
    test_path,
    "\n  testWidgets('desktop manager-teacher gets Organization in the primary rail', (",
    new_tests + "\n  testWidgets('desktop manager-teacher gets Organization in the primary rail', (",
)

# Design contracts: scope visits preserve Personal context; compact touch entry is visibly labeled.
nav_path = Path("docs/design/NAVIGATION_STATE_AUDIT.md")
nav = nav_path.read_text(encoding="utf-8")
section = """

## Cross-scope visit continuity

Opening Organization is a temporary change of work scope, not navigation inside Personal. A manager-teacher should therefore return to the Personal location they deliberately left.

- entering Organization remembers the current Personal destination;
- Personal student/case drill-down state may stay dormant while Organization is visible;
- returning from Organization restores that Personal destination and still-valid detail/case context;
- explicitly choosing a different Personal rail/bottom destination remains real navigation and clears drill-down state by the existing rules;
- if refreshed data invalidates the selected student/case, normal reconciliation still fails safe instead of reviving stale context.

Adaptive shells must ignore dormant Personal detail flags while Organization is the active destination. This allows continuity without letting hidden Personal state override the Organization surface.
"""
if "## Cross-scope visit continuity" not in nav:
    nav_path.write_text(nav.rstrip() + section + "\n", encoding="utf-8")

page_path = Path("docs/design/PAGE_RHYTHM_AUDIT.md")
page = page_path.read_text(encoding="utf-8")
old = "A manager-teacher reaches Organization through a quiet header action; Organization is not added as a fourth bottom-navigation item."
new = "A manager-teacher reaches Organization through a quiet, visibly labeled `机构` header action on Compact touch layouts; Organization is not added as a fourth bottom-navigation item."
if page.count(old) != 1:
    raise SystemExit("PAGE_RHYTHM compact Organization sentence not found exactly once")
page_path.write_text(page.replace(old, new, 1), encoding="utf-8")
