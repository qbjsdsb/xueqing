import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _slice(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, greaterThanOrEqualTo(0), reason: 'Missing $start');
  expect(
    endIndex,
    greaterThan(startIndex),
    reason: 'Missing $end after $start',
  );
  return source.substring(startIndex, endIndex);
}

void main() {
  test('workspace structural panes share one quiet base surface', () {
    final workspace = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();

    final rail = _slice(
      workspace,
      'class _NavigationRail',
      'class _RailGroupLabel',
    );
    expect(rail, contains('color: scheme.surface,'));
    expect(rail, isNot(contains('surfaceContainerLowest')));

    final studentList = _slice(
      workspace,
      'class _StudentListPaneState',
      'class _StudentRow',
    );
    expect(studentList, contains('color: scheme.surface,'));
    expect(studentList, isNot(contains('surfaceContainerLowest')));
  });

  test('management utility cues use line and spacing before extra fills', () {
    final management = File(
      'lib/features/organization_management/presentation/organization_management_layout.dart',
    ).readAsStringSync();
    final managementAreas = File(
      'lib/features/organization_management/presentation/organization_management_areas.dart',
    ).readAsStringSync();

    final header = _slice(
      management,
      'class _ManagementHeader',
      'class _ManagementToolbar',
    );
    expect(header, contains('color: Colors.transparent,'));
    expect(header, isNot(contains('surfaceContainerLow')));

    final setupHint = _slice(
      management,
      'class _ManagementSetupHint',
      'class _ManagementEmptyState',
    );
    expect(setupHint, contains('color: Colors.transparent,'));
    expect(setupHint, isNot(contains('surfaceContainerLow')));

    final setupNextStep = _slice(
      managementAreas,
      'Widget? _buildSetupNextStep()',
      'OrganizationManagementArea _initialArea',
    );
    expect(
      setupNextStep,
      contains("key: const Key('management-setup-next-step')"),
    );
    expect(setupNextStep, contains('color: Colors.transparent,'));
    expect(setupNextStep, isNot(contains('surfaceContainerLow')));
    expect(setupNextStep, contains('FilledButton.tonal('));
  });
}
