import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/case_reopen_draft_store.dart';
import 'package:xueqing/cloud/evidence_attachment_repository.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/cloud/progressive_case_repository.dart';
import 'package:xueqing/features/design_v2/v2_workflow_controller.dart';
import 'package:xueqing/features/teacher_workspace/presentation/evidence_attachment_picker.dart';

void main() {
  group('V2WorkflowController', () {
    test(
      'Quick Capture keeps exact student-subject identity and custom type',
      () async {
        final learning = _FakeLearningRepository();
        final progress = _FakeProgressiveCaseRepository();
        final attachments = _FakeEvidenceAttachmentRepository();
        final controller = V2WorkflowController(
          workspace: _workspace(),
          learningRepository: learning,
          progressiveCaseRepository: progress,
          evidenceAttachmentRepository: attachments,
          now: () => DateTime(2026, 9, 9, 18, 30),
        );

        final result = await controller.quickCapture(
          V2QuickCaptureWrite(
            operationId: 'operation-quick-1',
            studentId: 'student-1',
            subject: '语文',
            caseTypeKey: 'custom-reading',
            body: '概括题遗漏结果。需要提醒后才能补全。',
            attachments: [_attachment('photo-1.jpg')],
          ),
        );

        expect(result.caseId, 'case-created');
        expect(result.attachmentCount, 1);
        expect(learning.quickCaptureCalls, hasLength(1));
        final command = learning.quickCaptureCalls.single;
        expect(command.profileId, 'profile-chinese');
        expect(command.expectedProfileVersion, 2);
        expect(command.caseType, LearningCaseType.knowledge);
        expect(command.organizationCaseTypeId, 'custom-reading');
        expect(command.title, '概括题遗漏结果');
        expect(command.evidenceSummary, '概括题遗漏结果。需要提醒后才能补全。');
        expect(attachments.uploads.single.evidenceId, 'evidence-created');
        expect(attachments.uploads.single.caseId, 'case-created');
      },
    );

    test(
      'teacher case invalidation uses the dedicated record command',
      () async {
        final progress = _FakeProgressiveCaseRepository();
        final controller = V2WorkflowController(
          workspace: _workspace(),
          learningRepository: _FakeLearningRepository(),
          progressiveCaseRepository: progress,
        );

        await controller.voidCase(
          operationId: 'operation-void-case',
          caseId: 'case-existing',
          reason: CaseVoidReason.duplicate,
          note: '重复记录',
        );

        expect(progress.voidCalls, hasLength(1));
        final command = progress.voidCalls.single;
        expect(command.operationId, 'operation-void-case');
        expect(command.caseId, 'case-existing');
        expect(command.expectedCaseVersion, 3);
        expect(command.reason, CaseVoidReason.duplicate);
        expect(command.note, '重复记录');
        expect(progress.endCalls, isEmpty);
      },
    );

    test('same-name students never replace stable student identity', () async {
      final learning = _FakeLearningRepository();
      final controller = V2WorkflowController(
        workspace: _workspace(),
        learningRepository: learning,
        progressiveCaseRepository: _FakeProgressiveCaseRepository(),
      );

      await controller.quickCapture(
        const V2QuickCaptureWrite(
          operationId: 'operation-same-name',
          studentId: 'student-2',
          subject: '语文',
          caseTypeKey: 'unclassified',
          body: '另一个同名学生的问题。',
          attachments: [],
        ),
      );

      expect(learning.quickCaptureCalls.single.profileId, 'profile-other');
    });

    test('intervention photo evidence is committed before progress', () async {
      final log = <String>[];
      final learning = _FakeLearningRepository(log: log)
        ..addEvidenceReceipt = const CaseCommandReceipt(
          operationId: 'operation-photo',
          caseId: 'case-existing',
          eventId: 'event-photo',
          status: 'confirmed',
          caseVersion: 4,
          recordId: 'evidence-photo',
        );
      final progress = _FakeProgressiveCaseRepository(log: log);
      final attachments = _FakeEvidenceAttachmentRepository(log: log);
      final occurredAt = DateTime.utc(2026, 9, 9, 10, 30);
      final controller = V2WorkflowController(
        workspace: _workspace(),
        learningRepository: learning,
        progressiveCaseRepository: progress,
        evidenceAttachmentRepository: attachments,
        now: () => occurredAt,
      );

      await controller.recordProgress(
        V2ProgressWrite(
          operationId: 'operation-progress',
          photoEvidenceOperationId: 'operation-photo',
          caseId: 'case-existing',
          progressKind: CaseProgressKind.intervention,
          summary: '重新讲解对象、特征和结果的概括结构。',
          nextStep: CaseProgressNextStep.remind,
          nextActionTitle: '再检查一次效果',
          nextActionDueOn: DateTime(2026, 9, 12),
          attachments: [_attachment('intervention.jpg')],
        ),
      );

      expect(log, ['add-evidence', 'upload', 'progress']);
      expect(learning.addEvidenceCalls.single.expectedCaseVersion, 3);
      expect(
        learning.addEvidenceCalls.single.title,
        v2InterventionPhotoCompanionTitle,
      );
      expect(learning.addEvidenceCalls.single.observedAt, occurredAt);
      expect(progress.calls.single.expectedCaseVersion, 4);
      expect(progress.calls.single.progressKind, CaseProgressKind.intervention);
      expect(progress.calls.single.occurredAt, occurredAt);
      expect(attachments.uploads.single.evidenceId, 'evidence-photo');
    });

    test(
      'open observation records progress first and attaches to its evidence',
      () async {
        final log = <String>[];
        final learning = _FakeLearningRepository(log: log);
        final progress = _FakeProgressiveCaseRepository(log: log)
          ..receipt = const ProgressiveCaseReceipt(
            operationId: 'operation-observation',
            caseId: 'case-existing',
            status: 'confirmed',
            caseVersion: 4,
            recordId: 'evidence-observation',
          );
        final attachments = _FakeEvidenceAttachmentRepository(log: log);
        final controller = V2WorkflowController(
          workspace: _workspace(),
          learningRepository: learning,
          progressiveCaseRepository: progress,
          evidenceAttachmentRepository: attachments,
        );

        await controller.recordProgress(
          V2ProgressWrite(
            operationId: 'operation-observation',
            photoEvidenceOperationId: 'unused-photo-operation',
            caseId: 'case-existing',
            progressKind: CaseProgressKind.observation,
            summary: '今天能主动定位关键词。',
            nextStep: CaseProgressNextStep.continueTracking,
            attachments: [_attachment('observation.jpg')],
          ),
        );

        expect(log, ['progress', 'upload']);
        expect(learning.addEvidenceCalls, isEmpty);
        expect(progress.calls.single.expectedCaseVersion, 3);
        expect(attachments.uploads.single.evidenceId, 'evidence-observation');
      },
    );

    test(
      'closing observation stores photo evidence before closing the case',
      () async {
        final log = <String>[];
        final learning = _FakeLearningRepository(log: log)
          ..addEvidenceReceipt = const CaseCommandReceipt(
            operationId: 'operation-photo-close',
            caseId: 'case-existing',
            eventId: 'event-photo-close',
            status: 'confirmed',
            caseVersion: 4,
            recordId: 'evidence-before-close',
          );
        final progress = _FakeProgressiveCaseRepository(log: log);
        final attachments = _FakeEvidenceAttachmentRepository(log: log);
        final controller = V2WorkflowController(
          workspace: _workspace(),
          learningRepository: learning,
          progressiveCaseRepository: progress,
          evidenceAttachmentRepository: attachments,
        );

        await controller.recordProgress(
          V2ProgressWrite(
            operationId: 'operation-close',
            photoEvidenceOperationId: 'operation-photo-close',
            caseId: 'case-existing',
            progressKind: CaseProgressKind.observation,
            summary: '本次已经能够稳定独立完成。',
            nextStep: CaseProgressNextStep.close,
            closeReason: CaseClosureReason.resolved,
            attachments: [_attachment('close.jpg')],
          ),
        );

        expect(log, ['add-evidence', 'upload', 'progress']);
        expect(progress.calls.single.expectedCaseVersion, 4);
        expect(progress.calls.single.nextStep, CaseProgressNextStep.close);
      },
    );

    test(
      'missing attachment capability stops before the learning write',
      () async {
        final learning = _FakeLearningRepository();
        final controller = V2WorkflowController(
          workspace: _workspace(),
          learningRepository: learning,
          progressiveCaseRepository: _FakeProgressiveCaseRepository(),
        );

        expect(
          () => controller.quickCapture(
            V2QuickCaptureWrite(
              operationId: 'operation-no-attachments',
              studentId: 'student-1',
              subject: '语文',
              caseTypeKey: 'unclassified',
              body: '有图片但当前没有附件能力。',
              attachments: [_attachment('blocked.jpg')],
            ),
          ),
          throwsA(
            isA<V2WorkflowSaveException>().having(
              (error) => error.recordMayBeSaved,
              'recordMayBeSaved',
              isFalse,
            ),
          ),
        );
        expect(learning.quickCaptureCalls, isEmpty);
      },
    );

    test(
      'direct action completion keeps exact optimistic-lock identity',
      () async {
        final learning = _FakeLearningRepository();
        final controller = V2WorkflowController(
          workspace: _workspace(),
          learningRepository: learning,
          progressiveCaseRepository: _FakeProgressiveCaseRepository(),
        );

        final action = controller.pendingActionFor('case-existing');
        expect(action, isNotNull);
        expect(action!.actionId, 'action-current');
        expect(action.actionVersion, 2);
        expect(action.caseVersion, 3);
        expect(action.canComplete, isTrue);

        await controller.completeCurrentAction(
          operationId: 'operation-complete-1',
          caseId: 'case-existing',
        );

        final command = learning.completeActionCalls.single;
        expect(command.operationId, 'operation-complete-1');
        expect(command.actionId, 'action-current');
        expect(command.caseId, 'case-existing');
        expect(command.expectedCaseVersion, 3);
        expect(command.expectedActionVersion, 2);
        expect(command.nextActionTitle, isNull);
      },
    );

    test(
      'direct action reschedule keeps identity and accepts undated',
      () async {
        final learning = _FakeLearningRepository();
        final controller = V2WorkflowController(
          workspace: _workspace(),
          learningRepository: learning,
          progressiveCaseRepository: _FakeProgressiveCaseRepository(),
        );

        await controller.rescheduleCurrentAction(
          operationId: 'operation-reschedule-1',
          caseId: 'case-existing',
          dueOn: null,
        );

        final command = learning.rescheduleActionCalls.single;
        expect(command.operationId, 'operation-reschedule-1');
        expect(command.actionId, 'action-current');
        expect(command.expectedCaseVersion, 3);
        expect(command.expectedActionVersion, 2);
        expect(command.dueOn, isNull);
      },
    );

    test('new case action cannot be completed before confirmation', () async {
      final learning = _FakeLearningRepository();
      final controller = V2WorkflowController(
        workspace: _workspaceWithCase(
          _case(status: LearningCaseStatus.newCase),
        ),
        learningRepository: learning,
        progressiveCaseRepository: _FakeProgressiveCaseRepository(),
      );

      expect(
        controller.pendingActionFor('case-existing')!.canComplete,
        isFalse,
      );
      await expectLater(
        controller.completeCurrentAction(
          operationId: 'operation-blocked',
          caseId: 'case-existing',
        ),
        throwsA(isA<V2WorkflowSaveException>()),
      );
      expect(learning.completeActionCalls, isEmpty);
    });

    test('safe reopen writes recurrence evidence before reopening', () async {
      final log = <String>[];
      final learning = _FakeLearningRepository(log: log)
        ..addEvidenceReceipt = const CaseCommandReceipt(
          operationId: 'evidence-op-receipt',
          caseId: 'case-existing',
          eventId: 'event-recurrence',
          status: 'closed',
          caseVersion: 4,
          recordId: 'evidence-recurrence',
        );
      final store = InMemoryCaseReopenDraftStore();
      final controller = V2WorkflowController(
        workspace: _workspaceWithCase(_case(status: LearningCaseStatus.closed)),
        learningRepository: learning,
        progressiveCaseRepository: _FakeProgressiveCaseRepository(),
        caseReopenDraftStore: store,
        sessionUserId: 'user-1',
        now: () => DateTime(2026, 9, 10, 18, 30),
      );

      final result = await controller.reopenClosedCase(
        V2ReopenWrite(
          caseId: 'case-existing',
          recurrenceSummary: '今天又出现漏掉结果信息的情况。',
          nextActionTitle: '周五再检查一次概括题',
          nextActionDueOn: DateTime(2026, 9, 11),
        ),
      );

      expect(result.caseVersion, 5);
      expect(log, <String>['add-evidence', 'reopen']);
      final evidence = learning.addEvidenceCalls.single;
      expect(evidence.expectedCaseVersion, 3);
      expect(evidence.sourceType, 'observation');
      expect(evidence.title, '问题再次出现');
      expect(evidence.summary, '今天又出现漏掉结果信息的情况。');
      final reopen = learning.reopenCalls.single;
      expect(reopen.expectedCaseVersion, 4);
      expect(reopen.recurrenceEvidenceIds, <String>['evidence-recurrence']);
      expect(reopen.expectedEvidenceVersions, <String, int>{
        'evidence-recurrence': 1,
      });
      expect(reopen.nextActionType, CaseActionType.verify);
      expect(reopen.nextActionTitle, '周五再检查一次概括题');
      expect(reopen.nextActionDueOn, DateTime(2026, 9, 11));
      expect(
        await store.load('user:user-1|organization:org-1|case:case-existing'),
        isNull,
      );
    });

    test(
      'failed reopen resumes same stored evidence and operation id',
      () async {
        final learning = _FakeLearningRepository()
          ..failFirstReopen = true
          ..addEvidenceReceipt = const CaseCommandReceipt(
            operationId: 'evidence-op-receipt',
            caseId: 'case-existing',
            eventId: 'event-recurrence',
            status: 'closed',
            caseVersion: 4,
            recordId: 'evidence-recurrence',
          );
        final store = InMemoryCaseReopenDraftStore();
        final controller = V2WorkflowController(
          workspace: _workspaceWithCase(
            _case(status: LearningCaseStatus.closed),
          ),
          learningRepository: learning,
          progressiveCaseRepository: _FakeProgressiveCaseRepository(),
          caseReopenDraftStore: store,
          sessionUserId: 'user-1',
        );
        const scope = 'user:user-1|organization:org-1|case:case-existing';

        await expectLater(
          controller.reopenClosedCase(
            const V2ReopenWrite(
              caseId: 'case-existing',
              recurrenceSummary: '第一次保存的复发描述。',
              nextActionTitle: '第一次保存的下一步',
            ),
          ),
          throwsA(
            isA<V2WorkflowSaveException>().having(
              (error) => error.recordMayBeSaved,
              'recordMayBeSaved',
              isTrue,
            ),
          ),
        );

        final stored = await store.load(scope);
        expect(stored, isNotNull);
        expect(stored!.evidenceId, 'evidence-recurrence');
        final evidenceOperationId =
            learning.addEvidenceCalls.single.operationId;
        final reopenOperationId = learning.reopenCalls.single.operationId;

        await controller.reopenClosedCase(
          const V2ReopenWrite(
            caseId: 'case-existing',
            recurrenceSummary: '这次重试不应该覆盖原描述。',
            nextActionTitle: '这次重试也不应该覆盖原下一步',
          ),
        );

        expect(learning.addEvidenceCalls, hasLength(1));
        expect(learning.reopenCalls, hasLength(2));
        expect(
          learning.addEvidenceCalls.single.operationId,
          evidenceOperationId,
        );
        expect(learning.reopenCalls[1].operationId, reopenOperationId);
        expect(learning.reopenCalls[1].nextActionTitle, '第一次保存的下一步');
        expect(await store.load(scope), isNull);
      },
    );

    test(
      'failed recurrence evidence retry reuses the original evidence operation',
      () async {
        final learning = _FakeLearningRepository()
          ..failFirstAddEvidence = true
          ..addEvidenceReceipt = const CaseCommandReceipt(
            operationId: 'evidence-op-receipt',
            caseId: 'case-existing',
            eventId: 'event-recurrence',
            status: 'closed',
            caseVersion: 4,
            recordId: 'evidence-recurrence',
          );
        final store = InMemoryCaseReopenDraftStore();
        final controller = V2WorkflowController(
          workspace: _workspaceWithCase(
            _case(status: LearningCaseStatus.closed),
          ),
          learningRepository: learning,
          progressiveCaseRepository: _FakeProgressiveCaseRepository(),
          caseReopenDraftStore: store,
          sessionUserId: 'user-1',
        );
        const write = V2ReopenWrite(
          caseId: 'case-existing',
          recurrenceSummary: '同一个复发证据必须幂等重试。',
          nextActionTitle: '继续核验',
        );

        await expectLater(
          controller.reopenClosedCase(write),
          throwsA(isA<V2WorkflowSaveException>()),
        );
        final firstOperationId = learning.addEvidenceCalls.single.operationId;
        final pending = await controller.loadPendingReopen('case-existing');
        expect(pending?.recurrenceSummary, '同一个复发证据必须幂等重试。');

        await controller.reopenClosedCase(write);

        expect(learning.addEvidenceCalls, hasLength(2));
        expect(learning.addEvidenceCalls[1].operationId, firstOperationId);
        expect(learning.reopenCalls, hasLength(1));
      },
    );

    test('reopen stays hidden without resumable identity capability', () {
      final controller = V2WorkflowController(
        workspace: _workspaceWithCase(_case(status: LearningCaseStatus.closed)),
        learningRepository: _FakeLearningRepository(),
        progressiveCaseRepository: _FakeProgressiveCaseRepository(),
      );

      expect(controller.canReopenClosedCase('case-existing'), isFalse);
    });

    test(
      'case type choices use real active types and one unclassified option',
      () {
        final controller = V2WorkflowController(
          workspace: _workspace(),
          learningRepository: _FakeLearningRepository(),
          progressiveCaseRepository: _FakeProgressiveCaseRepository(),
        );

        expect(controller.caseTypeChoices.first.key, 'unclassified');
        expect(
          controller.caseTypeChoices.where((item) => item.label == '暂不分类'),
          hasLength(1),
        );
        expect(
          controller.caseTypeChoices.any(
            (item) => item.key == 'custom-reading',
          ),
          isTrue,
        );
        expect(
          controller.caseTypeChoices.any((item) => item.key == 'archived-type'),
          isFalse,
        );
        expect(
          controller.caseTypeChoices.any((item) => item.key == 'builtin:other'),
          isFalse,
        );
      },
    );
  });
}

