import 'package:flutter/widgets.dart';

import '../../cloud/case_reopen_draft_store.dart';
import '../../cloud/evidence_attachment_repository.dart';
import '../../cloud/learning_repository.dart';
import '../../cloud/organization_management_repository.dart';
import '../../cloud/organization_member_provisioning_repository.dart';
import '../../cloud/progressive_case_repository.dart';
import '../../cloud/student_learning_record_repository.dart';
import '../../cloud/teacher_learning_record_repository.dart';
import '../../update/update_installer.dart';
import '../../update/update_service.dart';

typedef AuthenticatedWorkspaceBuilder = Widget Function(
  BuildContext context,
  AuthenticatedWorkspaceRuntime runtime,
);

/// Capabilities that are safe to expose after the existing authentication,
/// onboarding, membership and disabled-account gates have all passed.
///
/// Identity/session repositories deliberately stay outside this object. V2
/// consumes business capabilities while TeacherWorkspaceEntryPage keeps the
/// authorization lifecycle boundary.
class AuthenticatedWorkspaceRuntime {
  const AuthenticatedWorkspaceRuntime({
    required this.learningRepository,
    required this.updateService,
    required this.updateInstaller,
    required this.caseReopenDraftStore,
    required this.appVersion,
    this.progressiveCaseRepository,
    this.evidenceAttachmentRepository,
    this.organizationManagementRepository,
    this.invitationAcceptanceRepository,
    this.memberProvisioningRepository,
    this.teacherLearningRecordRepository,
    this.studentLearningRecordRepository,
    this.sessionUserId,
    this.onSignOut,
  });

  final LearningRepository learningRepository;
  final ProgressiveCaseRepository? progressiveCaseRepository;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
  final OrganizationManagementRepository? organizationManagementRepository;
  final OrganizationInvitationAcceptanceRepository?
  invitationAcceptanceRepository;
  final OrganizationMemberProvisioningRepository? memberProvisioningRepository;
  final TeacherLearningRecordRepository? teacherLearningRecordRepository;
  final StudentLearningRecordRepository? studentLearningRecordRepository;
  final UpdateService updateService;
  final UpdateInstaller updateInstaller;
  final CaseReopenDraftStore caseReopenDraftStore;
  final String appVersion;
  final String? sessionUserId;
  final VoidCallback? onSignOut;
}
