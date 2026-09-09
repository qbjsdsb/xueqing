import '../../cloud/evidence_attachment_repository.dart';
import '../../cloud/learning_repository.dart';
import '../../cloud/progressive_case_repository.dart';
import '../teacher_workspace/presentation/evidence_attachment_picker.dart';

class V2CaseTypeChoice {
  const V2CaseTypeChoice({
    required this.key,
    required this.label,
    required this.baseType,
    this.organizationCaseTypeId,
  });

  final String key;
  final String label;
  final LearningCaseType baseType;
  final String? organizationCaseTypeId;
}

class V2QuickCaptureWrite {
  const V2QuickCaptureWrite({
    required this.operationId,
    required this.studentId,
    required this.subject,
    required this.caseTypeKey,
    required this.body,
    required this.attachments,
    this.observedAt,
  });

  final String operationId;
  final String studentId;
  final String subject;
  final String caseTypeKey;
  final String body;
  final List<PickedEvidenceAttachment> attachments;
  final DateTime? observedAt;
}

class V2ProgressWrite {
  const V2ProgressWrite({
    required this.operationId,
    required this.photoEvidenceOperationId,
    required this.caseId,
    required this.progressKind,
    required this.summary,
    required this.nextStep,
    required this.attachments,
    this.assessmentResult,
    this.occurredAt,
    this.completeCurrentAction = false,
    this.nextActionTitle,
    this.nextActionDueOn,
    this.closeReason,
    this.closeNote,
  });

  final String operationId;
  final String photoEvidenceOperationId;
  final String caseId;
  final CaseProgressKind progressKind;
  final String summary;
  final CaseAssessmentResult? assessmentResult;
  final DateTime? occurredAt;
  final bool completeCurrentAction;
  final CaseProgressNextStep nextStep;
  final String? nextActionTitle;
  final DateTime? nextActionDueOn;
  final CaseClosureReason? closeReason;
  final String? closeNote;
  final List<PickedEvidenceAttachment> attachments;
}

class V2WorkflowResult {
  const V2WorkflowResult({
    required this.caseId,
    required this.caseVersion,
    required this.attachmentCount,
  });

  final String caseId;
  final int caseVersion;
  final int attachmentCount;
}

class V2WorkflowSaveException implements Exception {
  const V2WorkflowSaveException(
    this.userMessage, {
    required this.recordMayBeSaved,
    this.cause,
  });

  final String userMessage;
  final bool recordMayBeSaved;
  final Object? cause;

  @override
  String toString() => userMessage;
}

