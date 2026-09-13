from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one anchor, found {count}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


page = "lib/features/design_v2/v2_organization_workspace_page.dart"
replace_once(
    page,
    "  _OrganizationSection _section = _OrganizationSection.learning;\n  bool _checkingForUpdates = false;",
    "  _OrganizationSection _section = _OrganizationSection.learning;\n  bool _managementActivated = false;\n  bool _checkingForUpdates = false;",
)

replace_once(
    page,
    "                              onSelectionChanged: (selection) {\n                                setState(() => _section = selection.single);\n                              },",
    "                              onSelectionChanged: (selection) {\n                                final nextSection = selection.single;\n                                setState(() {\n                                  _section = nextSection;\n                                  if (nextSection ==\n                                      _OrganizationSection.management) {\n                                    _managementActivated = true;\n                                  }\n                                });\n                              },",
)

old_body = '''                  Expanded(
                    child: _section == _OrganizationSection.learning
                        ? _OrganizationLearningView(
                            workspace: widget.workspace,
                            data: widget.workspaceData,
                            responsibility: widget.responsibility,
                            workflowController:
                                _organizationWorkflowController(),
                            composerDraftStore:
                                widget.runtime.composerDraftStore,
                            composerDraftScopeKey:
                                widget.runtime.composerDraftStore != null &&
                                    widget.runtime.sessionUserId != null
                                ? '${quickCaptureComposerScopeKey(sessionUserId: widget.runtime.sessionUserId!, organizationId: widget.workspace.organizationId)}:organization'
                                : null,
                            onChanged: widget.onChanged,
                          )
                        : Scrollbar(
                            controller: _managementScrollController,
                            thumbVisibility: !compact,
                            interactive: !compact,
                            child: SingleChildScrollView(
                              controller: _managementScrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              child: !compact
                                  ? SelectionArea(child: _managementContent())
                                  : _managementContent(),
                            ),
                          ),
                  ),'''
new_body = '''                  Expanded(
                    child: IndexedStack(
                      index: _section == _OrganizationSection.learning ? 0 : 1,
                      children: [
                        _OrganizationLearningView(
                          workspace: widget.workspace,
                          data: widget.workspaceData,
                          responsibility: widget.responsibility,
                          workflowController: _organizationWorkflowController(),
                          composerDraftStore: widget.runtime.composerDraftStore,
                          composerDraftScopeKey:
                              widget.runtime.composerDraftStore != null &&
                                  widget.runtime.sessionUserId != null
                              ? '${quickCaptureComposerScopeKey(sessionUserId: widget.runtime.sessionUserId!, organizationId: widget.workspace.organizationId)}:organization'
                              : null,
                          onChanged: widget.onChanged,
                        ),
                        if (_managementActivated)
                          Scrollbar(
                            controller: _managementScrollController,
                            thumbVisibility: !compact,
                            interactive: !compact,
                            child: SingleChildScrollView(
                              controller: _managementScrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              child: !compact
                                  ? SelectionArea(child: _managementContent())
                                  : _managementContent(),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),'''
replace_once(page, old_body, new_body)

tests = r'''

  testWidgets(
    'Organization keeps learning search and selected student while visiting Management',
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

      await tester.tap(find.text('管理').last);
      await tester.pumpAndSettle();
      expect(find.text('当前账号没有可用的机构管理权限。'), findsOneWidget);

      await tester.tap(find.text('学情').last);
      await tester.pumpAndSettle();
      final search = tester.widget<TextField>(
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
    'Organization keeps learning attention filter while visiting Management',
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

      await tester.tap(find.text('管理').last);
      await tester.pumpAndSettle();
      expect(find.text('当前账号没有可用的机构管理权限。'), findsOneWidget);

      await tester.tap(find.text('学情').last);
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
addition = """

Switching between Organization Learning and Management is also presentation/workspace navigation, not a request to clear the supervisor's Learning context. Learning search, attention filter and selected student remain alive while Management is visited. Management is initialized lazily on first entry so preserving state does not add eager management work to the default Learning view.
"""
anchor = "The loader therefore gives the embedded Organization workspace a stable identity across adaptive shell replacement. Window width may change presentation, but it must not recreate the supervisor's current working context."
if addition.strip() not in audit:
    if audit.count(anchor) != 1:
        raise SystemExit("navigation audit anchor not found exactly once")
    audit = audit.replace(anchor, anchor + addition.rstrip(), 1)
    audit_path.write_text(audit.rstrip() + "\n", encoding="utf-8")
