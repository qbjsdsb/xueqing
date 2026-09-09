import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real V2 preview uses controlled repositories and remains dev-only', () {
    final entry = File(
      'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final preview = File('lib/features/design_v2/v2_real_preview_page.dart')
        .readAsStringSync();
    final loader = File('lib/features/design_v2/v2_workspace_loader.dart')
        .readAsStringSync();
    final workspace = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();

    expect(
      entry,
      contains('ProgressiveCaseRepository? progressiveCaseRepository'),
    );
    expect(
      entry,
      contains('EvidenceAttachmentRepository? evidenceAttachmentRepository'),
    );
    expect(
      RegExp(r'case AppRoutes\.v2RealPreview:').allMatches(router).length,
      2,
    );
    expect(
      router,
      contains('progressiveCaseRepository: progressiveCaseRepository'),
    );
    expect(
      router,
      contains('evidenceAttachmentRepository: evidenceAttachmentRepository'),
    );
    expect(preview, contains('V2WorkspaceLoader('));
    expect(preview, isNot(contains('quickCapture(')));
    expect(preview, isNot(contains('recordProgress(')));
    expect(loader, contains('V2WorkflowController('));
    expect(
      loader,
      contains(
        'onWorkspaceChanged: workflowController == null ? null : _retry',
      ),
    );
    expect(
      workspace,
      contains('operationId = controller == null ? null : createOperationId()'),
    );
    expect(workspace, contains('await controller.quickCapture('));
    expect(workspace, contains('await controller.recordProgress('));
    expect(workspace, contains('widget.repository.listForEvidence('));
    expect(workspace, contains('widget.evidenceId'));
    expect(workspace, contains('createSignedUrl(attachment.storagePath)'));
  });
}