TeacherWorkspace _workspaceWithCase(WorkspaceCase learningCase) =>
    TeacherWorkspace(
      organizationId: 'org-1',
      viewerName: '王老师',
      organizationName: '测试机构',
      organizationTimeZone: 'Asia/Shanghai',
      hasTeachingAccess: true,
      students: [
        _profile(
          studentId: 'student-1',
          profileId: 'profile-chinese',
          profileVersion: 2,
          name: '林同学',
          subject: '语文',
          cases: [learningCase],
        ),
      ],
      loadedAt: DateTime(2026, 9, 9),
    );

TeacherWorkspace _workspace() => TeacherWorkspace(
  organizationId: 'org-1',
  viewerName: '王老师',
  organizationName: '测试机构',
  organizationTimeZone: 'Asia/Shanghai',
  hasTeachingAccess: true,
  students: [
    _profile(
      studentId: 'student-1',
      profileId: 'profile-chinese',
      profileVersion: 2,
      name: '林同学',
      subject: '语文',
      cases: [_case()],
    ),
    _profile(
      studentId: 'student-1',
      profileId: 'profile-math',
      profileVersion: 5,
      name: '林同学',
      subject: '数学',
    ),
    _profile(
      studentId: 'student-2',
      profileId: 'profile-other',
      profileVersion: 4,
      name: '林同学',
      subject: '语文',
    ),
  ],
  loadedAt: DateTime(2026, 9, 9),
  caseTypes: const [
    ...WorkspaceCaseType.builtInTypes,
    WorkspaceCaseType(
      id: 'custom-reading',
      displayName: '阅读理解',
      baseType: LearningCaseType.knowledge,
      status: 'active',
      sortOrder: 10,
      version: 1,
    ),
    WorkspaceCaseType(
      id: 'archived-type',
      displayName: '旧分类',
      baseType: LearningCaseType.other,
      status: 'archived',
      sortOrder: 20,
      version: 2,
    ),
  ],
);

