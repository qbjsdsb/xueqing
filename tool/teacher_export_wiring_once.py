from pathlib import Path


def replace(path: str, old: str, new: str) -> None:
    target = Path(path)
    text = target.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'missing anchor in {path}: {old[:120]!r}')
    target.write_text(text.replace(old, new, 1), encoding='utf-8')


workspace = 'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart'
replace(
    workspace,
    "import '../../../cloud/progressive_case_repository.dart';\n",
    "import '../../../cloud/progressive_case_repository.dart';\n"
    "import '../../../cloud/teacher_learning_record_repository.dart';\n",
)
replace(
    workspace,
    "    this.organizationMemberLifecycleRepository,\n    this.caseReopenDraftStore,",
    "    this.organizationMemberLifecycleRepository,\n"
    "    this.teacherLearningRecordRepository,\n"
    "    this.caseReopenDraftStore,",
)
replace(
    workspace,
    "  final OrganizationMemberLifecycleRepository?\n"
    "  organizationMemberLifecycleRepository;\n"
    "  final CaseReopenDraftStore? caseReopenDraftStore;",
    "  final OrganizationMemberLifecycleRepository?\n"
    "  organizationMemberLifecycleRepository;\n"
    "  final TeacherLearningRecordRepository? teacherLearningRecordRepository;\n"
    "  final CaseReopenDraftStore? caseReopenDraftStore;",
)
replace(
    workspace,
    "  OrganizationMemberLifecycleRepository? _organizationMemberLifecycleRepository;\n"
    "  String? _errorMessage;",
    "  OrganizationMemberLifecycleRepository? _organizationMemberLifecycleRepository;\n"
    "  TeacherLearningRecordRepository? _teacherLearningRecordRepository;\n"
    "  String? _errorMessage;",
)
replace(
    workspace,
    "      _organizationMemberLifecycleRepository =\n"
    "          widget.organizationMemberLifecycleRepository;\n"
    "    } else {",
    "      _organizationMemberLifecycleRepository =\n"
    "          widget.organizationMemberLifecycleRepository;\n"
    "      _teacherLearningRecordRepository =\n"
    "          widget.teacherLearningRecordRepository;\n"
    "    } else {",
)
replace(
    workspace,
    "      _organizationMemberLifecycleRepository =\n"
    "          SupabaseOrganizationMemberLifecycleRepository(CloudClient.client);\n"
    "    }",
    "      _organizationMemberLifecycleRepository =\n"
    "          SupabaseOrganizationMemberLifecycleRepository(CloudClient.client);\n"
    "      _teacherLearningRecordRepository =\n"
    "          SupabaseTeacherLearningRecordRepository(CloudClient.client);\n"
    "    }",
)
replace(
    workspace,
    "          invitationAcceptanceRepository: _invitationAcceptanceRepository,\n"
    "          updateService: _updateService,",
    "          invitationAcceptanceRepository: _invitationAcceptanceRepository,\n"
    "          teacherLearningRecordRepository: _teacherLearningRecordRepository,\n"
    "          updateService: _updateService,",
)
replace(
    workspace,
    "    this.invitationAcceptanceRepository,\n    this.updateService,",
    "    this.invitationAcceptanceRepository,\n"
    "    this.teacherLearningRecordRepository,\n"
    "    this.updateService,",
)
replace(
    workspace,
    "  final OrganizationInvitationAcceptanceRepository?\n"
    "  invitationAcceptanceRepository;\n"
    "  final UpdateService? updateService;",
    "  final OrganizationInvitationAcceptanceRepository?\n"
    "  invitationAcceptanceRepository;\n"
    "  final TeacherLearningRecordRepository? teacherLearningRecordRepository;\n"
    "  final UpdateService? updateService;",
)
replace(
    workspace,
    "      provisioningRepository: widget.memberProvisioningRepository,\n"
    "      organizationId: organizationId,",
    "      provisioningRepository: widget.memberProvisioningRepository,\n"
    "      teacherLearningRecordRepository: widget.teacherLearningRecordRepository,\n"
    "      organizationId: organizationId,",
)

