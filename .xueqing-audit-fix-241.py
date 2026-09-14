from pathlib import Path

# 1) Navigation types belong to the shared navigation model, not the Management UI.
nav_path = Path('lib/features/design_v2/v2_workspace_navigation.dart')
nav = nav_path.read_text(encoding='utf-8')
if nav.strip() != 'enum V2OrganizationSection { learning, management }':
    raise SystemExit('unexpected workspace navigation model')
nav_path.write_text(
    'enum V2OrganizationSection { learning, management }\n\n'
    'enum OrganizationManagementArea { people, students, settings }\n',
    encoding='utf-8',
)

areas_path = Path(
    'lib/features/organization_management/presentation/organization_management_areas.dart'
)
areas = areas_path.read_text(encoding='utf-8')
for declaration in [
    'enum OrganizationManagementArea { people, students, settings }\n\n',
    'enum _ManagementExportMode { students, teacher }\n\n',
]:
    if areas.count(declaration) != 1:
        raise SystemExit(f'expected one declaration: {declaration!r}')
    areas = areas.replace(declaration, '', 1)

# Remove the cross-area export chooser. Each peer destination gets only its own
# relevant export action.
start = areas.find('  Future<void> _showExportRecords() async {')
end = areas.find('  Widget? _buildSetupNextStep() {', start)
if start < 0 or end < 0:
    raise SystemExit('export chooser block not found')
areas = areas[:start] + '''  OrganizationManagementArea? _setupNextStepArea() {
    final options = widget.snapshot.setupOptions;
    if (options.subjects.isEmpty) return OrganizationManagementArea.settings;
    if (options.teachers.isEmpty || !options.canCreateStudent) {
      return OrganizationManagementArea.people;
    }
    if (widget.snapshot.students.isEmpty) {
      return OrganizationManagementArea.students;
    }
    return null;
  }

  VoidCallback? _exportActionForSelectedArea() => switch (_selectedArea) {
    OrganizationManagementArea.people => widget.onExportTeacherRecords,
    OrganizationManagementArea.students => widget.onExportStudentRecords,
    OrganizationManagementArea.settings => null,
  };

''' + areas[end:]

old_setup = '    final setupNextStep = _buildSetupNextStep();\n'
new_setup = '''    final setupNextStep = _setupNextStepArea() == _selectedArea
        ? _buildSetupNextStep()
        : null;
    final exportAction = _exportActionForSelectedArea();
'''
if areas.count(old_setup) != 1:
    raise SystemExit('setup-next-step build anchor missing')
areas = areas.replace(old_setup, new_setup, 1)

old_export = '''          onExport:
              widget.onExportStudentRecords != null ||
                  widget.onExportTeacherRecords != null
              ? _showExportRecords
              : null,
'''
if areas.count(old_export) != 1:
    raise SystemExit('global export toolbar anchor missing')
areas = areas.replace(old_export, '          onExport: exportAction,\n', 1)
areas_path.write_text(areas, encoding='utf-8')

# Make OrganizationManagementPage see the shared navigation model for its parts.
page_path = Path(
    'lib/features/organization_management/presentation/organization_management_page.dart'
)
page = page_path.read_text(encoding='utf-8')
import_anchor = "import '../../../export/learning_record_export_feedback.dart';\n"
nav_import = "import '../../design_v2/v2_workspace_navigation.dart';\n"
if page.count(import_anchor) != 1:
    raise SystemExit('management page import anchor missing')
if nav_import not in page:
    page = page.replace(import_anchor, import_anchor + nav_import, 1)
page_path.write_text(page, encoding='utf-8')

# Workspace preview now depends only on the shared navigation model for the enum.
preview_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
preview = preview_path.read_text(encoding='utf-8')
presentation_import = (
    "import '../organization_management/presentation/organization_management_page.dart';\n"
)
if preview.count(presentation_import) != 1:
    raise SystemExit('workspace preview presentation import missing')
preview = preview.replace(presentation_import, '', 1)
preview_path.write_text(preview, encoding='utf-8')

# 2) Each Windows peer Management area owns its own scroll position while
# continuing to share one OrganizationManagementPage / repository snapshot.
organization_path = Path('lib/features/design_v2/v2_organization_workspace_page.dart')
organization = organization_path.read_text(encoding='utf-8')
old_controller = '  final ScrollController _managementScrollController = ScrollController();\n'
new_controller = '''  final Map<OrganizationManagementArea, ScrollController>
  _managementScrollControllers = <OrganizationManagementArea, ScrollController>{
    for (final area in OrganizationManagementArea.values) area: ScrollController(),
  };

  ScrollController get _managementScrollController =>
      _managementScrollControllers[
        _managementArea ?? OrganizationManagementArea.people
      ]!;
'''
if organization.count(old_controller) != 1:
    raise SystemExit('single management scroll controller anchor missing')
organization = organization.replace(old_controller, new_controller, 1)

