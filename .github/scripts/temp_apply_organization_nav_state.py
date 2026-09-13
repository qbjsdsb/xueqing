from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one anchor, found {count}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "lib/features/design_v2/v2_workspace_loader.dart",
    "class _V2WorkspaceLoaderState extends State<V2WorkspaceLoader> {\n  late Future<_V2LoadedWorkspace> _workspaceFuture;",
    "class _V2WorkspaceLoaderState extends State<V2WorkspaceLoader> {\n  final GlobalKey _embeddedOrganizationWorkspaceKey = GlobalKey(\n    debugLabel: 'v2-embedded-organization-workspace',\n  );\n  late Future<_V2LoadedWorkspace> _workspaceFuture;",
)

replace_once(
    "lib/features/design_v2/v2_workspace_loader.dart",
    "            ? (context, onBackToPersonal) => V2OrganizationWorkspacePage(\n                workspace: rawWorkspace,",
    "            ? (context, onBackToPersonal) => V2OrganizationWorkspacePage(\n                key: _embeddedOrganizationWorkspaceKey,\n                workspace: rawWorkspace,",
)

tests = r'''

  testWidgets(
    'embedded Organization keeps management section across adaptive shell resize',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final workspace = _managerTeacherWorkspace();

      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: V2WorkspaceLoader(
            loadWorkspace: () async => workspace,
            responsibilityReadRepository: _FakeResponsibilityRepository(
              _responsibilityContext(
                personalProfileIds: const ['profile-personal'],
              ),
            ),
            runtime: _runtime(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('v2-open-organization-scope')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('管理').last);
      await tester.pumpAndSettle();
      expect(find.text('当前账号没有可用的机构管理权限。'), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(800, 844));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-medium-shell')), findsOneWidget);
      expect(find.text('当前账号没有可用的机构管理权限。'), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(1100, 844));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-expanded-shell')), findsOneWidget);
      expect(find.text('当前账号没有可用的机构管理权限。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'embedded Organization keeps learning query and selected student across resize',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final workspace = _managerTeacherWorkspace();

      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: V2WorkspaceLoader(
            loadWorkspace: () async => workspace,
            responsibilityReadRepository: _FakeResponsibilityRepository(
              _responsibilityContext(
                personalProfileIds: const ['profile-personal'],
              ),
            ),
            runtime: _runtime(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('机构'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('v2-organization-learning-search')),
        '学生',
      );
      await tester.tap(
        find.byKey(const Key('v2-organization-student-select-student-org')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('v2-organization-quick-capture-student-org')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('v2-organization-quick-capture-student-personal')),
        findsNothing,
      );

      await tester.binding.setSurfaceSize(const Size(800, 844));
      await tester.pumpAndSettle();
      var search = tester.widget<TextField>(
        find.byKey(const Key('v2-organization-learning-search')),
      );
      expect(search.controller?.text, '学生');

      await tester.binding.setSurfaceSize(const Size(1100, 844));
      await tester.pumpAndSettle();
      search = tester.widget<TextField>(
        find.byKey(const Key('v2-organization-learning-search')),
      );
      expect(search.controller?.text, '学生');
      expect(
        find.byKey(const Key('v2-organization-quick-capture-student-org')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('v2-organization-quick-capture-student-personal')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'embedded Organization keeps attention filter across adaptive shell resize',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final workspace = _managerTeacherWorkspace();

      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: V2WorkspaceLoader(
            loadWorkspace: () async => workspace,
            responsibilityReadRepository: _FakeResponsibilityRepository(
              _responsibilityContext(
                personalProfileIds: const ['profile-personal'],
              ),
            ),
            runtime: _runtime(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('机构'));
      await tester.pumpAndSettle();
      final filterFinder = find.byKey(
        const Key('v2-organization-filter-unassigned'),
      );
      await tester.tap(filterFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(filterFinder).selected, isTrue);

      await tester.binding.setSurfaceSize(const Size(800, 844));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(filterFinder).selected, isTrue);

      await tester.binding.setSurfaceSize(const Size(1100, 844));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(filterFinder).selected, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
'''

replace_once(
    "test/features/v2_typed_organization_navigation_test.dart",
    "\n}\n\nWidget _previewApp",
    tests + "\n}\n\nWidget _previewApp",
)

audit_path = Path("docs/design/NAVIGATION_STATE_AUDIT.md")
audit = audit_path.read_text(encoding="utf-8")
section = """

## Organization scope continuity

For a manager who also teaches, the embedded Organization workspace is one continuous supervisory work surface even when the outer Personal shell changes between Compact, Medium and Expanded.

- the current Organization section (Learning / Management) must survive resize;
- Learning search text and attention filter must survive resize;
- the selected student in expanded supervision must survive a round trip through a narrower shell;
- preserving these presentation states must not change Personal responsibility, Organization authority, Case owner, Profile Lead, or write semantics.

The loader therefore gives the embedded Organization workspace a stable identity across adaptive shell replacement. Window width may change presentation, but it must not recreate the supervisor's current working context.
"""
if "## Organization scope continuity" not in audit:
    audit_path.write_text((audit.rstrip() + section).rstrip() + "\n", encoding="utf-8")
