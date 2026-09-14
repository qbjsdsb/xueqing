import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows Organization rail exposes direct peer destinations', () {
    final workspace = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();
    final organization = File(
      'lib/features/design_v2/v2_organization_workspace_page.dart',
    ).readAsStringSync();
    final navigation = File(
      'lib/features/design_v2/v2_workspace_navigation.dart',
    ).readAsStringSync();
    final areas = File(
      'lib/features/organization_management/presentation/organization_management_areas.dart',
    ).readAsStringSync();

    expect(workspace, contains("Key('v2-rail-organization-people')"));
    expect(workspace, contains("Key('v2-rail-organization-students')"));
    expect(workspace, contains("Key('v2-rail-organization-settings')"));
    expect(workspace, contains("Key('v2-workspace-more')"));
    expect(workspace, contains('width: expandedRail ? 192 : 72'));
    expect(workspace, contains('SingleChildScrollView('));
    expect(organization, contains('showAreaSwitcher: showAreaSwitcher'));
    expect(organization, contains('_embeddedSectionTitle'));
    expect(navigation, contains('enum OrganizationManagementArea'));
    expect(workspace, isNot(contains('organization_management_page.dart')));
    expect(organization, contains('_managementScrollControllers'));
    expect(organization, contains('_managementScrollOffsets'));
    expect(organization, contains("'v2-organization-management-scroll'"));
    expect(organization, contains('_rememberManagementScrollOffset'));
    expect(organization, contains('_restoreManagementScrollOffset'));
    expect(
      areas,
      contains(
        'OrganizationManagementArea.people => widget.onExportTeacherRecords',
      ),
    );
    expect(
      areas,
      contains(
        'OrganizationManagementArea.students => widget.onExportStudentRecords',
      ),
    );
    expect(areas, contains('OrganizationManagementArea.settings => null'));
  });
}
