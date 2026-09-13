from pathlib import Path


def one(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


def in_section(text: str, start: str, end: str, old: str, new: str, label: str) -> str:
    i = text.index(start)
    j = text.index(end, i)
    section = text[i:j]
    count = section.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one anchor in section, found {count}")
    return text[:i] + section.replace(old, new, 1) + text[j:]


workspace_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
text = workspace_path.read_text(encoding='utf-8')

text = one(
    text,
    '  V2WorkspaceDestination _destination = V2WorkspaceDestination.today;\n  V2Student? _selectedStudent;',
    '  V2WorkspaceDestination _destination = V2WorkspaceDestination.today;\n  V2WorkspaceDestination _lastPersonalDestination =\n      V2WorkspaceDestination.today;\n  V2Student? _selectedStudent;',
    'workspace state',
)
text = one(
    text,
    '      _destination = V2WorkspaceDestination.today;\n      _showCase = false;\n      _showStudentDetail = false;',
    '      _destination = V2WorkspaceDestination.today;\n      _lastPersonalDestination = V2WorkspaceDestination.today;\n      _showCase = false;\n      _showStudentDetail = false;',
    'capability reconciliation',
)
text = one(
    text,
    '''  void _changeDestination(V2WorkspaceDestination value) {
    setState(() {
      _destination = value;
      _showCase = false;
      if (value != V2WorkspaceDestination.students) {
        _showStudentDetail = false;
      }
    });
  }
''',
    '''  void _changeDestination(V2WorkspaceDestination value) {
    setState(() {
      if (value == V2WorkspaceDestination.organization) {
        if (_destination != V2WorkspaceDestination.organization) {
          _lastPersonalDestination = _destination;
        }
        _destination = value;
        return;
      }

      _lastPersonalDestination = value;
      _destination = value;
      _showCase = false;
      if (value != V2WorkspaceDestination.students) {
        _showStudentDetail = false;
      }
    });
  }

  void _returnFromOrganization() {
    setState(() => _destination = _lastPersonalDestination);
  }
''',
    'destination semantics',
)

# Parent -> shells.
text = one(
    text,
    '                    organizationPageBuilder: widget.organizationPageBuilder,\n                    onOpenMore: () => _showWorkspaceMenu(context),',
    '                    organizationPageBuilder: widget.organizationPageBuilder,\n                    onBackFromOrganization: _returnFromOrganization,\n                    onOpenMore: () => _showWorkspaceMenu(context),',
    'compact parent callback',
)
text = one(
    text,
    '                    organizationPageBuilder: widget.organizationPageBuilder,\n                    onRefresh: widget.onRefresh == null',
    '                    organizationPageBuilder: widget.organizationPageBuilder,\n                    onBackFromOrganization: _returnFromOrganization,\n                    onRefresh: widget.onRefresh == null',
    'medium parent callback',
)
text = one(
    text,
    '                  organizationPageBuilder: widget.organizationPageBuilder,\n                  onRefresh: widget.onRefresh == null',
    '                  organizationPageBuilder: widget.organizationPageBuilder,\n                  onBackFromOrganization: _returnFromOrganization,\n                  onRefresh: widget.onRefresh == null',
    'desktop parent callback',
)

# Desktop.
text = in_section(
    text, 'class _DesktopWorkspace', 'class _MediumWorkspace',
    '    required this.organizationPageBuilder,\n    required this.onSettings,',
    '    required this.organizationPageBuilder,\n    required this.onBackFromOrganization,\n    required this.onSettings,',
    'desktop constructor',
)
text = in_section(
    text, 'class _DesktopWorkspace', 'class _MediumWorkspace',
    '  final V2OrganizationWorkspaceBuilder? organizationPageBuilder;\n  final VoidCallback? onRefresh;',
    '  final V2OrganizationWorkspaceBuilder? organizationPageBuilder;\n  final VoidCallback onBackFromOrganization;\n  final VoidCallback? onRefresh;',
    'desktop fields',
)
text = in_section(
    text, 'class _DesktopWorkspace', 'class _MediumWorkspace',
    '''                child: organizationPageBuilder!(
                  context,
                  () => onDestinationChanged(V2WorkspaceDestination.today),
                ),''',
    '''                child: organizationPageBuilder!(
                  context,
                  onBackFromOrganization,
                ),''',
    'desktop organization back',
)

# Medium.
text = in_section(
    text, 'class _MediumWorkspace', 'class _CompactWorkspace',
    '    required this.organizationPageBuilder,\n    required this.onSettings,',
    '    required this.organizationPageBuilder,\n    required this.onBackFromOrganization,\n    required this.onSettings,',
    'medium constructor',
)
text = in_section(
    text, 'class _MediumWorkspace', 'class _CompactWorkspace',
    '  final V2OrganizationWorkspaceBuilder? organizationPageBuilder;\n  final VoidCallback? onRefresh;',
    '  final V2OrganizationWorkspaceBuilder? organizationPageBuilder;\n  final VoidCallback onBackFromOrganization;\n  final VoidCallback? onRefresh;',
    'medium fields',
)
text = in_section(
    text, 'class _MediumWorkspace', 'class _CompactWorkspace',
    '        if (widget.showCase && widget.selectedCase != null) {',
    '        if (widget.destination == V2WorkspaceDestination.students &&\n            widget.showCase &&\n            widget.selectedCase != null) {',
    'medium dormant case gate',
)
text = in_section(
    text, 'class _MediumWorkspace', 'class _CompactWorkspace',
    '''          body = widget.organizationPageBuilder!(context, () {
            widget.onDestinationChanged(V2WorkspaceDestination.today);
          });''',
    '''          body = widget.organizationPageBuilder!(
            context,
            widget.onBackFromOrganization,
          );''',
    'medium organization back',
)
text = in_section(
    text, 'class _MediumWorkspace', 'class _CompactWorkspace',
    '        final hasInternalHistory = widget.showCase || widget.showStudentDetail;',
    '        final hasInternalHistory =\n            widget.destination == V2WorkspaceDestination.students &&\n            (widget.showCase || widget.showStudentDetail);',
    'medium dormant history gate',
)

# Compact.
text = in_section(
    text, 'class _CompactWorkspace', 'class _NavigationRail',
    '    required this.organizationPageBuilder,\n    required this.onOpenMore,',
    '    required this.organizationPageBuilder,\n    required this.onBackFromOrganization,\n    required this.onOpenMore,',
    'compact constructor',
)
text = in_section(
    text, 'class _CompactWorkspace', 'class _NavigationRail',
    '  final V2OrganizationWorkspaceBuilder? organizationPageBuilder;\n  final VoidCallback? onOpenMore;',
    '  final V2OrganizationWorkspaceBuilder? organizationPageBuilder;\n  final VoidCallback onBackFromOrganization;\n  final VoidCallback? onOpenMore;',
    'compact fields',
)
text = in_section(
    text, 'class _CompactWorkspace', 'class _NavigationRail',
    '    if (widget.showCase && widget.selectedCase != null) {',
    '    if (widget.destination == V2WorkspaceDestination.students &&\n        widget.showCase &&\n        widget.selectedCase != null) {',
    'compact dormant case gate',
)
text = in_section(
    text, 'class _CompactWorkspace', 'class _NavigationRail',
    '''      body = widget.organizationPageBuilder!(context, () {
        widget.onDestinationChanged(V2WorkspaceDestination.today);
      });''',
    '''      body = widget.organizationPageBuilder!(
        context,
        widget.onBackFromOrganization,
      );''',
    'compact organization back',
)
text = in_section(
    text, 'class _CompactWorkspace', 'class _NavigationRail',
    '    final hasInternalHistory = widget.showCase || widget.showStudentDetail;',
    '    final hasInternalHistory =\n        widget.destination == V2WorkspaceDestination.students &&\n        (widget.showCase || widget.showStudentDetail);',
    'compact dormant history gate',
)

# Compact Personal headers: visible Organization entry, same quiet location.
student_old = '''                    if (widget.onOpenOrganization != null)
                      IconButton(
                        key: const Key('v2-open-organization-scope'),
                        tooltip: '进入机构视角',
                        onPressed: widget.onOpenOrganization,
                        icon: const Icon(Icons.apartment_outlined),
                      ),'''
student_new = '''                    if (widget.onOpenOrganization != null)
                      TextButton.icon(
                        key: const Key('v2-open-organization-scope'),
                        onPressed: widget.onOpenOrganization,
                        icon: const Icon(Icons.apartment_outlined, size: 18),
                        label: const Text('机构'),
                      ),'''
text = in_section(
    text, 'class _StudentListPane', 'class _StudentRow',
    student_old, student_new, 'student Organization action',
)

learning_old = '''                  if (widget.onOpenOrganization != null)
                    IconButton(
                      key: const Key('v2-open-organization-scope'),
                      tooltip: '进入机构视角',
                      onPressed: widget.onOpenOrganization,
                      icon: const Icon(Icons.apartment_outlined),
                    ),'''
learning_new = '''                  if (widget.onOpenOrganization != null)
                    TextButton.icon(
                      key: const Key('v2-open-organization-scope'),
                      onPressed: widget.onOpenOrganization,
                      icon: const Icon(Icons.apartment_outlined, size: 18),
                      label: const Text('机构'),
                    ),'''
text = in_section(
    text, 'class _CaseIndexPane', 'class _V2OperationGuide',
    learning_old, learning_new, 'learning Organization action',
)

today_old = '''                  if (onOpenOrganization != null)
                    IconButton(
                      key: const Key('v2-open-organization-scope'),
                      tooltip: '进入机构视角',
                      onPressed: onOpenOrganization,
                      icon: const Icon(Icons.apartment_outlined),
                    ),'''
today_new = '''                  if (onOpenOrganization != null)
                    TextButton.icon(
                      key: const Key('v2-open-organization-scope'),
                      onPressed: onOpenOrganization,
                      icon: const Icon(Icons.apartment_outlined, size: 18),
                      label: const Text('机构'),
                    ),'''
text = one(text, today_old, today_new, 'today Organization action')
workspace_path.write_text(text, encoding='utf-8')

# Regression tests.
test_path = Path('test/features/v2_typed_organization_navigation_test.dart')
tests = test_path.read_text(encoding='utf-8')
tests = one(
    tests,
    '''      expect(
        find.byKey(const Key('v2-open-organization-scope')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('v2-open-organization-scope')));''',
    '''      expect(
        find.byKey(const Key('v2-open-organization-scope')),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, '机构'), findsOneWidget);

      await tester.tap(find.byKey(const Key('v2-open-organization-scope')));''',
    'compact manager discoverability assertion',
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
tests = one(
    tests,
    "\n  testWidgets('desktop manager-teacher gets Organization in the primary rail', (",
    new_tests + "\n  testWidgets('desktop manager-teacher gets Organization in the primary rail', (",
    'new navigation regressions',
)
test_path.write_text(tests, encoding='utf-8')

# Design contracts.
nav_path = Path('docs/design/NAVIGATION_STATE_AUDIT.md')
nav = nav_path.read_text(encoding='utf-8')
section = '''

## Cross-scope visit continuity

Opening Organization is a temporary change of work scope, not navigation inside Personal. A manager-teacher should therefore return to the Personal location they deliberately left.

- entering Organization remembers the current Personal destination;
- Personal student/case drill-down state may stay dormant while Organization is visible;
- returning from Organization restores that Personal destination and still-valid detail/case context;
- explicitly choosing a different Personal rail/bottom destination remains real navigation and clears drill-down state by the existing rules;
- if refreshed data invalidates the selected student/case, normal reconciliation still fails safe instead of reviving stale context.

Adaptive shells must ignore dormant Personal detail flags while Organization is the active destination. This allows continuity without letting hidden Personal state override the Organization surface.
'''
if '## Cross-scope visit continuity' not in nav:
    nav_path.write_text(nav.rstrip() + section + '\n', encoding='utf-8')

page_path = Path('docs/design/PAGE_RHYTHM_AUDIT.md')
page = page_path.read_text(encoding='utf-8')
page = one(
    page,
    'A manager-teacher reaches Organization through a quiet header action; Organization is not added as a fourth bottom-navigation item.',
    'A manager-teacher reaches Organization through a quiet, visibly labeled `机构` header action on Compact touch layouts; Organization is not added as a fourth bottom-navigation item.',
    'page rhythm Organization entry contract',
)
page_path.write_text(page, encoding='utf-8')
