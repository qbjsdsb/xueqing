import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/case_reopen_draft_store.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/cloud/responsibility_read_repository.dart';
import 'package:xueqing/features/design_v2/v2_organization_workspace_page.dart';
import 'package:xueqing/features/design_v2/v2_read_model_adapter.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_data.dart';
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
      expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);
    },
  );

  testWidgets(
    'manager-teacher keeps three compact destinations and opens Organization as a scope',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_previewApp(withOrganization: true));
      await tester.pumpAndSettle();

      var navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigation.destinations, hasLength(3));
      expect(
        find.byKey(const Key('v2-open-organization-scope')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('v2-open-organization-scope')));
      await tester.pumpAndSettle();
      expect(find.text('机构测试页'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('机构测试页'), findsNothing);
      navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigation.destinations, hasLength(3));
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

    expect(find.byKey(const Key('v2-rail-organization')), findsOneWidget);
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

      expect(
        find.byKey(const Key('v2-organization-page-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('v2-organization-back-personal')),
        findsOneWidget,
      );
      expect(find.byType(AppBar), findsNothing);

      await tester.tap(find.text('管理'));
      await tester.pumpAndSettle();
      expect(find.text('当前账号没有可用的机构管理权限。'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(returnedToPersonal, 0);
      expect(find.text('学情'), findsOneWidget);
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
      expect(find.text('学情'), findsOneWidget);
    },
  );

  testWidgets(
    'manager-teacher switches from Personal projection to full Organization projection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final workspace = _managerTeacherWorkspace();

      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: V2WorkspaceLoader(
            loadWorkspace: () async => workspace,
            responsibilityReadRepository: _FakeResponsibilityRepository(
              _responsibilityContext(
                personalProfileIds: const ['profile-personal'],
              ),
            ),
            runtime: _runtime(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigation.destinations, hasLength(3));
      expect(
        find.byKey(const Key('v2-open-organization-scope')),
        findsOneWidget,
      );
      await tester.tap(find.text('学生'));
      await tester.pumpAndSettle();
      expect(find.text('我的任课学生'), findsOneWidget);
      expect(find.text('机构其他学生'), findsNothing);

      await tester.tap(find.byKey(const Key('v2-open-organization-scope')));
      await tester.pumpAndSettle();
      expect(find.text('我的任课学生'), findsOneWidget);
      expect(find.text('机构其他学生'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
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

WorkspaceResponsibilityContext _responsibilityContext({
  List<String> personalProfileIds = const [],
}) => WorkspaceResponsibilityContext(
  organizationId: 'org-1',
  currentMembershipId: 'membership-manager',
  personalAssignments: [
    for (final profileId in personalProfileIds)
      WorkspacePersonalAssignment(
        assignmentId: 'assignment-$profileId',
        profileId: profileId,
        membershipId: 'membership-manager',
        assignmentRole: 'collaborator',
        businessDate: DateTime(2026, 9, 12),
      ),
  ],
  caseOwnerMembershipIds: const {},
  actionAssignedMembershipIds: const {},
  eventActorMembershipIds: const {},
  memberDisplayNames: const {
    'membership-manager': '李老师',
    'membership-lead': '张老师',
  },
  profileLeadMembershipIds: const {
    'profile-org': 'membership-lead',
    'profile-personal': 'membership-manager',
  },
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
  students: [_profile('student-org', 'profile-org', '机构学生')],
);

TeacherWorkspace _managerTeacherWorkspace() => TeacherWorkspace(
  viewerName: '李老师',
  organizationName: '测试机构',
  organizationTimeZone: 'Asia/Shanghai',
  organizationId: 'org-1',
  hasTeachingAccess: true,
  canManageOrganization: true,
  roles: const ['org_admin', 'teacher'],
  loadedAt: DateTime(2026, 9, 12, 12),
  businessDate: DateTime(2026, 9, 12),
  students: [
    _profile('student-personal', 'profile-personal', '我的任课学生'),
    _profile('student-org', 'profile-org', '机构其他学生'),
  ],
);

WorkspaceStudent _profile(String id, String profileId, String name) =>
    WorkspaceStudent(
      id: id,
      profileId: profileId,
      profileVersion: 1,
      name: name,
      grade: '初三',
      subject: '语文',
      context: '',
      positioning: null,
      strengths: null,
      cadenceNote: null,
      cases: const [],
      recentFacts: const [],
    );
