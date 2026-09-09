from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old[:100]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


# Shared update UI flow: business verification/download/install remain in the
# existing UpdateService / UpdateInstaller implementation.
Path('lib/features/design_v2/v2_update_flow.dart').write_text(r'''import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../update/update_dialog.dart';
import '../../update/update_installer.dart';
import '../../update/update_service.dart';

Future<void> runV2UpdateFlow(
  BuildContext context, {
  required UpdateService service,
  required UpdateInstaller installer,
}) async {
  try {
    final result = await service.checkForUpdate();
    if (!context.mounted) return;

    final shouldInstall = await showDialog<bool>(
      context: context,
      builder: (_) => UpdateDialog(result: result),
    );
    if (shouldInstall != true || !context.mounted) return;

    final downloaded = await service.download(result);
    final installResult = await installer.install(downloaded);
    if (!context.mounted) return;
    if (installResult.shouldExit) {
      await SystemNavigator.pop();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已打开系统安装界面，请按提示完成更新。')),
    );
  } on UpdateException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  } on UpdateInstallException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新失败，请稍后重试。')),
      );
    }
  }
}
''', encoding='utf-8')

Path('lib/features/design_v2/v2_management_page.dart').write_text(r'''import 'package:flutter/material.dart';

import '../../cloud/learning_repository.dart';
import '../organization_management/presentation/organization_management_page.dart';
import '../teacher_workspace/workspace_runtime.dart';
import 'v2_update_flow.dart';

class V2ManagementPage extends StatefulWidget {
  const V2ManagementPage({
    required this.workspace,
    required this.runtime,
    this.rootMode = false,
    this.onChanged,
    super.key,
  });

  final TeacherWorkspace workspace;
  final AuthenticatedWorkspaceRuntime runtime;
  final bool rootMode;
  final VoidCallback? onChanged;

  @override
  State<V2ManagementPage> createState() => _V2ManagementPageState();
}

class _V2ManagementPageState extends State<V2ManagementPage> {
  bool _checkingForUpdates = false;

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

  @override
  Widget build(BuildContext context) {
    final organizationId = widget.workspace.organizationId;
    final repository = widget.runtime.organizationManagementRepository;
    if (organizationId == null || repository == null) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: Text('当前账号没有可用的机构管理权限。')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.rootMode,
        title: Text('机构管理 · ${widget.workspace.organizationName}'),
        actions: [
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
            canManageCaseTypes: false,
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
  }
}
''', encoding='utf-8')

loader = 'lib/features/design_v2/v2_workspace_loader.dart'
replace_once(
    loader,
    "import '../teacher_workspace/workspace_runtime.dart';\nimport 'v2_read_model_adapter.dart';\n",
    "import '../teacher_workspace/workspace_runtime.dart';\nimport 'v2_management_page.dart';\nimport 'v2_read_model_adapter.dart';\n",
)
replace_once(
    loader,
    '''        final workspace = snapshot.requireData;
        if (!workspace.hasTeachingAccess) {
          return const _V2LoaderStatus(
            icon: Icons.person_off_outlined,
            title: '暂时没有任课学情',
            message: '当前账号暂时没有可查看的任课学生；获得任课关系后，这里会自动出现。',
          );
        }

        final snapshotData = V2ReadModelAdapter.fromWorkspace(workspace);
''',
    '''        final workspace = snapshot.requireData;
        final runtime = widget.runtime;
        final canOpenManagement =
            workspace.canManageOrganization &&
            workspace.organizationId != null &&
            runtime?.organizationManagementRepository != null;
        final WidgetBuilder? managementPageBuilder = canOpenManagement
            ? (_) => V2ManagementPage(
                workspace: workspace,
                runtime: runtime!,
                onChanged: _retry,
              )
            : null;

        if (!workspace.hasTeachingAccess) {
          if (canOpenManagement) {
            return V2ManagementPage(
              workspace: workspace,
              runtime: runtime!,
              rootMode: true,
              onChanged: _retry,
            );
          }
          return const _V2LoaderStatus(
            icon: Icons.person_off_outlined,
            title: '暂时没有任课学情',
            message: '当前账号暂时没有可查看的任课学生；获得任课关系后，这里会自动出现。',
          );
        }

        final snapshotData = V2ReadModelAdapter.fromWorkspace(workspace);
''',
)
replace_once(
    loader,
    '''        return V2WorkspacePreview(
          data: snapshotData.workspaceData,
          workflowController: workflowController,
          evidenceAttachmentRepository: evidenceAttachmentRepository,
          onWorkspaceChanged: workflowController == null ? null : _retry,
        );
''',
    '''        return V2WorkspacePreview(
          data: snapshotData.workspaceData,
          workflowController: workflowController,
          evidenceAttachmentRepository: evidenceAttachmentRepository,
          managementPageBuilder: managementPageBuilder,
          updateService: runtime?.updateService,
          updateInstaller: runtime?.updateInstaller,
          appVersion: runtime?.appVersion,
          onSignOut: runtime?.onSignOut,
          onWorkspaceChanged: workflowController == null ? null : _retry,
        );
''',
)