WorkspaceStudent _profile({
  required String studentId,
  required String profileId,
  required int profileVersion,
  required String name,
  required String subject,
  List<WorkspaceCase> cases = const [],
}) => WorkspaceStudent(
  id: studentId,
  profileId: profileId,
  profileVersion: profileVersion,
  name: name,
  grade: '初三',
  subject: subject,
  context: '',
  positioning: null,
  strengths: null,
  cadenceNote: null,
  cases: cases,
  recentFacts: const [],
);

WorkspaceCase _case({
  LearningCaseStatus status = LearningCaseStatus.confirmed,
}) => WorkspaceCase(
  id: 'case-existing',
  profileId: 'profile-chinese',
  title: '阅读概括不完整',
  type: LearningCaseType.knowledge,
  status: status,
  priority: 'normal',
  description: '概括题容易漏掉结果。',
  firstObservedAt: DateTime(2026, 9, 1),
  version: 3,
  evidence: const [],
  interventions: const [],
  assessments: const [],
  actions: const [
    WorkspaceAction(
      id: 'action-current',
      caseId: 'case-existing',
      title: '再检查一次',
      actionType: 'verify',
      status: WorkspaceActionStatus.pending,
      isPrimary: true,
      bucket: WorkspaceActionBucket.today,
      version: 2,
    ),
  ],
  timeline: const [],
);

