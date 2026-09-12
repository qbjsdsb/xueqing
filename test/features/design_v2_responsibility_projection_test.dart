import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/cloud/responsibility_read_repository.dart';
import 'package:xueqing/features/design_v2/v2_responsibility_projection.dart';

void main() {
  group('V2ResponsibilityProjection', () {
    test(
      'Personal students follow Assignments while full Profile history remains',
      () {
        final projection = V2ResponsibilityProjection.personal(
          workspace: _workspace(),
          responsibility: _context(
            personalProfileIds: const ['profile-personal'],
            actionAssignees: const {
              'action-mine': 'membership-me',
              'action-collaborator': 'membership-other',
            },
          ),
        );

        expect(projection.hasPersonalTeachingResponsibility, isTrue);
        expect(
          projection.workspace.students.map((profile) => profile.profileId),
          ['profile-personal'],
        );
        expect(projection.snapshot.students, hasLength(1));
        expect(projection.snapshot.students.single.id, 'student-personal');

        // The collaborator-owned next step does not remove the Case from the
        // teacher's longitudinal learning view for a Profile they teach.
        expect(projection.snapshot.focusItems.map((item) => item.id).toSet(), {
          'case-mine',
          'case-collaborator',
        });
        expect(
          projection.workspaceData.focusItems.map((item) => item.id).toSet(),
          {'case-mine', 'case-collaborator'},
        );
      },
    );

    test('Personal Today only contains primary Actions assigned to me', () {
      final projection = V2ResponsibilityProjection.personal(
        workspace: _workspace(),
        responsibility: _context(
          personalProfileIds: const ['profile-personal'],
          actionAssignees: const {
            'action-mine': 'membership-me',
            'action-collaborator': 'membership-other',
          },
        ),
      );

      expect(projection.todayCaseIds, {'case-mine'});
      expect(projection.workspaceData.todayFocusItems.map((item) => item.id), [
        'case-mine',
      ]);
    });

    test('manager visibility alone produces an empty Personal projection', () {
      final projection = V2ResponsibilityProjection.personal(
        workspace: _workspace(canManageOrganization: true),
        responsibility: _context(
          personalProfileIds: const [],
          actionAssignees: const {
            'action-mine': 'membership-me',
            'action-collaborator': 'membership-other',
            'action-org': 'membership-other',
          },
        ),
      );

      expect(projection.hasPersonalTeachingResponsibility, isFalse);
      expect(projection.workspace.students, isEmpty);
      expect(projection.workspaceData.students, isEmpty);
      expect(projection.workspaceData.todayFocusItems, isEmpty);
      expect(projection.workspace.canManageOrganization, isTrue);
    });

    test('fails closed when context belongs to another organization', () {
      expect(
        () => V2ResponsibilityProjection.personal(
          workspace: _workspace(),
          responsibility: _context(
            organizationId: 'org-other',
            personalProfileIds: const ['profile-personal'],
            actionAssignees: const {},
          ),
        ),
        throwsFormatException,
      );
    });

    test(
      'fails closed when Assignment references a missing workspace Profile',
      () {
        expect(
          () => V2ResponsibilityProjection.personal(
            workspace: _workspace(),
            responsibility: _context(
              personalProfileIds: const ['profile-missing'],
              actionAssignees: const {},
            ),
          ),
          throwsFormatException,
        );
      },
    );
  });
}

WorkspaceResponsibilityContext _context({
  String organizationId = 'org-1',
  required List<String> personalProfileIds,
  required Map<String, String> actionAssignees,
}) {
  return WorkspaceResponsibilityContext(
    organizationId: organizationId,
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
      'case-mine': 'membership-other',
      'case-collaborator': 'membership-other',
    },
    actionAssignedMembershipIds: actionAssignees,
    eventActorMembershipIds: const {},
    memberDisplayNames: const {
      'membership-me': '乔老师',
      'membership-other': '张老师',
    },
  );
}

TeacherWorkspace _workspace({bool canManageOrganization = false}) {
  return TeacherWorkspace(
    viewerName: '乔老师',
    organizationName: '测试机构',
    organizationTimeZone: 'Asia/Shanghai',
    organizationId: 'org-1',
    hasTeachingAccess: true,
    canManageOrganization: canManageOrganization,
    loadedAt: DateTime(2026, 9, 12, 12),
    businessDate: DateTime(2026, 9, 12),
    students: [
      _profile(
        studentId: 'student-personal',
        profileId: 'profile-personal',
        subject: '语文',
        cases: [
          _case(
            id: 'case-mine',
            profileId: 'profile-personal',
            actionId: 'action-mine',
            title: '我负责下一步',
          ),
          _case(
            id: 'case-collaborator',
            profileId: 'profile-personal',
            actionId: 'action-collaborator',
            title: '协作老师负责下一步',
          ),
        ],
      ),
      _profile(
        studentId: 'student-org-only',
        profileId: 'profile-org-only',
        subject: '数学',
        cases: [
          _case(
            id: 'case-org-only',
            profileId: 'profile-org-only',
            actionId: 'action-org',
            title: '仅机构监督可见',
          ),
        ],
      ),
    ],
  );
}

WorkspaceStudent _profile({
  required String studentId,
  required String profileId,
  required String subject,
  required List<WorkspaceCase> cases,
}) {
  return WorkspaceStudent(
    id: studentId,
    profileId: profileId,
    profileVersion: 1,
    name: studentId == 'student-personal' ? '林同学' : '王同学',
    grade: '初三',
    subject: subject,
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
  required String profileId,
  required String actionId,
  required String title,
}) {
  return WorkspaceCase(
    id: id,
    profileId: profileId,
    title: title,
    type: LearningCaseType.knowledge,
    status: LearningCaseStatus.intervening,
    priority: 'medium',
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
        title: '下一步',
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
