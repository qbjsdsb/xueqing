import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/layout/responsive.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../cloud/learning_repository.dart';
import '../../../cloud/organization_management_repository.dart';
import '../../../cloud/organization_member_provisioning_repository.dart';
import 'organization_student_edit_dialog.dart';
import 'organization_student_setup_dialog.dart';
import 'organization_student_teacher_assignment_transfer_dialog.dart';
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
        return Padding(
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
                busy: _busy,
                canInvite: _inviteRoles.isNotEmpty,
                canManageCaseTypes:
                    widget.canManageCaseTypes && widget.onOpenCaseTypes != null,
                onAddStudent: _addStudent,
                onInviteMember: _inviteMember,
                onAddSubject: _addSubject,
                onAddTeacherScope: _addTeacherScope,
                onOpenCaseTypes: widget.onOpenCaseTypes,
              ),
              const _ManagementBoundaryBanner(),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ManagementErrorText(message: _errorMessage!),
              ],
              const SizedBox(height: AppSpacing.lg),
              FutureBuilder<_OrganizationManagementSnapshot>(
                future: _snapshotFuture,
                builder: (context, snapshotState) {
                  if (snapshotState.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshotState.hasError || !snapshotState.hasData) {
                    return _ManagementErrorState(onRetry: _retryLoad);
                  }
                  return _ManagementOverview(
                    snapshot: snapshotState.data!,
                    isOwner: _isOwner,
                    busy: _busy,
                    canEditMemberName: widget.provisioningRepository != null,
                    onApprove: _approveInvitation,
                    onRevoke: _revokeInvitation,
                    onProvisionInvitation: widget.provisioningRepository == null
                        ? null
                        : _provisionExistingInvitation,
                    onEditMemberName: widget.provisioningRepository == null
                        ? null
                        : _editMemberDisplayName,
                    onEditStudent: _editStudent,
                    onToggleMemberStatus: _toggleMemberStatus,
                    onReissueMemberCredential:
                        widget.provisioningRepository == null
                        ? null
                        : _reissueMemberCredential,
                    onAddTeacherScope: _addTeacherScope,
                    onToggleTeacherScope: _toggleTeacherScope,
                    onTransferStudentTeacherAssignment:
                        _transferStudentTeacherAssignment,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
