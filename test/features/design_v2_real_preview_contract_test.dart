import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real V2 preview stays development-only and read-only by contract', () {
    final entry = File(
      'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final preview = File(
      'lib/features/design_v2/v2_real_preview_page.dart',
    ).readAsStringSync();

    expect(entry, contains('AuthenticatedWorkspaceBuilder'));
    expect(
      entry,
      contains(r"ValueKey('authenticated-workspace-$_activeUserId')"),
    );
    expect(
      RegExp(r'case AppRoutes\.v2RealPreview:').allMatches(router).length,
      2,
    );
    expect(router, contains('loadWorkspace: repository.loadWorkspace'));
    expect(preview, contains('final V2WorkspaceLoad loadWorkspace;'));
    expect(preview, isNot(contains('quickCapture(')));
    expect(preview, isNot(contains('recordProgress(')));
  });
}
