from pathlib import Path

workspace_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
test_path = Path('test/features/design_v2_workspace_test.dart')

workspace = workspace_path.read_text(encoding='utf-8')
old_history = "    final hasInternalHistory = widget.showCase || _studentOpen;\n"
new_history = (
    "    final hasInternalHistory = widget.showCase || _studentOpen;\n"
    "    final handlesSystemBack =\n"
    "        hasInternalHistory || widget.destination != 0;\n"
)
if workspace.count(old_history) != 1:
    raise SystemExit(
        f'expected exactly one compact history declaration, found {workspace.count(old_history)}'
    )
workspace = workspace.replace(old_history, new_history, 1)

old_can_pop = "      canPop: !hasInternalHistory,\n"
new_can_pop = "      canPop: !handlesSystemBack,\n"
if workspace.count(old_can_pop) != 1:
    raise SystemExit(
        f'expected exactly one compact PopScope canPop declaration, found {workspace.count(old_can_pop)}'
    )
workspace = workspace.replace(old_can_pop, new_can_pop, 1)

old_back = """        if (_studentOpen) {
          setState(() => _studentOpen = false);
        }
"""
new_back = """        if (_studentOpen) {
          setState(() => _studentOpen = false);
          return;
        }
        if (widget.destination != 0) {
          widget.onDestinationChanged(0);
        }
"""
if workspace.count(old_back) != 1:
    raise SystemExit(
        f'expected exactly one compact student-back branch, found {workspace.count(old_back)}'
    )
workspace = workspace.replace(old_back, new_back, 1)
workspace_path.write_text(workspace, encoding='utf-8')

tests = test_path.read_text(encoding='utf-8')
marker = "  testWidgets('student search filters real people without changing identity', (\n"
if tests.count(marker) != 1:
    raise SystemExit(f'expected exactly one test insertion marker, found {tests.count(marker)}')
new_test = """  testWidgets('compact system back returns secondary destination to Today', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    var navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

"""
if new_test.strip() in tests:
    raise SystemExit('compact system-back regression test already exists')
tests = tests.replace(marker, new_test + marker, 1)
test_path.write_text(tests, encoding='utf-8')
