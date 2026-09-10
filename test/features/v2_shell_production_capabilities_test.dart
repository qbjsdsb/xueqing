import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2 release shell has only real primary destinations and runtime actions', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final workspacePage = File('lib/features/design_v2/v2_workspace_page.dart')
        .readAsStringSync();
    final preview = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();
    final loader = File('lib/features/design_v2/v2_workspace_loader.dart')
        .readAsStringSync();
    final management = File('lib/features/design_v2/v2_management_page.dart')
        .readAsStringSync();
    final managementLayout = File(
      'lib/features/organization_management/presentation/'
      'organization_management_layout.dart',
    ).readAsStringSync();
    final updateFlow = File('lib/features/design_v2/v2_update_flow.dart')
        .readAsStringSync();
    final composers = File('lib/features/design_v2/v2_composers.dart')
        .readAsStringSync();
    final teacherWorkspace = File(
      'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    ).readAsStringSync();

    expect(
      router,
      contains("import '../../features/design_v2/v2_workspace_page.dart';"),
    );
    expect(router, contains('_workspaceEntry(useV2: true)'));
    expect(
      router,
      contains('config.environment.isProduction || !config.showDeveloperTools'),
    );
    expect(router, contains('V2WorkspacePage(runtime: runtime)'));
    expect(workspacePage, contains('V2WorkspaceLoader('));
    expect(workspacePage, contains('runtime.learningRepository.loadWorkspace'));
    expect(workspacePage, isNot(contains('V2 真实学情预览')));
    expect(workspacePage, isNot(contains('返回开发工具')));

    expect(preview, isNot(contains("label: '课程'")));
    expect(preview, isNot(contains('课程入口将在')));
    expect(preview, isNot(contains('Icons.menu_book_outlined')));
    expect(preview, isNot(contains("label: '更多'")));
    expect(preview, contains("Key('v2-compact-more')"));
    expect(preview, contains("tooltip: '管理'"));
    expect(preview, contains("tooltip: '设置'"));
    expect(preview, contains("title: const Text('检查更新')"));
    expect(preview, contains("title: const Text('退出登录')"));
    expect(preview, contains("Key('v2-workspace-refresh')"));
    expect(preview, contains("Key('v2-menu-refresh')"));
    expect(preview, contains("const Text('近期安排')"));
    expect(preview, contains("Key('v2-today-quick-capture')"));
    expect(preview, isNot(contains('.take(4)')));
    expect(preview, contains("Key('v2-empty-management')"));
    expect(preview, contains("Key('v2-student-more-actions')"));

    expect(loader, contains('workspace.canManageOrganization'));
    expect(teacherWorkspace, contains("membershipState?.status == 'none'"));
    expect(teacherWorkspace, contains('OrganizationInvitationJoinPage('));
    expect(loader, contains('rootMode: true'));
    expect(loader, contains('managementPageBuilder: managementPageBuilder'));
    expect(loader, contains('onExportStudent:'));
    expect(management, contains('OrganizationManagementPage('));
    expect(management, contains('teacherLearningRecordRepository:'));
    expect(management, contains('studentLearningRecordRepository:'));
    expect(management, contains("title: const Text('机构管理')"));
    expect(management, contains('showHeaderTitle: false'));
    expect(management, contains("tooltip: '检查更新'"));
    expect(management, contains("tooltip: '退出登录'"));
    expect(management, contains("Key('v2-management-more')"));
    expect(management, contains('PopupMenuButton<_ManagementPageAction>'));
    expect(management, contains("title: const Text('检查更新')"));
    expect(management, contains("title: Text('退出登录')"));
    expect(management, contains("Text('当前版本 \${widget.runtime.appVersion}')"));
    expect(
      management,
      contains('canManageCaseTypes: widget.workspace.canManageCaseTypes'),
    );
    expect(managementLayout, contains('Semantics('));
    expect(managementLayout, contains('liveRegion: true'));
    expect(teacherWorkspace, contains('class WorkspaceCaseTypeManager'));
    expect(composers, contains('DateTime? businessDate'));
    expect(composers, contains('这条记录还没有确认保存'));
    expect(composers, contains('onPopInvokedWithResult'));

    expect(updateFlow, contains('service.checkForUpdate()'));
    expect(updateFlow, contains('service.download('));
    expect(updateFlow, contains('onProgress:'));
    expect(updateFlow, contains('installer.install(downloaded)'));
    expect(updateFlow, contains('SystemNavigator.pop()'));
  });
}