PickedEvidenceAttachment _attachment(
  String fileName,
) => PickedEvidenceAttachment(
  attachmentId:
      '00000000-0000-4000-8000-${fileName.hashCode.abs().toString().padLeft(12, '0').substring(0, 12)}',
  bytes: Uint8List.fromList([1, 2, 3]),
  fileName: fileName,
  contentType: 'image/jpeg',
);

class _FakeLearningRepository extends Fake implements LearningRepository {
  _FakeLearningRepository({this.log});

  final List<String>? log;
  final quickCaptureCalls = <QuickCaptureCommand>[];
  final addEvidenceCalls = <AddCaseEvidenceCommand>[];
  final completeActionCalls = <CompleteCaseActionCommand>[];
  final rescheduleActionCalls = <RescheduleCaseActionCommand>[];
  final reopenCalls = <ReopenCaseCommand>[];
  bool failFirstAddEvidence = false;
  bool failFirstReopen = false;
  CaseCommandReceipt addEvidenceReceipt = const CaseCommandReceipt(
    operationId: 'operation-photo',
    caseId: 'case-existing',
    eventId: 'event-photo',
    status: 'confirmed',
    caseVersion: 4,
    recordId: 'evidence-photo',
  );

  @override
  Future<QuickCaptureReceipt> quickCapture(QuickCaptureCommand command) async {
    quickCaptureCalls.add(command);
    log?.add('quick-capture');
    return const QuickCaptureReceipt(
      operationId: 'operation-quick-1',
      caseId: 'case-created',
      evidenceId: 'evidence-created',
      status: 'new',
      caseVersion: 1,
    );
  }

