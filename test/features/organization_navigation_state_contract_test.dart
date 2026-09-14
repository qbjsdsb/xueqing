import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Organization workspace owns the selected management area', () {
    final navigation = File(
      'lib/features/design_v2/v2_workspace_navigation.dart',
    ).readAsStringSync();
    final areas = File(
      'lib/features/organization_management/presentation/organization_management_areas.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/organization_management/presentation/organization_management_page.dart',
    ).readAsStringSync();
    final organization = File(
      'lib/features/design_v2/v2_organization_workspace_page.dart',
    ).readAsStringSync();

    expect(navigation, contains('enum OrganizationManagementArea'));
    expect(
      areas,
      contains('widget.initialArea ?? _initialArea(widget.snapshot)'),
    );
    expect(areas, contains('widget.onAreaChanged?.call(area)'));
    expect(page, contains('final OrganizationManagementArea? initialArea;'));
    expect(
      organization,
      contains('OrganizationManagementArea? _managementArea;'),
    );
    expect(organization, contains('initialArea: _managementArea'));
    expect(
      organization,
      contains('onAreaChanged: _handleManagementAreaChanged'),
    );
  });
}