page = 'lib/features/organization_management/presentation/organization_management_page.dart'
replace(
    page,
    "import '../../../cloud/organization_member_provisioning_repository.dart';\n",
    "import '../../../cloud/organization_member_provisioning_repository.dart';\n"
    "import '../../../cloud/teacher_learning_record_repository.dart';\n"
    "import '../../../export/learning_record_export.dart';\n",
)
replace(
    page,
    "    this.provisioningRepository,\n    super.key,",
    "    this.provisioningRepository,\n"
    "    this.teacherLearningRecordRepository,\n"
    "    super.key,",
)
replace(
    page,
    "  final OrganizationMemberProvisioningRepository? provisioningRepository;\n",
    "  final OrganizationMemberProvisioningRepository? provisioningRepository;\n"
    "  final TeacherLearningRecordRepository? teacherLearningRecordRepository;\n",
)
replace(
    page,
    "                  final canEditMemberName =\n"
    "                      hasProvisioningRepository &&\n"
    "                      widget.roles.any(\n"
    "                        (role) => role == 'org_owner' || role == 'org_admin',\n"
    "                      );\n"
    "                  return Column(",
    "                  final canEditMemberName =\n"
    "                      hasProvisioningRepository &&\n"
    "                      widget.roles.any(\n"
    "                        (role) => role == 'org_owner' || role == 'org_admin',\n"
    "                      );\n"
    "                  final canExportTeacherRecords =\n"
    "                      widget.teacherLearningRecordRepository != null &&\n"
    "                      widget.roles.any(\n"
    "                        (role) => role == 'org_owner' || role == 'org_admin',\n"
    "                      );\n"
    "                  return Column(",
)
replace(
    page,
    "                        onInviteMember: _inviteMember,\n"
    "                        onApprove: _approveInvitation,",
    "                        onInviteMember: _inviteMember,\n"
    "                        onExportTeacherRecords: canExportTeacherRecords\n"
    "                            ? _exportTeacherRecords\n"
    "                            : null,\n"
    "                        onApprove: _approveInvitation,",
)

areas = 'lib/features/organization_management/presentation/organization_management_areas.dart'
replace(
    areas,
    "    this.onProvisionInvitation,\n    this.onEditMemberName,",
    "    this.onProvisionInvitation,\n"
    "    this.onExportTeacherRecords,\n"
    "    this.onEditMemberName,",
)
replace(
    areas,
    "  final VoidCallback onInviteMember;\n"
    "  final Future<void> Function(OrganizationInvitation invitation) onApprove;",
    "  final VoidCallback onInviteMember;\n"
    "  final Future<void> Function()? onExportTeacherRecords;\n"
    "  final Future<void> Function(OrganizationInvitation invitation) onApprove;",
)
old_action = """            action: widget.canInvite
                ? FilledButton.tonalIcon(
                    onPressed: widget.busy ? null : widget.onInviteMember,
                    icon: const Icon(Icons.group_add_outlined, size: 18),
                    label: const Text('邀请成员'),
                  )
                : null,"""
new_action = """            action: widget.canInvite || widget.onExportTeacherRecords != null
                ? Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (widget.onExportTeacherRecords != null)
                        OutlinedButton.icon(
                          onPressed: widget.busy
                              ? null
                              : widget.onExportTeacherRecords,
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('导出老师记录'),
                        ),
                      if (widget.canInvite)
                        FilledButton.tonalIcon(
                          onPressed: widget.busy ? null : widget.onInviteMember,
                          icon: const Icon(Icons.group_add_outlined, size: 18),
                          label: const Text('邀请成员'),
                        ),
                    ],
                  )
                : null,"""
replace(areas, old_action, new_action)

actions = 'lib/features/organization_management/presentation/organization_management_learning_actions.dart'
anchor = "mixin _OrganizationManagementLearningActions on _OrganizationManagementCore {\n"
method = r'''mixin _OrganizationManagementLearningActions on _OrganizationManagementCore {
  Future<void> _exportTeacherRecords() async {
    if (_busy) return;
    final repository = widget.teacherLearningRecordRepository;
    if (repository == null) return;

    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) return;
      final teachers = snapshot.members
          .where((member) => member.roles.contains('teacher'))
          .toList(growable: false)
        ..sort(
          (left, right) =>
              _teacherExportName(left).compareTo(_teacherExportName(right)),
        );
      if (teachers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前没有可导出的老师记录。')),
        );
        return;
      }

      final teacher = await showDialog<OrganizationMember>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('选择要导出的老师'),
          children: [
            for (final member in teachers)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(member),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _teacherExportName(member),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        member.email,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
      if (!mounted || teacher == null) return;

      setState(() {
        _busy = true;
        _errorMessage = null;
      });
      final records = await repository.listTeacherRecords(
        organizationId: widget.organizationId,
        membershipId: teacher.membershipId,
      );
      if (!mounted) return;
      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_teacherExportName(teacher)} 还没有可导出的教学记录。'),
          ),
        );
        return;
      }

      final teacherName = _teacherExportName(teacher);
      final rows = LearningRecordExport.rowsForTeacherRecords(
        records,
        teacherName: teacherName,
      );
      final savedPath = await LearningRecordExport.saveAsXlsx(
        fileNameWithoutExtension: LearningRecordExport.teacherFileName(
          teacherName,
        ),
        rows: rows,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedPath == null ? '已取消导出。' : '$teacherName 的教学记录表已生成。',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = teacherLearningRecordExportErrorMessage(error) ??
            '导出失败，请检查网络和账号状态后重试。';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _teacherExportName(OrganizationMember member) {
    final displayName = member.displayName?.trim() ?? '';
    if (displayName.isNotEmpty &&
        displayName.toLowerCase() != member.email.trim().toLowerCase()) {
      return displayName;
    }
    return member.email.trim().isEmpty ? '未命名老师' : member.email.trim();
  }
'''
replace(actions, anchor, method)