preview = 'lib/features/design_v2/v2_workspace_preview.dart'
replace_once(
    preview,
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\n\nimport '../../update/update_installer.dart';\nimport '../../update/update_service.dart';\n",
)
replace_once(
    preview,
    "import 'v2_fixture.dart';\nimport 'v2_workflow_controller.dart';\n",
    "import 'v2_fixture.dart';\nimport 'v2_update_flow.dart';\nimport 'v2_workflow_controller.dart';\n",
)
replace_once(
    preview,
    '''    this.workflowController,
    this.evidenceAttachmentRepository,
    this.onWorkspaceChanged,
  });

  final V2WorkspaceData data;
  final V2WorkflowController? workflowController;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
  final VoidCallback? onWorkspaceChanged;
''',
    '''    this.workflowController,
    this.evidenceAttachmentRepository,
    this.managementPageBuilder,
    this.updateService,
    this.updateInstaller,
    this.appVersion,
    this.onSignOut,
    this.onWorkspaceChanged,
  });

  final V2WorkspaceData data;
  final V2WorkflowController? workflowController;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
  final WidgetBuilder? managementPageBuilder;
  final UpdateService? updateService;
  final UpdateInstaller? updateInstaller;
  final String? appVersion;
  final VoidCallback? onSignOut;
  final VoidCallback? onWorkspaceChanged;
''',
)
replace_once(
    preview,
    '''  bool _showCase = false;
''',
    '''  bool _showCase = false;
  bool _checkingForUpdates = false;
''',
)
replace_once(
    preview,
    '''  void _changeDestination(int value) {
    setState(() {
      _destination = value;
      _showCase = false;
    });
  }

  @override
''',
    '''  void _changeDestination(int value) {
    setState(() {
      _destination = value;
      _showCase = false;
    });
  }

  Future<void> _openManagement(BuildContext context) async {
    final builder = widget.managementPageBuilder;
    if (builder == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: builder),
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    final service = widget.updateService;
    final installer = widget.updateInstaller;
    if (service == null || installer == null || _checkingForUpdates) return;
    setState(() => _checkingForUpdates = true);
    try {
      await runV2UpdateFlow(context, service: service, installer: installer);
    } finally {
      if (mounted) setState(() => _checkingForUpdates = false);
    }
  }

  void _afterMenuClose(BuildContext menuContext, VoidCallback action) {
    Navigator.of(menuContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  Future<void> _showWorkspaceMenu(BuildContext context) async {
    Widget menu(BuildContext menuContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.managementPageBuilder != null)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('机构管理'),
                subtitle: const Text('成员、学生、学科与记录导出'),
                onTap: () => _afterMenuClose(
                  menuContext,
                  () => _openManagement(context),
                ),
              ),
            ListTile(
              leading: _checkingForUpdates
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update_alt_outlined),
              title: const Text('检查更新'),
              subtitle: widget.appVersion == null
                  ? null
                  : Text('当前版本 ${widget.appVersion}'),
              onTap: _checkingForUpdates ||
                      widget.updateService == null ||
                      widget.updateInstaller == null
                  ? null
                  : () => _afterMenuClose(
                      menuContext,
                      () => _checkForUpdates(context),
                    ),
            ),
            if (widget.onSignOut != null)
              ListTile(
                leading: const Icon(Icons.logout_outlined),
                title: const Text('退出登录'),
                onTap: () => _afterMenuClose(menuContext, widget.onSignOut!),
              ),
          ],
        ),
      ),
    );

    if (MediaQuery.sizeOf(context).width < 720) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: menu,
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('设置'),
          content: SizedBox(width: 390, child: menu(dialogContext)),
        ),
      );
    }
  }

  @override
''',
)
replace_once(
    preview,
    '''                    onOpenCase: _openCase,
                    onBackFromCase: _closeCase,
                  );
''',
    '''                    onOpenCase: _openCase,
                    onBackFromCase: _closeCase,
                    onOpenMore: () => _showWorkspaceMenu(context),
                  );
''',
)
replace_once(
    preview,
    '''                  onOpenCase: _openCase,
                  onBackFromCase: _closeCase,
                );
''',
    '''                  onOpenCase: _openCase,
                  onBackFromCase: _closeCase,
                  onManage: widget.managementPageBuilder == null
                      ? null
                      : () => _openManagement(context),
                  onSettings: () => _showWorkspaceMenu(context),
                );
''',
)
replace_once(
    preview,
    '''    required this.onOpenCase,
    required this.onBackFromCase,
  });
''',
    '''    required this.onOpenCase,
    required this.onBackFromCase,
    required this.onSettings,
    this.onManage,
  });
''',
)
replace_once(
    preview,
    '''  final ValueChanged<V2FocusItem> onOpenCase;
  final VoidCallback onBackFromCase;
''',
    '''  final ValueChanged<V2FocusItem> onOpenCase;
  final VoidCallback onBackFromCase;
  final VoidCallback? onManage;
  final VoidCallback onSettings;
''',
)
replace_once(
    preview,
    '''              child: _NavigationRail(
                selectedIndex: destination,
                onSelected: onDestinationChanged,
              ),
''',
    '''              child: _NavigationRail(
                selectedIndex: destination,
                onSelected: onDestinationChanged,
                onManage: onManage,
                onSettings: onSettings,
              ),
''',
)
replace_once(
    preview,
    '''            ] else if (destination == 3) ...[
              Expanded(child: _CaseIndexPane(onOpenCase: onOpenCase)),
            ] else ...[
              const Expanded(
                child: _QuietPlaceholder(
                  title: '课程',
                  message: 'V2 第一阶段先确定教师高频工作流。课程入口将在 Shell 稳定后接入。',
                ),
              ),
            ],
''',
    '''            ] else ...[
              Expanded(child: _CaseIndexPane(onOpenCase: onOpenCase)),
            ],
''',
)
# Compact constructor is the second identical constructor signature occurrence after
# the desktop one was already replaced, so the old text is unique again.
replace_once(
    preview,
    '''    required this.onOpenCase,
    required this.onBackFromCase,
  });
''',
    '''    required this.onOpenCase,
    required this.onBackFromCase,
    required this.onOpenMore,
  });
''',
)
replace_once(
    preview,
    '''  final ValueChanged<V2FocusItem> onOpenCase;
  final VoidCallback onBackFromCase;

  @override
  State<_CompactWorkspace> createState() => _CompactWorkspaceState();
''',
    '''  final ValueChanged<V2FocusItem> onOpenCase;
  final VoidCallback onBackFromCase;
  final VoidCallback onOpenMore;

  @override
  State<_CompactWorkspace> createState() => _CompactWorkspaceState();
''',
)
replace_once(
    preview,
    '''    } else if (widget.destination == 3) {
      body = _CaseIndexPane(onOpenCase: widget.onOpenCase, compact: true);
    } else {
      body = const _QuietPlaceholder(title: '课程', message: '课程入口将在下一阶段接入 V2。');
    }
''',
    '''    } else {
      body = _CaseIndexPane(onOpenCase: widget.onOpenCase, compact: true);
    }
''',
)
replace_once(
    preview,
    '''              onDestinationSelected: (value) {
                setState(() => _studentOpen = false);
                widget.onDestinationChanged(value);
              },
''',
    '''              onDestinationSelected: (value) {
                if (value == 3) {
                  widget.onOpenMore();
                  return;
                }
                setState(() => _studentOpen = false);
                widget.onDestinationChanged(value);
              },
''',
)
replace_once(
    preview,
    '''                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: '课程',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: '学情',
                ),
''',
    '''                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: '学情',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  label: '更多',
                ),
''',
)
replace_once(
    preview,
    '''  const _NavigationRail({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
''',
    '''  const _NavigationRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.onSettings,
    this.onManage,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onManage;
  final VoidCallback onSettings;
''',
)
replace_once(
    preview,
    '''          for (final item in const [
            (Icons.today_outlined, '今日'),
            (Icons.people_outline, '学生'),
            (Icons.menu_book_outlined, '课程'),
            (Icons.fact_check_outlined, '学情'),
          ].indexed)
''',
    '''          for (final item in const [
            (Icons.today_outlined, '今日'),
            (Icons.people_outline, '学生'),
            (Icons.fact_check_outlined, '学情'),
          ].indexed)
''',
)
replace_once(
    preview,
    '''          const Spacer(),
          const _RailItem(
            icon: Icons.admin_panel_settings_outlined,
            tooltip: '管理',
          ),
          const _RailItem(icon: Icons.settings_outlined, tooltip: '设置'),
          const SizedBox(height: 12),
''',
    '''          const Spacer(),
          if (onManage != null)
            _RailItem(
              icon: Icons.admin_panel_settings_outlined,
              tooltip: '管理',
              onTap: onManage,
            ),
          _RailItem(
            icon: Icons.settings_outlined,
            tooltip: '设置',
            onTap: onSettings,
          ),
          const SizedBox(height: 12),
''',
)

