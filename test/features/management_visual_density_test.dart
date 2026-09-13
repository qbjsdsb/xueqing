import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Organization Management keeps rows and metadata visually quiet', () {
    final areas = File(
      'lib/features/organization_management/presentation/'
      'organization_management_areas.dart',
    ).readAsStringSync();
    final rows = File(
      'lib/features/organization_management/presentation/'
      'organization_management_rows.dart',
    ).readAsStringSync();
    final layout = File(
      'lib/features/organization_management/presentation/'
      'organization_management_layout.dart',
    ).readAsStringSync();

    expect(
      areas,
      isNot(contains('colorScheme.primaryContainer.withValues(alpha: 0.32)')),
    );
    expect(areas, contains('BorderSide(color: colorScheme.primary, width: 2)'));

    expect(
      rows,
      isNot(contains('backgroundColor: colorScheme.primaryContainer')),
    );
    expect(
      rows,
      contains(
        'border: Border(bottom: BorderSide(color: colorScheme.outlineVariant))',
      ),
    );

    final roleChipStart = rows.indexOf('class _ManagementRoleChip');
    final statusChipStart = rows.indexOf('class _ManagementStatusChip');
    expect(roleChipStart, greaterThanOrEqualTo(0));
    expect(statusChipStart, greaterThan(roleChipStart));

    final roleBlock = rows.substring(roleChipStart, statusChipStart);
    final statusBlock = rows.substring(statusChipStart);
    expect(roleBlock, isNot(contains('return Chip(')));
    expect(statusBlock, isNot(contains('return Chip(')));
    expect(roleBlock, contains('AppRadii.small'));
    expect(statusBlock, contains('AppRadii.small'));

    final areaCardStart = layout.indexOf('class _ManagementAreaCard');
    final sectionStart = layout.indexOf('class _ManagementSection');
    expect(areaCardStart, greaterThanOrEqualTo(0));
    expect(sectionStart, greaterThan(areaCardStart));
    final areaCardBlock = layout.substring(areaCardStart, sectionStart);
    expect(
      areaCardBlock,
      contains('Widget build(BuildContext context) => child;'),
    );
    expect(areaCardBlock, isNot(contains('Divider(')));
    expect(areaCardBlock, isNot(contains('description')));

    expect(layout, contains('class _ManagementToolbar'));
    expect(layout, contains("tooltip: '导出记录'"));
    expect(layout, contains("label: const Text('导出记录')"));
  });
}
