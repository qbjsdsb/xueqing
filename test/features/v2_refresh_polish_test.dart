import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2 exposes explicit refresh without widening data access', () {
    final loader = File('lib/features/design_v2/v2_workspace_loader.dart')
        .readAsStringSync();
    final preview = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();
    final management = File(
      'lib/features/organization_management/presentation/'
      'organization_management_layout.dart',
    ).readAsStringSync();

    expect(loader, contains('Future<void> _softRefresh()'));
    expect(loader, contains('onRefresh: _softRefresh'));
    expect(loader, contains('当前页面和已保存记录不会受影响'));
    expect(preview, contains("Key('v2-workspace-refresh')"));
    expect(preview, contains("Key('v2-menu-refresh')"));
    expect(preview, contains("title: Text(_refreshing ? '正在刷新' : '刷新学情')"));
    expect(management, contains("Key('management-refresh')"));
  });

  test('V2 visual system stays quiet and editorial', () {
    final preview = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();
    final theme = File('lib/features/design_v2/v2_theme.dart')
        .readAsStringSync();
    final spacing = File('lib/app/theme/app_spacing.dart').readAsStringSync();

    expect(preview, isNot(contains('Icons.eco_outlined')));
    expect(preview, contains("'学情'"));
    expect(preview, contains("title: const Text('更多')"));
    expect(theme, contains("import '../../app/theme/app_theme.dart';"));
    expect(theme, contains('AppTheme.dark()'));
    expect(theme, contains('AppTheme.light()'));
    expect(
      theme,
      contains('minimumSize: const Size(0, AppSpacing.touchTarget)'),
    );
    expect(theme, contains('height: 68'));
    expect(spacing, contains('static const dialog = 16.0;'));
  });
}