old_dispose = '''  @override
  void dispose() {
    _managementScrollController.dispose();
    super.dispose();
  }
'''
new_dispose = '''  @override
  void dispose() {
    for (final controller in _managementScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
'''
if organization.count(old_dispose) != 1:
    raise SystemExit('management scroll dispose anchor missing')
organization = organization.replace(old_dispose, new_dispose, 1)

old_scroll = '''                          Scrollbar(
                            controller: _managementScrollController,
                            thumbVisibility: !compact,
                            interactive: !compact,
                            child: SingleChildScrollView(
                              controller: _managementScrollController,
'''
new_scroll = '''                          Scrollbar(
                            key: const Key('v2-organization-management-scrollbar'),
                            controller: _managementScrollController,
                            thumbVisibility: !compact,
                            interactive: !compact,
                            child: SingleChildScrollView(
                              key: ValueKey<String>(
                                'v2-organization-management-scroll-${_managementArea?.name ?? 'default'}',
                              ),
                              controller: _managementScrollController,
'''
if organization.count(old_scroll) != 1:
    raise SystemExit('management scroll widget anchor missing')
organization = organization.replace(old_scroll, new_scroll, 1)
organization_path.write_text(organization, encoding='utf-8')

# 3) Update state contract to read the enum from the shared model.
state_test_path = Path('test/features/organization_navigation_state_contract_test.dart')
state_test = state_test_path.read_text(encoding='utf-8')
old_areas_read = '''    final areas = File(
      'lib/features/organization_management/presentation/organization_management_areas.dart',
    ).readAsStringSync();
'''
new_areas_read = '''    final navigation = File(
      'lib/features/design_v2/v2_workspace_navigation.dart',
    ).readAsStringSync();
    final areas = File(
      'lib/features/organization_management/presentation/organization_management_areas.dart',
    ).readAsStringSync();
'''
if state_test.count(old_areas_read) != 1:
    raise SystemExit('organization state test file read anchor missing')
state_test = state_test.replace(old_areas_read, new_areas_read, 1)
state_test = state_test.replace(
    "    expect(areas, contains('enum OrganizationManagementArea'));\n",
    "    expect(navigation, contains('enum OrganizationManagementArea'));\n",
    1,
)
state_test_path.write_text(state_test, encoding='utf-8')

# 4) Strengthen the Windows source contract around the audit boundaries.
windows_contract_path = Path(
    'test/features/windows_organization_navigation_contract_test.dart'
)
contract = windows_contract_path.read_text(encoding='utf-8')
read_anchor = '''    final organization = File(
      'lib/features/design_v2/v2_organization_workspace_page.dart',
    ).readAsStringSync();
'''
read_replacement = read_anchor + '''    final navigation = File(
      'lib/features/design_v2/v2_workspace_navigation.dart',
    ).readAsStringSync();
    final areas = File(
      'lib/features/organization_management/presentation/organization_management_areas.dart',
    ).readAsStringSync();
'''
if contract.count(read_anchor) != 1:
    raise SystemExit('Windows contract read anchor missing')
contract = contract.replace(read_anchor, read_replacement, 1)
expect_anchor = "    expect(organization, contains('_embeddedSectionTitle'));\n"
expect_replacement = expect_anchor + '''    expect(navigation, contains('enum OrganizationManagementArea'));
    expect(
      workspace,
      isNot(contains('organization_management_page.dart')),
    );
    expect(organization, contains('_managementScrollControllers'));
    expect(
      organization,
      contains("v2-organization-management-scroll-${_managementArea?.name ?? 'default'}"),
    );
    expect(
      areas,
      contains('OrganizationManagementArea.people => widget.onExportTeacherRecords'),
    );
    expect(
      areas,
      contains('OrganizationManagementArea.students => widget.onExportStudentRecords'),
    );
    expect(areas, contains('OrganizationManagementArea.settings => null'));
'''
if contract.count(expect_anchor) != 1:
    raise SystemExit('Windows contract expectation anchor missing')
contract = contract.replace(expect_anchor, expect_replacement, 1)
windows_contract_path.write_text(contract, encoding='utf-8')

# 5) Add real peer-destination and per-area-scroll behavior coverage.
org_test_path = Path('test/features/v2_organization_workspace_test.dart')
org_test = org_test_path.read_text(encoding='utf-8')
insert_anchor = '''  testWidgets(
    'Organization scope refresh reloads activated Management without losing its area',
'''
if org_test.count(insert_anchor) != 1:
    raise SystemExit('organization workspace insertion anchor missing')
