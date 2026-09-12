import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/case_reopen_draft_store.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/cloud/responsibility_read_repository.dart';
import 'package:xueqing/features/design_v2/v2_fixture.dart';
import 'package:xueqing/features/design_v2/v2_organization_workspace_page.dart';
import 'package:xueqing/features/design_v2/v2_read_model_adapter.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_loader.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';
import 'package:xueqing/features/teacher_workspace/workspace_runtime.dart';
import 'package:xueqing/update/update_installer.dart';
import 'package:xueqing/update/update_service.dart';

void main() {
  testWidgets(
    'ordinary compact teacher keeps exactly three personal destinations',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_previewApp());
      await tester.pumpAndSettle();

      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigation.destinations, hasLength(3));
      expect(find.text('机构'), findsNothing);
    },
  );

  testWidgets(
    'manager-teacher gets Organization as a fourth compact destination',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_previewApp(withOrganization: true));
      await tester.pumpAndSettle();

      var navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigation.destinations, hasLength(4));
      expect(find.text('机构'), findsOneWidget);

      await tester.tap(find.text('机构'));
      await tester.pumpAndSettle();
      expect(find.text('机构测试页'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('机构测试页'), findsNothing);
      navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigation.selectedIndex, 0);
    },
  );

  testWidgets('desktop manager-teacher gets Organization in the primary rail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_previewApp(withOrganization: true));
    await tester.pumpAndSettle();

    expect(find.byTooltip('机构'), findsOneWidget);
    await tester.tap(find.byTooltip('机构'));
    await tester.pumpAndSettle();
    expect(find.text('机构测试页'), findsOneWidget);
  });

  testWidgets(
    'embedded Organization back unwinds management before returning Personal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var returnedToPersonal = 0;
      final workspace = _managerWorkspace();

      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: V2OrganizationWorkspacePage(
            workspace: workspace,
            workspaceData: V2ReadModelAdapter.fromWorkspace(workspace)
                .workspaceData,
            responsibility: _responsibilityContext(),
            runtime: _runtime(),
            embedded: true,
            onBackFromRoot: () => returnedToPersonal += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('机构管理'));
      await tester.pumpAndSettle();
      expect(find.text('当前账号没有可用的机构管理权限。'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(returnedToPersonal, 0);
      expect(find.text('机构学情'), findsWidgets);
      expect(find.text('当前账号没有可用的机构管理权限。'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(returnedToPersonal, 1);
    },
  );

  testWidgets(
    'Organization learning does not depend on organization management repository',
    (tester) async {
      final workspace = _managerWorkspace();
      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: V2WorkspaceLoader(
            loadWorkspace: () async => workspace,
            responsibilityReadRepository: _FakeResponsibilityRepository(
              _responsibilityContext(),
            ),
            runtime: _runtime(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('暂时没有任课学情'), findsNothing);
      expect(find.text('机构'), findsOneWidget);
      expect(find.text('机构学生'), findsOneWidget);
      expect(find.text('机构学情'), findsWidgets);
    },
  );
}

Widget _previewApp({bool withOrganization = false}) => MaterialApp(
  theme: V2Theme.light(),
  home: V2WorkspacePreview(
    data: v2FixtureWorkspaceData,
    organizationPageBuilder: withOrganization
        ? (context, onBackToPersonal) => PopScope<void>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) onBackToPersonal();
            },
            child: const Center(child: Text('机构测试页')),
          )
        : null,
  ),
);

AuthenticatedWorkspaceRuntime _runtime() => AuthenticatedWorkspaceRuntime(
  learningRepository: _FakeLearningRepository(),
  updateService: UpdateService(currentVersion: '0.3.8'),
  updateInstaller: _FakeUpdateInstaller(),
  caseReopenDraftStore: _FakeCaseReopenDraftStore(),
  appVersion: '0.3.8',
  sessionUserId: 'user-manager',
);

class _FakeLearningRepository implements LearningRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeUpdateInstaller implements UpdateInstaller {
  @override
  Future<UpdateInstallResult> install(UpdateDownloadedArtifact update) async =>
      const UpdateInstallResult(shouldExit: false);
}

class _FakeCaseReopenDraftStore implements CaseReopenDraftStore {
  @override
  Future<void> clear(String scopeKey) async {}

  @override
  Future<CaseReopenDraft?> load(String scopeKey) async => null;

  @override
  Future<void> save(String scopeKey, CaseReopenDraft draft) async {}
}

class _FakeResponsibilityRepository implements ResponsibilityReadRepository {
  _FakeResponsibilityRepository(this.context);

  final WorkspaceResponsibilityContext context;

  @override
  Future<WorkspaceResponsibilityContext> loadContext({
    required String organizationId,
  }) async {
    expect(organizationId, 'org-1');
    return context;
  }
}

WorkspaceResponsibilityContext _responsibilityContext() =>
    WorkspaceResponsibilityContext(
      organizationId: 'org-1',
      currentMembershipId: 'membership-manager',
      personalAssignments: const [],
      caseOwnerMembershipIds: const {},
      actionAssignedMembershipIds: const {},
      eventActorMembershipIds: const {},
      memberDisplayNames: const {'membership-lead': '张老师'},
      profileLeadMembershipIds: const {'profile-org': 'membership-lead'},
    );

TeacherWorkspace _managerWorkspace() => TeacherWorkspace(
  viewerName: '李老师',
  organizationName: '测试机构',
  organizationTimeZone: 'Asia/Shanghai',
  organizationId: 'org-1',
  hasTeachingAccess: true,
  canManageOrganization: true,
  roles: const ['org_admin'],
  loadedAt: DateTime(2026, 9, 12, 12),
  businessDate: DateTime(2026, 9, 12),
  students: [
    WorkspaceStudent(
      id: 'student-org',
      profileId: 'profile-org',
      profileVersion: 1,
      name: '机构学生',
      grade: '初三',
      subject: '语文',
      context: '',
      positioning: null,
      strengths: null,
      cadenceNote: null,
      cases: const [],
      recentFacts: const [],
    ),
  ],
);
