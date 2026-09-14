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
  test('top-level headers stay quieter than entity detail headlines', () {
    final header = File('lib/features/design_v2/v2_page_header.dart')
        .readAsStringSync();
    expect(header, contains('theme.textTheme.titleLarge'));
    expect(header, contains('fontSize: 22'));
    expect(
      header,
      isNot(contains('Text(title, style: theme.textTheme.headlineSmall)')),
    );

    final management = File(
      'lib/features/organization_management/presentation/organization_management_layout.dart',
    ).readAsStringSync();
    final managementHeader = _slice(
      management,
      'class _ManagementHeader',
      'class _ManagementToolbar',
    );
    expect(managementHeader, contains('textTheme.titleLarge'));
    expect(managementHeader, contains('copyWith(fontSize: 22, height: 1.35)'));
    expect(managementHeader, isNot(contains('textTheme.headlineSmall')));
  });

  test('sections and rows use a denser editorial hierarchy', () {
    final workspace = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();

    final sectionTitle = _slice(
      workspace,
      'class _SectionTitle',
      'class _FocusRow',
    );
    expect(sectionTitle, contains('textTheme.titleMedium'));
    expect(sectionTitle, contains('textTheme.labelMedium'));
    expect(sectionTitle, isNot(contains('textTheme.titleLarge')));

    final studentRow = _slice(
      workspace,
      'class _StudentRow',
      'class _InitialMark',
    );
    expect(
      studentRow,
      contains('EdgeInsets.symmetric(horizontal: 12, vertical: 10)'),
    );

    final focusRow = _slice(workspace, 'class _FocusRow', 'class _Timeline');
    expect(focusRow, contains('EdgeInsets.symmetric(vertical: 12)'));
    expect(focusRow, contains('height: 52'));

    final todayAction = _slice(
      workspace,
      'class _TodayAction',
      'String _todayActionStatus',
    );
    expect(todayAction, contains('EdgeInsets.symmetric(vertical: 12)'));
    expect(todayAction, contains('height: 56'));
  });
}
