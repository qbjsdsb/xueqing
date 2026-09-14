from pathlib import Path

organization_path = Path('lib/features/design_v2/v2_organization_workspace_page.dart')
text = organization_path.read_text(encoding='utf-8')

old_controller_block = '''  final Map<OrganizationManagementArea, ScrollController>
  _managementScrollControllers = <OrganizationManagementArea, ScrollController>{
    for (final area in OrganizationManagementArea.values) area: ScrollController(),
  };

  ScrollController get _managementScrollController =>
      _managementScrollControllers[
        _managementArea ?? OrganizationManagementArea.people
      ]!;
'''
new_controller_block = '''  final Map<OrganizationManagementArea, ScrollController>
  _managementScrollControllers = <OrganizationManagementArea, ScrollController>{
    for (final area in OrganizationManagementArea.values)
      area: ScrollController(keepScrollOffset: false),
  };
  final Map<OrganizationManagementArea, double> _managementScrollOffsets =
      <OrganizationManagementArea, double>{
        for (final area in OrganizationManagementArea.values) area: 0,
      };

  ScrollController get _managementScrollController =>
      _managementScrollControllers[
        _managementArea ?? OrganizationManagementArea.people
      ]!;

  void _rememberManagementScrollOffset() {
    final area = _managementArea;
    if (area == null) return;
    final controller = _managementScrollControllers[area]!;
    if (controller.hasClients) {
      _managementScrollOffsets[area] = controller.offset;
    }
  }

  void _restoreManagementScrollOffset(OrganizationManagementArea area) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _managementScrollControllers[area]!;
      if (!controller.hasClients) return;
      final position = controller.position;
      final target = _managementScrollOffsets[area]!
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((controller.offset - target).abs() > 0.5) {
        controller.jumpTo(target);
      }
    });
  }
'''
if text.count(old_controller_block) != 1:
    raise SystemExit('generated controller block not found exactly once')
text = text.replace(old_controller_block, new_controller_block, 1)

old_update = '''    final requestedArea = widget.managementArea;
    if (requestedArea != null && requestedArea != _managementArea) {
      _managementArea = requestedArea;
    }
'''
new_update = '''    final requestedArea = widget.managementArea;
    if (requestedArea != null && requestedArea != _managementArea) {
      _rememberManagementScrollOffset();
      _managementArea = requestedArea;
      _restoreManagementScrollOffset(requestedArea);
    }
'''
if text.count(old_update) != 1:
    raise SystemExit('management-area didUpdate block not found')
text = text.replace(old_update, new_update, 1)

old_handler = '''  void _handleManagementAreaChanged(OrganizationManagementArea area) {
    if (_managementArea == area) return;
    setState(() => _managementArea = area);
    widget.onManagementAreaChanged?.call(area);
  }
'''
new_handler = '''  void _handleManagementAreaChanged(OrganizationManagementArea area) {
    if (_managementArea == area) return;
    _rememberManagementScrollOffset();
    setState(() => _managementArea = area);
    _restoreManagementScrollOffset(area);
    widget.onManagementAreaChanged?.call(area);
  }
'''
if text.count(old_handler) != 1:
    raise SystemExit('management-area change handler not found')
text = text.replace(old_handler, new_handler, 1)

old_scroll = '''                            child: SingleChildScrollView(
                              key: ValueKey<String>(
                                'v2-organization-management-scroll-${_managementArea?.name ?? 'default'}',
                              ),
                              controller: _managementScrollController,
'''
new_scroll = '''                            child: SingleChildScrollView(
                              key: const Key('v2-organization-management-scroll'),
                              controller: _managementScrollController,
'''
if text.count(old_scroll) != 1:
    raise SystemExit('area-keyed management scroll not found')
text = text.replace(old_scroll, new_scroll, 1)
organization_path.write_text(text, encoding='utf-8')

# Update the generated source contract to describe the stable subtree + manual
# offset restoration rather than the rejected area-keyed subtree replacement.
contract_path = Path('test/features/windows_organization_navigation_contract_test.dart')
contract = contract_path.read_text(encoding='utf-8')
old_contract = '''    expect(organization, contains('_managementScrollControllers'));
    expect(
      organization,
      contains(r"v2-organization-management-scroll-${_managementArea?.name ?? 'default'}"),
    );
'''
new_contract = '''    expect(organization, contains('_managementScrollControllers'));
    expect(organization, contains('_managementScrollOffsets'));
    expect(
      organization,
      contains("Key('v2-organization-management-scroll')"),
    );
    expect(organization, contains('_rememberManagementScrollOffset'));
    expect(organization, contains('_restoreManagementScrollOffset'));
'''
if contract.count(old_contract) != 1:
    raise SystemExit('generated scroll source contract not found')
contract = contract.replace(old_contract, new_contract, 1)
contract_path.write_text(contract, encoding='utf-8')

# Keep the behavior test on one stable Scrollable subtree and compare the
# controller attached to that subtree for each active area.
test_path = Path('test/features/v2_organization_workspace_test.dart')
test = test_path.read_text(encoding='utf-8')
test = test.replace(
    "        const ValueKey<String>('v2-organization-management-scroll-people'),\n",
    "        const Key('v2-organization-management-scroll'),\n",
    1,
)
test = test.replace(
    "        const ValueKey<String>('v2-organization-management-scroll-settings'),\n",
    "        const Key('v2-organization-management-scroll'),\n",
    1,
)
# The people finder remains valid after returning because the subtree key is stable.
test_path.write_text(test, encoding='utf-8')