Path('test/features/v2_shell_production_capabilities_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2 release shell has only real primary destinations and runtime actions', () {
    final preview = File(
      'lib/features/design_v2/v2_workspace_preview.dart',
    ).readAsStringSync();
    final loader = File(
      'lib/features/design_v2/v2_workspace_loader.dart',
    ).readAsStringSync();
    final management = File(
      'lib/features/design_v2/v2_management_page.dart',
    ).readAsStringSync();
    final updateFlow = File(
      'lib/features/design_v2/v2_update_flow.dart',
    ).readAsStringSync();

    expect(preview, isNot(contains("label: '课程'")));
    expect(preview, isNot(contains('课程入口将在')));
    expect(preview, isNot(contains('Icons.menu_book_outlined')));
    expect(preview, contains("label: '更多'"));
    expect(preview, contains("tooltip: '管理'"));
    expect(preview, contains("tooltip: '设置'"));
    expect(preview, contains("title: const Text('检查更新')"));
    expect(preview, contains("title: const Text('退出登录')"));

    expect(loader, contains('workspace.canManageOrganization'));
    expect(loader, contains('rootMode: true'));
    expect(loader, contains('managementPageBuilder: managementPageBuilder'));
    expect(management, contains('OrganizationManagementPage('));
    expect(management, contains('teacherLearningRecordRepository:'));
    expect(management, contains('studentLearningRecordRepository:'));
    expect(management, contains("tooltip: '检查更新'"));
    expect(management, contains("tooltip: '退出登录'"));

    expect(updateFlow, contains('service.checkForUpdate()'));
    expect(updateFlow, contains('service.download(result)'));
    expect(updateFlow, contains('installer.install(downloaded)'));
    expect(updateFlow, contains('SystemNavigator.pop()'));
  });
}
''', encoding='utf-8')

print('V2 shell production capabilities patch applied')