  @override
  Future<CaseCommandReceipt> completeCaseAction(
    CompleteCaseActionCommand command,
  ) async {
    completeActionCalls.add(command);
    return CaseCommandReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      eventId: 'event-complete',
      status: 'confirmed',
      caseVersion: command.expectedCaseVersion + 1,
      recordId: command.actionId,
    );
  }

  @override
  Future<CaseCommandReceipt> rescheduleCaseAction(
    RescheduleCaseActionCommand command,
  ) async {
    rescheduleActionCalls.add(command);
    return CaseCommandReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      eventId: 'event-reschedule',
      status: 'confirmed',
      caseVersion: command.expectedCaseVersion + 1,
      recordId: command.actionId,
    );
  }

  @override
  Future<CaseCommandReceipt> addCaseEvidence(
    AddCaseEvidenceCommand command,
  ) async {
    addEvidenceCalls.add(command);
    log?.add('add-evidence');
    if (failFirstAddEvidence && addEvidenceCalls.length == 1) {
      throw Exception('network timeout while saving recurrence evidence');
    }
    return addEvidenceReceipt;
  }

  @override
  Future<CaseCommandReceipt> reopenCase(ReopenCaseCommand command) async {
    reopenCalls.add(command);
    log?.add('reopen');
    if (failFirstReopen && reopenCalls.length == 1) {
      throw Exception('network timeout while reopening case');
    }
    return CaseCommandReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      actionId: 'action-reopened',
      eventId: 'event-reopened',
      status: 'confirmed',
      caseVersion: command.expectedCaseVersion + 1,
    );
  }
}

