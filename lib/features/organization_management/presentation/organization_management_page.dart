import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/layout/responsive.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../cloud/evidence_attachment_repository.dart';
import '../../../cloud/learning_repository.dart';
import '../../../cloud/organization_management_repository.dart';
import '../../../cloud/organization_member_provisioning_repository.dart';
import '../../../cloud/student_learning_record_repository.dart';
import '../../../cloud/teacher_learning_record_repository.dart';
import '../../../export/learning_record_export.dart';
import '../../../export/learning_record_export_feedback.dart';
import 'organization_student_edit_dialog.dart';
import 'organization_student_record_export_dialog.dart';
import 'organization_student_setup_dialog.dart';
import 'organization_student_subject_restore_dialog.dart';
import 'organization_student_subject_setup_dialog.dart';
import 'organization_student_teacher_assignment_transfer_dialog.dart';
import 'organization_student_teacher_handoff_confirmation_dialog.dart';
import 'organization_subject_setup_dialog.dart';
import 'organization_teacher_subject_scope_dialog.dart';

part 'organization_management_core.dart';
part 'organization_management_learning_actions.dart';
part 'organization_management_member_actions.dart';
part 'organization_management_areas.dart';
part 'organization_management_layout.dart';
part 'organization_management_rows.dart';
part 'organization_management_dialogs.dart';
part 'organization_management_helpers.dart';

class OrganizationManagementPage extends StatefulWidget {
  const OrganizationManagementPage({
    required this.repository,
    required this.organizationId,
    required this.organizationName,
    required this.roles,
    this.canManageCaseTypes = false,
    this.onOpenCaseTypes,
    this.onChanged,
    this.provisioningRepository,
    this.evidenceAttachmentRepository,
    this.teacherLearningRecordRepository,
    this.studentLearningRecordRepository,
    this.showHeaderTitle = true,
    super.key,
  });

  final OrganizationManagementRepository repository;
  final String organizationId;
  final String organizationName;
  final List<String> roles;
  final bool canManageCaseTypes;
  final VoidCallback? onOpenCaseTypes;
  final VoidCallback? onChanged;
  final OrganizationMemberProvisioningRepository? provisioningRepository;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
  final TeacherLearningRecordRepository? teacherLearningRecordRepository;
  final StudentLearningRecordRepository? studentLearningRecordRepository;
  final bool showHeaderTitle;

  @override
  State<OrganizationManagementPage> createState() =>
      _OrganizationManagementPageState();
}

class _OrganizationManagementPageState extends State<OrganizationManagementPage>
    with
        _OrganizationManagementCore,
        _OrganizationManagementLearningActions,
        _OrganizationManagementMemberActions {
  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      builder: (context, sizeClass) {
        final horizontalPadding = switch (sizeClass) {
          WindowSizeClass.compact => AppSpacing.md,
          WindowSizeClass.medium => AppSpacing.lg,
          WindowSizeClass.expanded => AppSpacing.xl,
        };
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AppSpacing.md,
                  horizontalPadding,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ManagementHeader(
                      organizationName: widget.organizationName,
                      roleLabel: _roleSummary(widget.roles),
                      refreshing: _manualRefreshing,
                      onRefresh: _busy ? null : _manualRefresh,
                      showTitle: widget.showHeaderTitle,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _ManagementErrorText(message: _errorMessage!),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    FutureBuilder<_OrganizationManagementSnapshot>(
                      future: _snapshotFuture,
                      builder: (context, snapshotState) {
                        if (!snapshotState.hasData &&
                            snapshotState.connectionState !=
                                ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.xxl,
                            ),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshotState.hasError || !snapshotState.hasData) {
                          return _ManagementErrorState(onRetry: _retryLoad);
                        }
                        final hasProvisioningRepository =
                            widget.provisioningRepository != null;
                        final canManageMemberAccounts =
                            _isOwner && hasProvisioningRepository;
                        final canEditMemberName =
                            hasProvisioningRepository &&
                            widget.roles.any(
                              (role) =>
                                  role == 'org_owner' || role == 'org_admin',
                            );
                        final canExportTeacherRecords =
                            widget.teacherLearningRecordRepository != null &&
                            widget.roles.any(
                              (role) =>
                                  role == 'org_owner' || role == 'org_admin',
                            );
                        final canExportStudentRecords =
                            widget.studentLearningRecordRepository != null &&
                            widget.roles.any(
                              (role) =>
                                  role == 'org_owner' || role == 'org_admin',
                            );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 2,
                              child:
                                  snapshotState.connectionState !=
                                      ConnectionState.done
                                  ? const LinearProgressIndicator(minHeight: 2)
                                  : null,
                            ),
                            _ManagementOverview(
                              snapshot: snapshotState.data!,
                              isOwner: _isOwner,
                              busy: _busy,
                              canInvite: _inviteRoles.isNotEmpty,
                              canEditMemberName: canEditMemberName,
                              onAddStudent: _addStudent,
                              onAddStudentSubject: _addStudentSubject,
                              onToggleStudentSubjectService:
                                  _toggleStudentSubjectService,
                              onToggleStudentTeaching: _toggleStudentTeaching,
                              onToggleStudentArchive: _toggleStudentArchive,
                              onInviteMember: _inviteMember,
                              onExportTeacherRecords: canExportTeacherRecords
                                  ? _exportTeacherRecords
                                  : null,
                              onExportStudentRecords: canExportStudentRecords
                                  ? _exportStudentRecords
                                  : null,
                              onApprove: _approveInvitation,
                              onRevoke: _revokeInvitation,
                              onProvisionInvitation: canManageMemberAccounts
                                  ? _provisionExistingInvitation
                                  : null,
                              onEditMemberName: canEditMemberName
                                  ? _editMemberDisplayName
                                  : null,
                              onEditStudent: _editStudent,
                              onToggleMemberStatus: _toggleMemberStatus,
                              onReissueMemberCredential: canManageMemberAccounts
                                  ? _reissueMemberCredential
                                  : null,
                              onAddSubject: _addSubject,
                              onAddTeacherScope: _addTeacherScope,
                              onToggleTeacherScope: _toggleTeacherScope,
                              onTransferStudentTeacherAssignment:
                                  _transferStudentTeacherAssignment,
                              canManageCaseTypes:
                                  widget.canManageCaseTypes &&
                                  widget.onOpenCaseTypes != null,
                              onOpenCaseTypes: widget.onOpenCaseTypes,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
