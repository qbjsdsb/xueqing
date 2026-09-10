from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


# 1. Compact Android system-back hierarchy.
workspace_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
workspace = workspace_path.read_text(encoding='utf-8')
workspace = replace_once(
    workspace,
    "    final hasInternalHistory = widget.showCase || _studentOpen;\n",
    "    final hasInternalHistory = widget.showCase || _studentOpen;\n"
    "    final handlesSystemBack =\n"
    "        hasInternalHistory || widget.destination != 0;\n",
    'compact back declaration',
)
workspace = replace_once(
    workspace,
    "      canPop: !hasInternalHistory,\n",
    "      canPop: !handlesSystemBack,\n",
    'compact PopScope canPop',
)
workspace = replace_once(
    workspace,
    """        if (_studentOpen) {
          setState(() => _studentOpen = false);
        }
""",
    """        if (_studentOpen) {
          setState(() => _studentOpen = false);
          return;
        }
        if (widget.destination != 0) {
          widget.onDestinationChanged(0);
        }
""",
    'compact system-back handler',
)
workspace_path.write_text(workspace, encoding='utf-8')

# 2. Runtime regression for top-level compact navigation.
workspace_test_path = Path('test/features/design_v2_workspace_test.dart')
workspace_tests = workspace_test_path.read_text(encoding='utf-8')
marker = "  testWidgets('student search filters real people without changing identity', (\n"
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
if new_test.strip() in workspace_tests:
    raise SystemExit('compact system-back regression test already exists')
workspace_tests = replace_once(
    workspace_tests,
    marker,
    new_test + marker,
    'workspace regression insertion point',
)
workspace_test_path.write_text(workspace_tests, encoding='utf-8')

# 3. Update the source-contract test to the new, intentional hierarchy.
contract_path = Path('test/features/v032_real_device_ux_contract_test.dart')
contract = contract_path.read_text(encoding='utf-8')
contract = replace_once(
    contract,
    """    expect(source, contains('canPop: !hasInternalHistory'));
    expect(source, contains('widget.onBackFromCase();'));
    expect(source, contains('setState(() => _studentOpen = false)'));
""",
    """    expect(source, contains('final handlesSystemBack ='));
    expect(source, contains('hasInternalHistory || widget.destination != 0'));
    expect(source, contains('canPop: !handlesSystemBack'));
    expect(source, contains('widget.onBackFromCase();'));
    expect(source, contains('setState(() => _studentOpen = false)'));
    expect(source, contains('widget.onDestinationChanged(0);'));
""",
    'real-device source contract',
)
contract_path.write_text(contract, encoding='utf-8')

# 4. Make management widget tests hit real controls and truly exercise re-entry guards.
management_test_path = Path('test/features/organization_management_test.dart')
management_tests = management_test_path.read_text(encoding='utf-8')
management_tests = replace_once(
    management_tests,
    """  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}
""",
    """  await tester.ensureVisible(target);
  final compactChip = find.ancestor(of: target, matching: find.byType(ChoiceChip));
  if (compactChip.evaluate().isNotEmpty) {
    await tester.tap(compactChip);
  } else {
    await tester.tap(target);
  }
  await tester.pumpAndSettle();
}
""",
    'management area test helper',
)
management_tests = replace_once(
    management_tests,
    """    await tester.tap(addStudent);
    await tester.tap(addStudent);
    await tester.pumpAndSettle();
""",
    """    final addStudentButton = tester.widget<FilledButton>(addStudent);
    addStudentButton.onPressed!();
    addStudentButton.onPressed!();
    await tester.pumpAndSettle();
""",
    'rapid add-student re-entry test',
)
management_tests = replace_once(
    management_tests,
    """    await tester.tap(addSubject);
    await tester.tap(addSubject);
    await tester.pumpAndSettle();
""",
    """    final addSubjectButton = tester.widget<TextButton>(addSubject);
    addSubjectButton.onPressed!();
    addSubjectButton.onPressed!();
    await tester.pumpAndSettle();
""",
    'rapid add-subject re-entry test',
)
management_tests = replace_once(
    management_tests,
    """    await tester.tap(configureTeacherSubjects);
    await tester.tap(configureTeacherSubjects);
    await tester.pumpAndSettle();
""",
    """    final configureButton = tester.widget<TextButton>(
      configureTeacherSubjects,
    );
    configureButton.onPressed!();
    configureButton.onPressed!();
    await tester.pumpAndSettle();
""",
    'rapid teacher-config re-entry test',
)
management_test_path.write_text(management_tests, encoding='utf-8')

# 5. Turn future missed taps into real failures instead of warning-only false greens.
flutter_test_config = Path('test/flutter_test_config.dart')
if flutter_test_config.exists():
    raise SystemExit('test/flutter_test_config.dart unexpectedly already exists')
flutter_test_config.write_text(
    """import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  WidgetController.hitTestWarningShouldBeFatal = true;
  await testMain();
}
""",
    encoding='utf-8',
)

# 6. Keep Supabase CLI local branch state out of version control permanently.
gitignore_path = Path('.gitignore')
gitignore = gitignore_path.read_text(encoding='utf-8')
gitignore = replace_once(
    gitignore,
    "# Supabase local tooling\nsupabase/.temp/\n",
    "# Supabase local tooling\nsupabase/.temp/\nsupabase/.branches/\n",
    'Supabase local tooling ignore block',
)
gitignore_path.write_text(gitignore, encoding='utf-8')