class _FakeProgressiveCaseRepository extends Fake
    implements ProgressiveCaseRepository, LearningCaseRecordRepository {
  _FakeProgressiveCaseRepository({this.log});

  final List<String>? log;
  final calls = <RecordCaseProgressCommand>[];
  final endCalls = <EndCaseFollowUpCommand>[];
  final voidCalls = <VoidLearningCaseCommand>[];
  final restoreCalls = <RestoreLearningCaseCommand>[];
  ProgressiveCaseReceipt receipt = const ProgressiveCaseReceipt(
    operationId: 'operation-progress',
    caseId: 'case-existing',
    status: 'intervening',
    caseVersion: 5,
    recordId: 'progress-record',
  );

  @override
  Future<ProgressiveCaseReceipt> recordProgress(
    RecordCaseProgressCommand command,
  ) async {
    calls.add(command);
    log?.add('progress');
    return receipt;
  }

  @override
  Future<ProgressiveCaseReceipt> endFollowUp(
    EndCaseFollowUpCommand command,
  ) async {
    endCalls.add(command);
    log?.add('end-follow-up');
    return ProgressiveCaseReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      status: 'closed',
      caseVersion: command.expectedCaseVersion + 1,
      eventId: 'event-void',
    );
  }

  @override
  Future<LearningCaseRecordReceipt> voidLearningCase(
    VoidLearningCaseCommand command,
  ) async {
    voidCalls.add(command);
    return LearningCaseRecordReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      recordState: 'voided',
      caseStatus: 'confirmed',
      caseVersion: command.expectedCaseVersion + 1,
      eventId: 'event-case-voided',
    );
  }

  @override
  Future<LearningCaseRecordReceipt> restoreLearningCase(
    RestoreLearningCaseCommand command,
  ) async {
    restoreCalls.add(command);
    return LearningCaseRecordReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      recordState: 'active',
      caseStatus: 'confirmed',
      caseVersion: command.expectedCaseVersion + 1,
      eventId: 'event-case-restored',
    );
  }

  @override
  Future<List<VoidedLearningCaseSummary>> listVoidedLearningCases({
    required String profileId,
  }) async => const <VoidedLearningCaseSummary>[];
}

class _UploadCall {
  const _UploadCall({required this.caseId, required this.evidenceId});

  final String caseId;
  final String evidenceId;
}

class _FakeEvidenceAttachmentRepository extends Fake
    implements EvidenceAttachmentRepository {
  _FakeEvidenceAttachmentRepository({this.log});

  final List<String>? log;
  final uploads = <_UploadCall>[];

  @override
  Future<CaseEvidenceAttachment> upload({
    required String organizationId,
    required String learningCaseId,
    required String evidenceId,
    required String attachmentId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    uploads.add(_UploadCall(caseId: learningCaseId, evidenceId: evidenceId));
    log?.add('upload');
    return CaseEvidenceAttachment(
      id: attachmentId,
      organizationId: organizationId,
      learningCaseId: learningCaseId,
      caseEvidenceId: evidenceId,
      storageBucket: caseEvidenceAttachmentBucket,
      storagePath: 'test/$attachmentId.jpg',
      originalFileName: fileName,
      contentType: contentType,
      sizeBytes: bytes.length,
      createdAt: DateTime(2026, 9, 9),
    );
  }
}
