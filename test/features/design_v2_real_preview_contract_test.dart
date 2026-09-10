import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real V2 preview uses controlled repositories and remains dev-only', () {
    final entry = File(
      'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final runtime = File(
      'lib/features/teacher_workspace/workspace_runtime.dart',
    ).readAsStringSync();
    final preview = File('lib/features/design_v2/v2_real_preview_page.dart')
        .readAsStringSync();
    final loader = File('lib/features/design_v2/v2_workspace_loader.dart')
        .readAsStringSync();
    final workspace = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();

    expect(entry, contains('AuthenticatedWorkspaceRuntime('));
    expect(entry, contains('organizationManagementRepository:'));
    expect(entry, contains('teacherLearningRecordRepository:'));
    expect(entry, contains('studentLearningRecordRepository:'));
    expect(runtime, contains('OrganizationManagementRepository?'));
    expect(runtime, contains('OrganizationMemberProvisioningRepository?'));
    expect(runtime, contains('TeacherLearningRecordRepository?'));
    expect(runtime, contains('StudentLearningRecordRepository?'));
    expect(runtime, contains('UpdateService updateService'));
    expect(runtime, contains('UpdateInstaller updateInstaller'));
    expect(runtime, contains('CaseReopenDraftStore caseReopenDraftStore'));
    expect(runtime, contains('String appVersion'));
    expect(runtime, isNot(contains('final AuthRepository')));
    expect(
      runtime,
      isNot(contains('final OrganizationMemberLifecycleRepository')),
    );
    expect(
      RegExp(r'case AppRoutes\.v2RealPreview:').allMatches(router).length,
      2,
    );
    expect(router, contains('V2RealPreviewPage(runtime: runtime)'));
    expect(preview, contains('V2WorkspaceLoader('));
    expect(preview, contains('runtime: runtime'));
    expect(preview, isNot(contains('quickCapture(')));
    expect(preview, isNot(contains('recordProgress(')));
    expect(loader, contains('widget.runtime?.learningRepository'));
    expect(loader, contains('V2WorkflowController('));
    expect(loader, contains('Future<void> _softRefresh()'));
    expect(loader, contains('onRefresh: _softRefresh'));
    expect(loader, contains('onChanged: () => unawaited(_softRefresh())'));
    expect(loader, contains(': () => unawaited(_softRefresh())'));
    expect(workspace, contains("initialDraft?.state['operation_id']"));
    expect(
      workspace,
      contains("initialDraft?.state['photo_evidence_operation_id']"),
    );
    expect(workspace, contains('storedOperationId.trim().isNotEmpty'));
    expect(workspace, contains('storedPhotoOperationId.trim().isNotEmpty'));
    expect(workspace, contains(': createOperationId();'));
    expect(workspace, contains('await controller.quickCapture('));
    expect(workspace, contains('await controller.recordProgress('));
    expect(workspace, contains('widget.repository.listForEvidence('));
    expect(workspace, contains('widget.evidenceId'));
    expect(workspace, contains('createSignedUrl(attachment.storagePath)'));
  });
}