class V2WorkflowController {
  V2WorkflowController({
    required this.workspace,
    required this.learningRepository,
    required this.progressiveCaseRepository,
    this.evidenceAttachmentRepository,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TeacherWorkspace workspace;
  final LearningRepository learningRepository;
  final ProgressiveCaseRepository progressiveCaseRepository;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
  final DateTime Function() _now;

  List<String> subjectsForStudent(String studentId) {
    final seen = <String>{};
    final result = <String>[];
    for (final profile in workspace.students) {
      if (profile.id != studentId) {
        continue;
      }
      final subject = profile.subject.trim();
      if (subject.isNotEmpty && seen.add(subject)) {
        result.add(subject);
      }
    }
    return List<String>.unmodifiable(result);
  }

  List<V2CaseTypeChoice> get caseTypeChoices {
    final result = <V2CaseTypeChoice>[
      const V2CaseTypeChoice(
        key: 'unclassified',
        label: '暂不分类',
        baseType: LearningCaseType.other,
      ),
    ];
    for (final type in workspace.caseTypes) {
      if (!type.isActive || type.key == 'builtin:other') {
        continue;
      }
      result.add(
        V2CaseTypeChoice(
          key: type.key,
          label: type.label,
          baseType: type.baseType,
          organizationCaseTypeId: type.id,
        ),
      );
    }
    return List<V2CaseTypeChoice>.unmodifiable(result);
  }

  Future<V2WorkflowResult> quickCapture(V2QuickCaptureWrite write) async {
    final body = write.body.trim();
    if (body.isEmpty) {
      throw ArgumentError('body cannot be empty.');
    }
    final profile = _profileFor(write.studentId, write.subject);
    final caseType = _caseTypeFor(write.caseTypeKey);
    _assertAttachmentCapability(write.attachments);

    final receipt = await learningRepository.quickCapture(
      QuickCaptureCommand(
        operationId: write.operationId,
        profileId: profile.profileId,
        expectedProfileVersion: profile.profileVersion,
        caseType: caseType.baseType,
        organizationCaseTypeId: caseType.organizationCaseTypeId,
        title: _headline(body),
        description: null,
        observedAt: write.observedAt ?? _now(),
        evidenceSummary: body,
      ),
    );

    try {
      await _uploadAttachments(
        caseId: receipt.caseId,
        evidenceId: receipt.evidenceId,
        attachments: write.attachments,
      );
    } catch (error) {
      throw V2WorkflowSaveException(
        '文字记录已保存，但图片上传失败。请保留当前内容并重试保存图片。',
        recordMayBeSaved: true,
        cause: error,
      );
    }

    return V2WorkflowResult(
      caseId: receipt.caseId,
      caseVersion: receipt.caseVersion,
      attachmentCount: write.attachments.length,
    );
  }

  Future<V2WorkflowResult> recordProgress(V2ProgressWrite write) async {
    final summary = write.summary.trim();
    if (summary.isEmpty) {
      throw ArgumentError('summary cannot be empty.');
    }
    final learningCase = _caseFor(write.caseId);
    _assertAttachmentCapability(write.attachments);

    final needsCompanionEvidence =
        write.attachments.isNotEmpty &&
        (write.progressKind != CaseProgressKind.observation ||
            write.nextStep == CaseProgressNextStep.close);

    var expectedCaseVersion = learningCase.version;
    if (needsCompanionEvidence) {
      late final CaseCommandReceipt evidenceReceipt;
      try {
        evidenceReceipt = await learningRepository.addCaseEvidence(
          AddCaseEvidenceCommand(
            operationId: write.photoEvidenceOperationId,
            caseId: learningCase.id,
            expectedCaseVersion: expectedCaseVersion,
            sourceType: 'observation',
            title: _photoEvidenceTitle(write.progressKind),
            observedAt: write.occurredAt ?? _now(),
            summary: summary,
          ),
        );
        final evidenceId = evidenceReceipt.recordId;
        if (evidenceId == null || evidenceId.trim().isEmpty) {
          throw const FormatException(
            'Photo evidence command did not return an evidence id.',
          );
        }
        await _uploadAttachments(
          caseId: learningCase.id,
          evidenceId: evidenceId,
          attachments: write.attachments,
        );
      } catch (error) {
        throw V2WorkflowSaveException(
          '图片证据尚未保存完整，进展还没有提交。请重试。',
          recordMayBeSaved: true,
          cause: error,
        );
      }
      expectedCaseVersion = evidenceReceipt.caseVersion;
    }

    final currentAction = write.completeCurrentAction
        ? learningCase.primaryAction
        : null;
    if (write.completeCurrentAction && currentAction == null) {
      throw const V2WorkflowSaveException(
        '当前待办已经变化，请刷新后再记录进展。',
        recordMayBeSaved: false,
      );
    }

    final progressReceipt = await progressiveCaseRepository.recordProgress(
      RecordCaseProgressCommand(
        operationId: write.operationId,
        caseId: learningCase.id,
        expectedCaseVersion: expectedCaseVersion,
        progressKind: write.progressKind,
        summary: summary,
        assessmentResult: write.assessmentResult,
        occurredAt: write.occurredAt,
        completeCurrentAction: write.completeCurrentAction,
        currentActionId: currentAction?.id,
        expectedActionVersion: currentAction?.version,
        nextStep: write.nextStep,
        nextActionTitle: _normalizedOptional(write.nextActionTitle),
        nextActionDueOn: write.nextActionDueOn,
        closeReason: write.closeReason,
        closeNote: _normalizedOptional(write.closeNote),
      ),
    );

    if (write.attachments.isNotEmpty && !needsCompanionEvidence) {
      final evidenceId = progressReceipt.recordId;
      if (evidenceId == null || evidenceId.trim().isEmpty) {
        throw const V2WorkflowSaveException(
          '文字记录已保存，但没有拿到图片关联信息。请刷新后检查。',
          recordMayBeSaved: true,
        );
      }
      try {
        await _uploadAttachments(
          caseId: learningCase.id,
          evidenceId: evidenceId,
          attachments: write.attachments,
        );
      } catch (error) {
        throw V2WorkflowSaveException(
          '文字记录已保存，但图片上传失败。请保留当前内容并重试保存图片。',
          recordMayBeSaved: true,
          cause: error,
        );
      }
    }

    return V2WorkflowResult(
      caseId: progressReceipt.caseId,
      caseVersion: progressReceipt.caseVersion,
      attachmentCount: write.attachments.length,
    );
  }

  WorkspaceStudent _profileFor(String studentId, String subject) {
    final normalizedSubject = subject.trim();
    for (final profile in workspace.students) {
      if (profile.id == studentId &&
          profile.subject.trim() == normalizedSubject) {
        return profile;
      }
    }
    throw StateError(
      'The selected student subject profile is no longer active.',
    );
  }

  WorkspaceCase _caseFor(String caseId) {
    for (final profile in workspace.students) {
      for (final learningCase in profile.cases) {
        if (learningCase.id == caseId) {
          return learningCase;
        }
      }
    }
    throw StateError('The selected learning case is no longer available.');
  }

  V2CaseTypeChoice _caseTypeFor(String key) {
    for (final choice in caseTypeChoices) {
      if (choice.key == key) {
        return choice;
      }
    }
    throw StateError('The selected case type is no longer available.');
  }

  void _assertAttachmentCapability(List<PickedEvidenceAttachment> attachments) {
    if (attachments.isEmpty) {
      return;
    }
    if (workspace.organizationId == null ||
        evidenceAttachmentRepository == null) {
      throw const V2WorkflowSaveException(
        '当前环境暂时不能保存图片，请移除图片后再试。',
        recordMayBeSaved: false,
      );
    }
  }

  Future<void> _uploadAttachments({
    required String caseId,
    required String evidenceId,
    required List<PickedEvidenceAttachment> attachments,
  }) async {
    if (attachments.isEmpty) {
      return;
    }
    final repository = evidenceAttachmentRepository!;
    final organizationId = workspace.organizationId!;
    for (final attachment in attachments) {
      await repository.upload(
        organizationId: organizationId,
        learningCaseId: caseId,
        evidenceId: evidenceId,
        attachmentId: attachment.attachmentId,
        bytes: attachment.bytes,
        fileName: attachment.fileName,
        contentType: attachment.contentType,
      );
    }
  }

  String _headline(String body) {
    final firstLine = body
        .split(RegExp(r'[\n。！？!?；;]'))
        .map((part) => part.trim())
        .firstWhere((part) => part.isNotEmpty, orElse: () => body.trim());
    if (firstLine.length <= 48) {
      return firstLine;
    }
    return '${firstLine.substring(0, 47)}…';
  }

  String _photoEvidenceTitle(CaseProgressKind kind) => switch (kind) {
    CaseProgressKind.observation => '本次表现图片',
    CaseProgressKind.intervention => '本次教学处理图片',
    CaseProgressKind.assessment => '本次检查图片',
  };

  String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