new_tests = r'''  testWidgets(
    'Windows Organization rail opens exact peer management areas across resize',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: V2WorkspaceLoader(
            loadWorkspace: () async => _workspace(),
            responsibilityReadRepository: _FakeResponsibilityRepository(
              _context(personalProfileIds: const ['profile-a']),
            ),
            runtime: _runtime(includeManagement: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('机构成员'));
      await tester.pumpAndSettle();
      expect(find.text('机构成员'), findsOneWidget);
      expect(find.byKey(const Key('management-area-people')), findsNothing);

      await tester.tap(find.byTooltip('机构学生'));
      await tester.pumpAndSettle();
      expect(find.text('学生档案'), findsOneWidget);

      await tester.tap(find.byTooltip('机构设置'));
      await tester.pumpAndSettle();
      expect(find.text('机构学科'), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(800, 800));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-medium-shell')), findsOneWidget);
      expect(find.text('机构学科'), findsOneWidget);

      await tester.tap(find.byTooltip('机构学生'));
      await tester.pumpAndSettle();
      expect(find.text('学生档案'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Windows Organization peer areas keep independent scroll positions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 520));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final managementRepository = _FakeOrganizationManagementRepository(
        members: _manyMembers(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: V2WorkspaceLoader(
            loadWorkspace: () async => _workspace(),
            responsibilityReadRepository: _FakeResponsibilityRepository(
              _context(personalProfileIds: const ['profile-a']),
            ),
            runtime: _runtime(
              includeManagement: true,
              managementRepository: managementRepository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('机构成员'));
      await tester.pumpAndSettle();
      final peopleScroll = find.byKey(
        const ValueKey<String>('v2-organization-management-scroll-people'),
      );
      expect(peopleScroll, findsOneWidget);
      final peopleController = tester
          .widget<SingleChildScrollView>(peopleScroll)
          .controller!;
      await tester.drag(peopleScroll, const Offset(0, -700));
      await tester.pumpAndSettle();
      final savedPeopleOffset = peopleController.offset;
      expect(savedPeopleOffset, greaterThan(100));

      await tester.tap(find.byTooltip('机构设置'));
      await tester.pumpAndSettle();
      final settingsScroll = find.byKey(
        const ValueKey<String>('v2-organization-management-scroll-settings'),
      );
      expect(settingsScroll, findsOneWidget);
      final settingsController = tester
          .widget<SingleChildScrollView>(settingsScroll)
          .controller!;
      expect(identical(settingsController, peopleController), isFalse);
      expect(settingsController.offset, lessThan(5));

      await tester.tap(find.byTooltip('机构成员'));
      await tester.pumpAndSettle();
      final restoredPeopleController = tester
          .widget<SingleChildScrollView>(peopleScroll)
          .controller!;
      expect(identical(restoredPeopleController, peopleController), isTrue);
      expect(restoredPeopleController.offset, closeTo(savedPeopleOffset, 1));
      expect(tester.takeException(), isNull);
    },
  );

'''
org_test = org_test.replace(insert_anchor, new_tests + insert_anchor, 1)

# Let the existing fake supply a long member list for scroll-state coverage.
class_anchor = '''class _FakeOrganizationManagementRepository
    implements OrganizationManagementRepository {
  int listStudentsCount = 0;

'''
class_replacement = '''class _FakeOrganizationManagementRepository
    implements OrganizationManagementRepository {
  _FakeOrganizationManagementRepository({this.members = const []});

  final List<OrganizationMember> members;
  int listStudentsCount = 0;

'''
if org_test.count(class_anchor) != 1:
    raise SystemExit('fake management repository anchor missing')
org_test = org_test.replace(class_anchor, class_replacement, 1)
old_members = '''  Future<List<OrganizationMember>> listMembers({
    required String organizationId,
  }) async => const [];
'''
new_members = '''  Future<List<OrganizationMember>> listMembers({
    required String organizationId,
  }) async => members;
'''
if org_test.count(old_members) != 1:
    raise SystemExit('fake listMembers anchor missing')
org_test = org_test.replace(old_members, new_members, 1)
helper_anchor = 'WorkspaceResponsibilityContext _context({\n'
if org_test.count(helper_anchor) != 1:
    raise SystemExit('test helper anchor missing')
members_helper = r'''List<OrganizationMember> _manyMembers() => List<OrganizationMember>.generate(
  36,
  (index) => OrganizationMember(
    appUserId: 'member-user-$index',
    membershipId: 'member-$index',
    email: 'teacher$index@example.com',
    displayName: '测试老师 $index',
    status: 'active',
    roles: const ['teacher'],
  ),
);

'''
org_test = org_test.replace(helper_anchor, members_helper + helper_anchor, 1)
org_test_path.write_text(org_test, encoding='utf-8')

# 6) Keep the canonical design contract truthful.
doc_path = Path('docs/design/WINDOWS_ORGANIZATION_NAVIGATION_V2.md')
doc = doc_path.read_text(encoding='utf-8')
doc_anchor = '- Compact and standalone Organization pages retain the area switcher so Members / Students / Settings are never made unreachable.\n'
if doc.count(doc_anchor) != 1:
    raise SystemExit('Windows navigation doc anchor missing')
doc = doc.replace(
    doc_anchor,
    doc_anchor
    + '- Members / Students / Settings keep independent scroll positions while sharing one management snapshot.\n'
    + '- Management onboarding and export actions stay contextual to the active peer destination.\n',
    1,
)
doc_path.write_text(doc, encoding='utf-8')
