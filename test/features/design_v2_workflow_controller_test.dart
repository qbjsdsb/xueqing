import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
      final controller = V2WorkflowController(
        workspace: _workspace(),
        learningRepository: learning,
        progressiveCaseRepository: progress,
        evidenceAttachmentRepository: attachments,
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
      expect(progress.calls.single.expectedCaseVersion, 4);
      expect(progress.calls.single.progressKind, CaseProgressKind.intervention);
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

WorkspaceCase _case() => WorkspaceCase(
  id: 'case-existing',
  profileId: 'profile-chinese',
  title: '阅读概括不完整',
  type: LearningCaseType.knowledge,
  status: LearningCaseStatus.confirmed,
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
  Future<CaseCommandReceipt> addCaseEvidence(
    AddCaseEvidenceCommand command,
  ) async {
    addEvidenceCalls.add(command);
    log?.add('add-evidence');
    return addEvidenceReceipt;
  }
}

class _FakeProgressiveCaseRepository extends Fake
    implements ProgressiveCaseRepository {
  _FakeProgressiveCaseRepository({this.log});

  final List<String>? log;
  final calls = <RecordCaseProgressCommand>[];
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
