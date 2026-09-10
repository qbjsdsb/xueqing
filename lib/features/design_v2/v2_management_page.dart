import 'package:flutter/material.dart';

import '../../cloud/learning_repository.dart';
import '../organization_management/presentation/organization_management_page.dart';
import '../teacher_workspace/presentation/teacher_workspace_page.dart';
import '../teacher_workspace/workspace_runtime.dart';
import 'v2_update_flow.dart';

class V2ManagementPage extends StatefulWidget {
  const V2ManagementPage({
    required this.workspace,
    required this.runtime,
    this.rootMode = false,
    this.onChanged,
    this.onRefresh,
    super.key,
  });

  final TeacherWorkspace workspace;
  final AuthenticatedWorkspaceRuntime runtime;
  final bool rootMode;
  final VoidCallback? onChanged;
  final Future<void> Function()? onRefresh;

  @override
  State<V2ManagementPage> createState() => _V2ManagementPageState();
}

class _V2ManagementPageState extends State<V2ManagementPage> {
  bool _checkingForUpdates = false;
  bool _refreshing = false;

  Future<void> _refresh() async {
    final refresh = widget.onRefresh;
    if (refresh == null || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      await refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已刷新最新数据。')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('刷新失败，请检查网络后重试。')));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _checkForUpdates() async {
    if (_checkingForUpdates) return;
    setState(() => _checkingForUpdates = true);
    try {
      await runV2UpdateFlow(
        context,
        service: widget.runtime.updateService,
        installer: widget.runtime.updateInstaller,
      );
    } finally {
      if (mounted) setState(() => _checkingForUpdates = false);
    }
  }

  Future<void> _openCaseTypes() async {
    final organizationId = widget.workspace.organizationId;
    if (organizationId == null || !widget.workspace.canManageCaseTypes) {
      return;
    }
    final manager = WorkspaceCaseTypeManager(
      organizationId: organizationId,
      caseTypes: widget.workspace.caseTypes,
      repository: widget.runtime.learningRepository,
      onChanged: () async {
        widget.onChanged?.call();
      },
    );
    if (MediaQuery.sizeOf(context).width < 720) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        builder: (_) => manager,
      );
    } else {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(child: manager),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizationId = widget.workspace.organizationId;
    final repository = widget.runtime.organizationManagementRepository;
    if (organizationId == null || repository == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: Text('当前账号没有可用的机构管理权限。'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.rootMode,
        title: Text('机构管理 · ${widget.workspace.organizationName}'),
        actions: [
          if (widget.onRefresh != null)
            IconButton(
              key: const Key('v2-management-refresh'),
              tooltip: _refreshing ? '正在刷新' : '刷新数据',
              onPressed: _refreshing ? null : _refresh,
              icon: _refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          if (_checkingForUpdates)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: '检查更新',
              onPressed: _checkForUpdates,
              icon: const Icon(Icons.system_update_alt_outlined),
            ),
          if (widget.rootMode && widget.runtime.onSignOut != null)
            IconButton(
              tooltip: '退出登录',
              onPressed: widget.runtime.onSignOut,
              icon: const Icon(Icons.logout_outlined),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: OrganizationManagementPage(
            repository: repository,
            provisioningRepository: widget.runtime.memberProvisioningRepository,
            teacherLearningRecordRepository:
                widget.runtime.teacherLearningRecordRepository,
            studentLearningRecordRepository:
                widget.runtime.studentLearningRecordRepository,
            organizationId: organizationId,
            organizationName: widget.workspace.organizationName,
            roles: widget.workspace.roles,
            canManageCaseTypes: widget.workspace.canManageCaseTypes,
            onOpenCaseTypes: widget.workspace.canManageCaseTypes
                ? () {
                    _openCaseTypes();
                  }
                : null,
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
  }
}
