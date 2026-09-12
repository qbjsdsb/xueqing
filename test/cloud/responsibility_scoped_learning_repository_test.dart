import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/cloud/responsibility_read_repository.dart';
import 'package:xueqing/cloud/responsibility_scoped_learning_repository.dart';

void main() {
  group('ResponsibilityScopedLearningRepository', () {
    test('Personal Quick Capture uses the loaded membership snapshot', () async {
      final base = _FakeLearningRepository();
      final reader = _FakeResponsibilityReadRepository(_context());
      final writer = _FakeResponsibilityWriteRepository();
      final gateway = ResponsibilityScopedLearningRepository(
        learningRepository: base,
        responsibilityReadRepository: reader,
        responsibilityWriteRepository: writer,
      );

      await gateway.loadWorkspace();
      await gateway.loadContext(organizationId: 'org-1');
      final receipt = await gateway.quickCapture(_command());

      expect(receipt.caseId, 'case-scoped');
      expect(base.legacyQuickCaptureCalls, 0);
      expect(writer.calls, hasLength(1));
      expect(writer.calls.single.workspaceScope, WorkspaceWriteScope.personal);
      expect(
        writer.calls.single.expectedResponsibilityMembershipId,
        'membership-me',
      );
      expect(writer.calls.single.command.profileId, 'profile-mine');
    });

    test('missing responsibility context fails closed', () async {
      final base = _FakeLearningRepository();
      final writer = _FakeResponsibilityWriteRepository();
      final gateway = ResponsibilityScopedLearningRepository(
        learningRepository: base,
        responsibilityReadRepository: _FakeResponsibilityReadRepository(
          _context(),
        ),
        responsibilityWriteRepository: writer,
      );

      await gateway.loadWorkspace();

      expect(
        () => gateway.quickCapture(_command()),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'personal_responsibility_context_required',
          ),
        ),
      );
      expect(base.legacyQuickCaptureCalls, 0);
      expect(writer.calls, isEmpty);
    });

    test('organization-wide Profile cannot leak into Personal write', () async {
      final base = _FakeLearningRepository();
      final writer = _FakeResponsibilityWriteRepository();
      final gateway = ResponsibilityScopedLearningRepository(
        learningRepository: base,
        responsibilityReadRepository: _FakeResponsibilityReadRepository(
          _context(),
        ),
        responsibilityWriteRepository: writer,
      );

      await gateway.loadWorkspace();
      await gateway.loadContext(organizationId: 'org-1');

      expect(
        () => gateway.quickCapture(_command(profileId: 'profile-org-only')),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'personal_profile_responsibility_required',
          ),
        ),
      );
      expect(base.legacyQuickCaptureCalls, 0);
      expect(writer.calls, isEmpty);
    });

    test('workspace refresh clears the old responsibility snapshot', () async {
      final writer = _FakeResponsibilityWriteRepository();
      final gateway = ResponsibilityScopedLearningRepository(
        learningRepository: _FakeLearningRepository(),
        responsibilityReadRepository: _FakeResponsibilityReadRepository(
          _context(),
        ),
        responsibilityWriteRepository: writer,
      );

      await gateway.loadWorkspace();
      await gateway.loadContext(organizationId: 'org-1');
      await gateway.loadWorkspace();

      expect(
        () => gateway.quickCapture(_command()),
        throwsA(isA<StateError>()),
      );
      expect(writer.calls, isEmpty);
    });
  });
}

class _FakeLearningRepository implements LearningRepository {
  int legacyQuickCaptureCalls = 0;

  @override
  Future<TeacherWorkspace> loadWorkspace() async => TeacherWorkspace(
    viewerName: '乔老师',
    organizationName: '测试机构',
    organizationTimeZone: 'Asia/Shanghai',
    organizationId: 'org-1',
    hasTeachingAccess: true,
    students: const <WorkspaceStudent>[],
    loadedAt: DateTime(2026, 9, 12, 15),
  );

  @override
  Future<QuickCaptureReceipt> quickCapture(QuickCaptureCommand command) async {
    legacyQuickCaptureCalls += 1;
    return const QuickCaptureReceipt(
      operationId: 'operation-1',
      caseId: 'case-legacy',
      evidenceId: 'evidence-legacy',
      status: 'new',
      caseVersion: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeResponsibilityReadRepository
    implements ResponsibilityReadRepository {
  _FakeResponsibilityReadRepository(this.context);

  final WorkspaceResponsibilityContext context;

  @override
  Future<WorkspaceResponsibilityContext> loadContext({
    required String organizationId,
  }) async {
    expect(organizationId, context.organizationId);
    return context;
  }
}

class _FakeResponsibilityWriteRepository
    implements ResponsibilityWriteRepository {
  final List<_ScopedCall> calls = <_ScopedCall>[];

  @override
  Future<QuickCaptureReceipt> quickCaptureInScope({
    required QuickCaptureCommand command,
    required WorkspaceWriteScope workspaceScope,
    required String expectedResponsibilityMembershipId,
  }) async {
    calls.add(
      _ScopedCall(
        command: command,
        workspaceScope: workspaceScope,
        expectedResponsibilityMembershipId:
            expectedResponsibilityMembershipId,
      ),
    );
    return QuickCaptureReceipt(
      operationId: command.operationId,
      caseId: 'case-scoped',
      evidenceId: 'evidence-scoped',
      status: 'new',
      caseVersion: 1,
    );
  }
}

class _ScopedCall {
  const _ScopedCall({
    required this.command,
    required this.workspaceScope,
    required this.expectedResponsibilityMembershipId,
  });

  final QuickCaptureCommand command;
  final WorkspaceWriteScope workspaceScope;
  final String expectedResponsibilityMembershipId;
}

WorkspaceResponsibilityContext _context() {
  return WorkspaceResponsibilityContext(
    organizationId: 'org-1',
    currentMembershipId: 'membership-me',
    personalAssignments: [
      WorkspacePersonalAssignment(
        assignmentId: 'assignment-1',
        profileId: 'profile-mine',
        membershipId: 'membership-me',
        assignmentRole: 'lead',
        businessDate: DateTime(2026, 9, 12),
      ),
    ],
    caseOwnerMembershipIds: const <String, String>{},
    actionAssignedMembershipIds: const <String, String>{},
    eventActorMembershipIds: const <String, String>{},
    memberDisplayNames: const <String, String>{
      'membership-me': '乔老师',
    },
    profileLeadMembershipIds: const <String, String?>{
      'profile-mine': 'membership-me',
      'profile-org-only': 'membership-other',
    },
  );
}

QuickCaptureCommand _command({String profileId = 'profile-mine'}) {
  return QuickCaptureCommand(
    operationId: 'operation-1',
    profileId: profileId,
    expectedProfileVersion: 1,
    caseType: LearningCaseType.knowledge,
    title: '阅读题漏看限制词',
    description: null,
    observedAt: DateTime(2026, 9, 12, 15),
    evidenceSummary: '课堂上两次漏看限制词。',
  );
}
