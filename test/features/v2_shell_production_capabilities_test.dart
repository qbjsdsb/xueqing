import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'V2 release shell has only real primary destinations and runtime actions',
    () {
      final router = File('lib/app/router/app_router.dart').readAsStringSync();
      final workspacePage = File(
        'lib/features/design_v2/v2_workspace_page.dart',
      ).readAsStringSync();
      final preview = File('lib/features/design_v2/v2_workspace_preview.dart')
          .readAsStringSync();
      final loader = File('lib/features/design_v2/v2_workspace_loader.dart')
          .readAsStringSync();
      final management = File('lib/features/design_v2/v2_management_page.dart')
          .readAsStringSync();
      final updateFlow = File('lib/features/design_v2/v2_update_flow.dart')
          .readAsStringSync();

      expect(router, contains("import '../../features/design_v2/v2_workspace_page.dart';"));
      expect(router, contains('_workspaceEntry(useV2: true)'));
      expect(router, contains('config.environment.isProduction || !config.showDeveloperTools'));
      expect(router, contains('V2WorkspacePage(runtime: runtime)'));
      expect(workspacePage, contains('V2WorkspaceLoader('));
      expect(workspacePage, contains('runtime.learningRepository.loadWorkspace'));
      expect(workspacePage, isNot(contains('V2 真实学情预览')));
      expect(workspacePage, isNot(contains('返回开发工具')));

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
    },
  );
}
