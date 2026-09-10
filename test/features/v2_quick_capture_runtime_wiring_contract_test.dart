import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production authenticated V2 wires durable quick-capture recovery', () {
    final entry = File(
      'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    ).readAsStringSync();
    final runtime = File(
      'lib/features/teacher_workspace/workspace_runtime.dart',
    ).readAsStringSync();
    final loader = File('lib/features/design_v2/v2_workspace_loader.dart')
        .readAsStringSync();
    final preview = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();

    expect(entry, contains('SecureComposerDraftStore()'));
    expect(entry, contains('composerDraftStore: _composerDraftStore'));
    expect(runtime, contains('final ComposerDraftStore? composerDraftStore;'));
    expect(loader, contains('quickCaptureComposerScopeKey('));
    expect(loader, contains('organizationId: workspace.organizationId'));
    expect(preview, contains('_restoreComposerDraft'));
    expect(preview, contains("draft.kind == 'quick_capture'"));
    expect(preview, contains("draft.kind == 'progress'"));
    expect(preview, contains('initialDraft: draft'));
  });
}
