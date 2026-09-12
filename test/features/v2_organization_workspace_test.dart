import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/case_reopen_draft_store.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/cloud/organization_management_repository.dart';
import 'package:xueqing/cloud/responsibility_read_repository.dart';
import 'package:xueqing/features/design_v2/v2_organization_workspace_page.dart';
import 'package:xueqing/features/design_v2/v2_read_model_adapter.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_loader.dart';
import 'package:xueqing/features/teacher_workspace/workspace_runtime.dart';
import 'package:xueqing/update/update_installer.dart';
import 'package:xueqing/update/update_service.dart';

void main() {
  testWidgets(
    'Organization learning shows Lead responsibility without writes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final workspace = _workspace();
      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: V2OrganizationWorkspacePage(
            workspace: workspace,
            workspaceData: V2ReadModelAdapter.fromWorkspace(workspace)
                .workspaceData,
            responsibility: _context(personalProfileIds: const []),
            runtime: _runtime(includeManagement: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('机构'), findsOneWidget);
      expect(find.text('机构学情'), findsWidgets);
      expect(find.textContaining('2 名学生 · 2 个正在跟进的问题'), findsOneWidget);
      expect(find.byKey(const Key('v2-today-quick-capture')), findsNothing);

      await tester.tap(find.text('机构学生一'));
      await tester.pumpAndSettle();
      expect(find.textContaining('当前负责：张老师'), findsOneWidget);

      await tester.tap(find.text('机构学生二'));
      await tester.pumpAndSettle();
      expect(find.textContaining('当前负责：未设置主责'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('v2-organization-learning-search')),
        '张老师',
      );
      await tester.pumpAndSettle();
      expect(find.text('机构学生一'), findsOneWidget);
      expect(find.text('机构学生二'), findsNothing);
    },
  );

  testWidgets('manager without Personal Assignment enters Organization root', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: V2WorkspaceLoader(
          loadWorkspace: () async => _workspace(),
          responsibilityReadRepository: _FakeResponsibilityRepository(
            _context(personalProfileIds: const []),
          ),
          runtime: _runtime(includeManagement: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂时没有任课学情'), findsNothing);
    expect(find.text('机构'), findsOneWidget);
    expect(find.text('机构学生一'), findsOneWidget);
    expect(find.text('机构学生二'), findsOneWidget);
    expect(
      find.byKey(const Key('v2-organization-section-switch')),
      findsOneWidget,
    );
  });
}

AuthenticatedWorkspaceRuntime _runtime({required bool includeManagement}) {
  return AuthenticatedWorkspaceRuntime(
    learningRepository: _FakeLearningRepository(),
    organizationManagementRepository: includeManagement
        ? _FakeOrganizationManagementRepository()
        : null,
    updateService: UpdateService(currentVersion: '0.3.8'),
    updateInstaller: _FakeUpdateInstaller(),
    caseReopenDraftStore: _FakeCaseReopenDraftStore(),
    appVersion: '0.3.8',
    sessionUserId: 'user-manager',
  );
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

class _FakeLearningRepository implements LearningRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeOrganizationManagementRepository
    implements OrganizationManagementRepository {
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

WorkspaceResponsibilityContext _context({
  required List<String> personalProfileIds,
}) {
  return WorkspaceResponsibilityContext(
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
    caseOwnerMembershipIds: const {
      'case-a': 'membership-lead',
      'case-b': 'membership-other',
    },
    actionAssignedMembershipIds: const {
      'action-a': 'membership-lead',
      'action-b': 'membership-other',
    },
    eventActorMembershipIds: const {},
    memberDisplayNames: const {
      'membership-manager': '李老师',
      'membership-lead': '张老师',
      'membership-other': '王老师',
    },
    profileLeadMembershipIds: const {
      'profile-a': 'membership-lead',
      'profile-b': null,
    },
  );
}

TeacherWorkspace _workspace() {
  return TeacherWorkspace(
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
      _profile(
        studentId: 'student-a',
        profileId: 'profile-a',
        name: '机构学生一',
        caseId: 'case-a',
        actionId: 'action-a',
        title: '阅读概括遗漏要点',
      ),
      _profile(
        studentId: 'student-b',
        profileId: 'profile-b',
        name: '机构学生二',
        caseId: 'case-b',
        actionId: 'action-b',
        title: '作文立意不稳定',
      ),
    ],
  );
}

WorkspaceStudent _profile({
  required String studentId,
  required String profileId,
  required String name,
  required String caseId,
  required String actionId,
  required String title,
}) {
  return WorkspaceStudent(
    id: studentId,
    profileId: profileId,
    profileVersion: 1,
    name: name,
    grade: '初三',
    subject: '语文',
    context: '',
    positioning: null,
    strengths: null,
    cadenceNote: null,
    recentFacts: const [],
    cases: [
      WorkspaceCase(
        id: caseId,
        profileId: profileId,
        title: title,
        type: LearningCaseType.knowledge,
        status: LearningCaseStatus.intervening,
        priority: 'normal',
        description: title,
        firstObservedAt: DateTime(2026, 9, 10),
        version: 1,
        evidence: const [],
        interventions: const [],
        assessments: const [],
        actions: [
          WorkspaceAction(
            id: actionId,
            caseId: caseId,
            title: '下一次继续检查',
            actionType: 'verify',
            status: WorkspaceActionStatus.pending,
            isPrimary: true,
            bucket: WorkspaceActionBucket.today,
            version: 1,
            dueAt: DateTime(2026, 9, 12, 18),
            businessDueDate: DateTime(2026, 9, 12),
          ),
        ],
        timeline: const [],
      ),
    ],
  );
}
