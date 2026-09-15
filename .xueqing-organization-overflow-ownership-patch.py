from pathlib import Path

source_path = Path('lib/features/design_v2/v2_organization_workspace_page.dart')
source = source_path.read_text()
old_signature = '''  List<Widget> _organizationHeaderActions({required bool canSignOut}) {
    return ['''
new_signature = '''  List<Widget> _organizationHeaderActions({
    required bool canSignOut,
    required bool showOverflow,
  }) {
    return ['''
if source.count(old_signature) != 1:
    raise SystemExit('header action signature did not match exactly once')
source = source.replace(old_signature, new_signature)

old_menu = '''      PopupMenuButton<_OrganizationPageAction>(
        key: const Key('v2-organization-more'),'''
new_menu = '''      if (showOverflow)
        PopupMenuButton<_OrganizationPageAction>(
          key: const Key('v2-organization-more'),'''
if source.count(old_menu) != 1:
    raise SystemExit('organization overflow menu did not match exactly once')
source = source.replace(old_menu, new_menu)

# Reindent the menu body one level to keep formatter output conventional.
start = source.index("        PopupMenuButton<_OrganizationPageAction>(\n          key: const Key('v2-organization-more'),")
end_marker = "\n    ];\n  }\n\n  String get _embeddedSectionTitle"
end = source.index(end_marker, start)
block = source[start:end]
lines = block.splitlines()
for index in range(2, len(lines)):
    lines[index] = '  ' + lines[index]
source = source[:start] + '\n'.join(lines) + source[end:]

old_call = '''                          actions: _organizationHeaderActions(
                            canSignOut: canSignOut,
                          ),'''
new_call = '''                          actions: _organizationHeaderActions(
                            canSignOut: canSignOut,
                            showOverflow: !widget.embedded || compact,
                          ),'''
if source.count(old_call) != 1:
    raise SystemExit('header action call did not match exactly once')
source = source.replace(old_call, new_call)
source_path.write_text(source)

test_path = Path('test/features/v2_organization_workspace_test.dart')
test = test_path.read_text()
old_assertions = '''      expect(find.byKey(const Key('v2-workspace-refresh')), findsOneWidget);
      await tester.tap(find.byTooltip('机构学情监督'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-organization-refresh')), findsOneWidget);
      expect(find.byKey(const Key('v2-workspace-refresh')), findsNothing);

      await tester.binding.setSurfaceSize(const Size(800, 800));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-medium-shell')), findsOneWidget);
      expect(find.byKey(const Key('v2-organization-refresh')), findsOneWidget);
      expect(find.byKey(const Key('v2-workspace-refresh')), findsNothing);
      expect(tester.takeException(), isNull);'''
new_assertions = '''      expect(find.byKey(const Key('v2-workspace-refresh')), findsOneWidget);
      expect(find.byKey(const Key('v2-workspace-more')), findsOneWidget);
      await tester.tap(find.byTooltip('机构学情监督'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-organization-refresh')), findsOneWidget);
      expect(find.byKey(const Key('v2-workspace-refresh')), findsNothing);
      expect(find.byKey(const Key('v2-workspace-more')), findsOneWidget);
      expect(find.byKey(const Key('v2-organization-more')), findsNothing);

      await tester.binding.setSurfaceSize(const Size(800, 800));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-medium-shell')), findsOneWidget);
      expect(find.byKey(const Key('v2-organization-refresh')), findsOneWidget);
      expect(find.byKey(const Key('v2-workspace-refresh')), findsNothing);
      expect(find.byKey(const Key('v2-workspace-more')), findsOneWidget);
      expect(find.byKey(const Key('v2-organization-more')), findsNothing);
      expect(tester.takeException(), isNull);'''
if test.count(old_assertions) != 1:
    raise SystemExit('refresh ownership assertions did not match exactly once')
test = test.replace(old_assertions, new_assertions)

marker = '''  testWidgets(
    'Windows Organization rail opens exact peer management areas across resize','''
inserted = '''  testWidgets('compact embedded Organization keeps its local overflow fallback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workspace = _workspace();
    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: V2OrganizationWorkspacePage(
          workspace: workspace,
          workspaceData: V2ReadModelAdapter.fromWorkspace(workspace)
              .workspaceData,
          responsibility: _context(personalProfileIds: const []),
          runtime: _runtime(includeManagement: false),
          embedded: true,
          onRefresh: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v2-organization-refresh')), findsOneWidget);
    expect(find.byKey(const Key('v2-organization-more')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Windows Organization rail opens exact peer management areas across resize','''
if test.count(marker) != 1:
    raise SystemExit('compact fallback insertion marker did not match exactly once')
test = test.replace(marker, inserted)
test_path.write_text(test)
