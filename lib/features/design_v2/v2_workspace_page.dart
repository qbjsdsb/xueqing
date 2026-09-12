import 'package:flutter/material.dart';

import '../../cloud/cloud_client.dart';
import '../../cloud/responsibility_read_repository.dart';
import '../../cloud/responsibility_scoped_learning_repository.dart';
import '../teacher_workspace/workspace_runtime.dart';
import 'v2_theme.dart';
import 'v2_workspace_loader.dart';

/// Production host for the V2 teacher workspace.
///
/// Authentication, onboarding, membership state and disabled-account gates
/// remain owned by TeacherWorkspaceEntryPage. This page starts only after the
/// authenticated runtime has been established and therefore contains no
/// second auth or authorization lifecycle.
class V2WorkspacePage extends StatelessWidget {
  const V2WorkspacePage({
    required this.runtime,
    this.responsibilityReadRepository,
    this.responsibilityWriteRepository,
    super.key,
  });

  final AuthenticatedWorkspaceRuntime runtime;

  /// Injectable for widget tests. Normal cloud-backed runtime uses the same
  /// already-initialized Supabase client as the existing workspace repository.
  final ResponsibilityReadRepository? responsibilityReadRepository;
  final ResponsibilityWriteRepository? responsibilityWriteRepository;

  @override
  Widget build(BuildContext context) {
    final workspaceTheme = Theme.of(context).brightness == Brightness.dark
        ? V2Theme.dark()
        : V2Theme.light();
    final responsibilityRepository =
        responsibilityReadRepository ??
        (CloudClient.isInitialized
            ? SupabaseResponsibilityReadRepository(CloudClient.client)
            : null);
    final responsibilityWriter =
        responsibilityWriteRepository ??
        (CloudClient.isInitialized
            ? SupabaseResponsibilityWriteRepository(CloudClient.client)
            : null);

    final responsibilityGateway =
        responsibilityRepository != null && responsibilityWriter != null
        ? ResponsibilityScopedLearningRepository(
            runtime.learningRepository,
            responsibilityRepository,
            responsibilityWriter,
          )
        : null;
    final effectiveRuntime = responsibilityGateway == null
        ? runtime
        : _runtimeWithLearningRepository(runtime, responsibilityGateway);
    final effectiveResponsibilityRepository =
        responsibilityGateway ?? responsibilityRepository;

    return Theme(
      data: workspaceTheme,
      child: V2WorkspaceLoader(
        loadWorkspace: effectiveRuntime.learningRepository.loadWorkspace,
        responsibilityReadRepository: effectiveResponsibilityRepository,
        runtime: effectiveRuntime,
      ),
    );
  }
}

AuthenticatedWorkspaceRuntime _runtimeWithLearningRepository(
  AuthenticatedWorkspaceRuntime source,
  ResponsibilityScopedLearningRepository learningRepository,
) {
  return AuthenticatedWorkspaceRuntime(
    learningRepository: learningRepository,
    progressiveCaseRepository: source.progressiveCaseRepository,
    evidenceAttachmentRepository: source.evidenceAttachmentRepository,
    organizationManagementRepository: source.organizationManagementRepository,
    invitationAcceptanceRepository: source.invitationAcceptanceRepository,
    memberProvisioningRepository: source.memberProvisioningRepository,
    teacherLearningRecordRepository: source.teacherLearningRecordRepository,
    studentLearningRecordRepository: source.studentLearningRecordRepository,
    composerDraftStore: source.composerDraftStore,
    updateService: source.updateService,
    updateInstaller: source.updateInstaller,
    caseReopenDraftStore: source.caseReopenDraftStore,
    appVersion: source.appVersion,
    sessionUserId: source.sessionUserId,
    onSignOut: source.onSignOut,
  );
}
