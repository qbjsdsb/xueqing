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
  });
}
