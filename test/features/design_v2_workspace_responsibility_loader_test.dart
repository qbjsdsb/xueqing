import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/cloud/responsibility_read_repository.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_loader.dart';

void main() {
  Widget app({
    required TeacherWorkspace workspace,
    required ResponsibilityReadRepository responsibilityRepository,
  }) {
    return MaterialApp(
      theme: V2Theme.light(),
      home: V2WorkspaceLoader(
        loadWorkspace: () async => workspace,
        responsibilityReadRepository: responsibilityRepository,
      ),
    );
  }

  testWidgets('manager-wide snapshot never leaks into Personal students', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      app(
        workspace: _workspace(),
        responsibilityRepository: _FakeResponsibilityRepository(
          _context(personalProfileIds: const ['profile-mine']),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('学生'));
    await tester.pumpAndSettle();

    expect(find.text('我的学生'), findsWidgets);
    expect(find.text('机构其他学生'), findsNothing);
  });

  testWidgets('manager role without Assignment has no Personal workspace', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        workspace: _workspace(),
        responsibilityRepository: _FakeResponsibilityRepository(
          _context(personalProfileIds: const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂时没有任课学情'), findsOneWidget);
    expect(find.text('我的学生'), findsNothing);
    expect(find.text('机构其他学生'), findsNothing);
  });

  testWidgets(
    'Today uses Action assignee while Learning keeps complete Profile cases',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        app(
          workspace: _workspace(),
          responsibilityRepository: _FakeResponsibilityRepository(
            _context(
              personalProfileIds: const ['profile-mine'],
              actionAssignees: const {
                'action-mine': 'membership-me',
                'action-other': 'membership-other',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('本人要处理的问题'), findsOneWidget);
      expect(find.text('协作老师要处理的问题'), findsNothing);

      await tester.tap(find.byTooltip('学情'));
      await tester.pumpAndSettle();

      expect(find.text('本人要处理的问题'), findsOneWidget);
      expect(find.text('协作老师要处理的问题'), findsOneWidget);
    },
  );

  testWidgets(
    'responsibility read failure fails closed instead of leaking raw data',
    (tester) async {
      await tester.pumpWidget(
        app(
          workspace: _workspace(),
          responsibilityRepository: _ThrowingResponsibilityRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('学情暂时无法读取'), findsOneWidget);
      expect(find.text('我的学生'), findsNothing);
      expect(find.text('机构其他学生'), findsNothing);
    },
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

class _ThrowingResponsibilityRepository
    implements ResponsibilityReadRepository {
  @override
  Future<WorkspaceResponsibilityContext> loadContext({
    required String organizationId,
  }) async {
    throw StateError('responsibility context unavailable');
  }
}

WorkspaceResponsibilityContext _context({
  required List<String> personalProfileIds,
  Map<String, String> actionAssignees = const {
    'action-mine': 'membership-me',
    'action-other': 'membership-other',
  },
}) {
  return WorkspaceResponsibilityContext(
    organizationId: 'org-1',
    currentMembershipId: 'membership-me',
    personalAssignments: [
      for (final profileId in personalProfileIds)
        WorkspacePersonalAssignment(
          assignmentId: 'assignment-$profileId',
          profileId: profileId,
          membershipId: 'membership-me',
          assignmentRole: 'collaborator',
          businessDate: DateTime(2026, 9, 12),
        ),
    ],
    caseOwnerMembershipIds: const {
      'case-mine': 'membership-me',
      'case-other-action': 'membership-me',
      'case-org-only': 'membership-other',
    },
    actionAssignedMembershipIds: actionAssignees,
    eventActorMembershipIds: const {},
    memberDisplayNames: const {
      'membership-me': '乔老师',
      'membership-other': '张老师',
    },
  );
}

TeacherWorkspace _workspace() {
  return TeacherWorkspace(
    viewerName: '乔老师',
    organizationName: '测试机构',
    organizationTimeZone: 'Asia/Shanghai',
    organizationId: 'org-1',
    hasTeachingAccess: true,
    canManageOrganization: true,
    loadedAt: DateTime(2026, 9, 12, 12),
    businessDate: DateTime(2026, 9, 12),
    students: [
      _profile(
        studentId: 'student-mine',
        profileId: 'profile-mine',
        name: '我的学生',
        cases: [
          _case(
            id: 'case-mine',
            actionId: 'action-mine',
            profileId: 'profile-mine',
            title: '本人要处理的问题',
          ),
          _case(
            id: 'case-other-action',
            actionId: 'action-other',
            profileId: 'profile-mine',
            title: '协作老师要处理的问题',
          ),
        ],
      ),
      _profile(
        studentId: 'student-org-only',
        profileId: 'profile-org-only',
        name: '机构其他学生',
        cases: [
          _case(
            id: 'case-org-only',
            actionId: 'action-org-only',
            profileId: 'profile-org-only',
            title: '机构监督问题',
          ),
        ],
      ),
    ],
  );
}

WorkspaceStudent _profile({
  required String studentId,
  required String profileId,
  required String name,
  required List<WorkspaceCase> cases,
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
    cases: cases,
    recentFacts: const [],
  );
}

WorkspaceCase _case({
  required String id,
  required String actionId,
  required String profileId,
  required String title,
}) {
  return WorkspaceCase(
    id: id,
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
        caseId: id,
        title: '今天跟进',
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
  );
}
