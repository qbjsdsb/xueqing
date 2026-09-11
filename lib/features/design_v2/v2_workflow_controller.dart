import '../../cloud/case_reopen_draft_store.dart';
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

class V2ReopenWrite {
  const V2ReopenWrite({
    required this.caseId,
    required this.recurrenceSummary,
    required this.nextActionTitle,
    this.nextActionDueOn,
    this.observedAt,
  });

  final String caseId;
  final String recurrenceSummary;
  final String nextActionTitle;
  final DateTime? nextActionDueOn;
  final DateTime? observedAt;
}

class V2ReopenDraftSnapshot {
  const V2ReopenDraftSnapshot({
    required this.caseId,
    required this.recurrenceSummary,
    required this.nextActionTitle,
    required this.nextActionDueOn,
  });

  final String caseId;
  final String recurrenceSummary;
  final String nextActionTitle;
  final DateTime? nextActionDueOn;
}

class V2PendingActionSnapshot {
  const V2PendingActionSnapshot({
    required this.caseId,
    required this.caseVersion,
    required this.actionId,
    required this.actionVersion,
    required this.title,
    required this.dueOn,
    required this.canComplete,
  });

  final String caseId;
  final int caseVersion;
  final String actionId;
  final int actionVersion;
  final String title;
  final DateTime? dueOn;
  final bool canComplete;
}

class V2VoidedCaseItem {
  const V2VoidedCaseItem({
    required this.caseId,
    required this.profileId,
    required this.subject,
    required this.title,
    required this.caseStatus,
    required this.caseVersion,
    required this.reasonLabel,
    required this.voidedAt,
    required this.voidedByName,
    this.note,
  });

  final String caseId;
  final String profileId;
  final String subject;
  final String title;
  final String caseStatus;
  final int caseVersion;
  final String reasonLabel;
  final String? note;
  final DateTime voidedAt;
  final String voidedByName;
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
    this.caseReopenDraftStore,
    this.sessionUserId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TeacherWorkspace workspace;
  final LearningRepository learningRepository;
  final ProgressiveCaseRepository progressiveCaseRepository;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
  final CaseReopenDraftStore? caseReopenDraftStore;
  final String? sessionUserId;
  final DateTime Function() _now;

  LearningCaseRecordRepository? get _recordRepository =>
      progressiveCaseRepository is LearningCaseRecordRepository
      ? progressiveCaseRepository as LearningCaseRecordRepository
      : null;

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

  bool hasPendingPrimaryAction(String caseId) =>
      _caseFor(caseId).primaryAction != null;

  DateTime get businessDate => workspace.businessDate ?? _now();

  V2PendingActionSnapshot? pendingActionFor(String caseId) {
    final learningCase = _caseFor(caseId);
    final action = learningCase.primaryAction;
    if (action == null) {
      return null;
    }
    return V2PendingActionSnapshot(
      caseId: learningCase.id,
      caseVersion: learningCase.version,
      actionId: action.id,
      actionVersion: action.version,
      title: action.title,
      dueOn: action.businessDueDate ?? action.dueAt,
      canComplete: learningCase.status != LearningCaseStatus.newCase,
    );
  }

  Future<void> completeCurrentAction({
    required String operationId,
    required String caseId,
  }) async {
    final action = pendingActionFor(caseId);
    if (action == null) {
      throw const V2WorkflowSaveException(
        '当前提醒已经变化，请刷新后再试。',
        recordMayBeSaved: false,
      );
    }
    if (!action.canComplete) {
      throw const V2WorkflowSaveException(
        '这个新问题还需要先确认，再完成后续提醒。',
        recordMayBeSaved: false,
      );
    }
    await learningRepository.completeCaseAction(
      CompleteCaseActionCommand(
        operationId: operationId,
        actionId: action.actionId,
        caseId: action.caseId,
        expectedCaseVersion: action.caseVersion,
        expectedActionVersion: action.actionVersion,
      ),
    );
  }

  Future<void> rescheduleCurrentAction({
    required String operationId,
    required String caseId,
    required DateTime? dueOn,
  }) async {
    final action = pendingActionFor(caseId);
    if (action == null) {
      throw const V2WorkflowSaveException(
        '当前提醒已经变化，请刷新后再试。',
        recordMayBeSaved: false,
      );
    }
    await learningRepository.rescheduleCaseAction(
      RescheduleCaseActionCommand(
        operationId: operationId,
        actionId: action.actionId,
        caseId: action.caseId,
        expectedCaseVersion: action.caseVersion,
        expectedActionVersion: action.actionVersion,
        dueOn: dueOn,
      ),
    );
  }

  Future<void> voidCase({
    required String operationId,
    required String caseId,
    required CaseVoidReason reason,
    String? note,
  }) async {
    final repository = _recordRepository;
    if (repository == null) {
      throw const V2WorkflowSaveException(
        '当前版本暂时不能安全作废学情，请更新后重试。',
        recordMayBeSaved: false,
      );
    }
    final learningCase = _caseFor(caseId);
    try {
      await repository.voidLearningCase(
        VoidLearningCaseCommand(
          operationId: operationId,
          caseId: learningCase.id,
          expectedCaseVersion: learningCase.version,
          reason: reason,
          note: _normalizedOptional(note),
        ),
      );
    } catch (error) {
      final detail = error.toString().toLowerCase();
      if (detail.contains('version_conflict') ||
          detail.contains('case_already_voided') ||
          detail.contains('case_record_voided')) {
        throw V2WorkflowSaveException(
          '这条学情刚刚有变化，请刷新后再作废。',
          recordMayBeSaved: false,
          cause: error,
        );
      }
      if (detail.contains('teaching_fact_gate') ||
          detail.contains('manager_permission_required') ||
          detail.contains('permission') ||
          detail.contains('forbidden')) {
        throw V2WorkflowSaveException(
          '你当前不能作废这条学情，请确认仍在负责这名学生后再试。',
          recordMayBeSaved: false,
          cause: error,
        );
      }
      if (_looksLikeNetworkError(detail)) {
        throw V2WorkflowSaveException(
          '网络中断，作废结果暂时无法确认。操作编号已经保留，可以直接重试。',
          recordMayBeSaved: true,
          cause: error,
        );
      }
      throw V2WorkflowSaveException(
        '这条学情暂时无法作废，请稍后重试。',
        recordMayBeSaved: false,
        cause: error,
      );
    }
  }

  Future<List<V2VoidedCaseItem>> listVoidedCasesForStudent(
    String studentId,
  ) async {
    final repository = _recordRepository;
    if (repository == null) return const <V2VoidedCaseItem>[];
    final result = <V2VoidedCaseItem>[];
    for (final profile in workspace.students) {
      if (profile.id != studentId) continue;
      final rows = await repository.listVoidedLearningCases(
        profileId: profile.profileId,
      );
      for (final row in rows) {
        result.add(
          V2VoidedCaseItem(
            caseId: row.caseId,
            profileId: row.profileId,
            subject: profile.subject,
            title: row.title,
            caseStatus: row.caseStatus,
            caseVersion: row.caseVersion,
            reasonLabel: _voidReasonLabel(row.voidReason),
            note: row.voidNote,
            voidedAt: row.voidedAt,
            voidedByName: row.voidedByName,
          ),
        );
      }
    }
    result.sort((left, right) => right.voidedAt.compareTo(left.voidedAt));
    return List<V2VoidedCaseItem>.unmodifiable(result);
  }

  Future<void> restoreVoidedCase({
    required String operationId,
    required V2VoidedCaseItem item,
  }) async {
    final repository = _recordRepository;
    if (repository == null || !workspace.canManageOrganization) {
      throw const V2WorkflowSaveException(
        '只有负责人或管理员可以恢复已作废学情。',
        recordMayBeSaved: false,
      );
    }
    try {
      await repository.restoreLearningCase(
        RestoreLearningCaseCommand(
          operationId: operationId,
          caseId: item.caseId,
          expectedCaseVersion: item.caseVersion,
        ),
      );
    } catch (error) {
      final detail = error.toString().toLowerCase();
      if (detail.contains('version_conflict') ||
          detail.contains('case_not_voided')) {
        throw V2WorkflowSaveException(
          '这条学情刚刚有变化，请刷新后再恢复。',
          recordMayBeSaved: false,
          cause: error,
        );
      }
      if (detail.contains('case_restore_context_inactive')) {
        throw V2WorkflowSaveException(
          '这条学情所属的学生或学科服务已停用；请先恢复对应学科服务，再恢复学情。',
          recordMayBeSaved: false,
          cause: error,
        );
      }
      if (detail.contains('case_restore_responsibility_unavailable')) {
        throw V2WorkflowSaveException(
          '暂时找不到可接手这条学情的有效责任人；请先检查成员和任课设置。',
          recordMayBeSaved: false,
          cause: error,
        );
      }
      if (detail.contains('manager_permission_required') ||
          detail.contains('permission') ||
          detail.contains('forbidden')) {
        throw V2WorkflowSaveException(
          '只有负责人或管理员可以恢复已作废学情。',
          recordMayBeSaved: false,
          cause: error,
        );
      }
      if (_looksLikeNetworkError(detail)) {
        throw V2WorkflowSaveException(
          '网络中断，恢复结果暂时无法确认。操作编号已经保留，可以直接重试。',
          recordMayBeSaved: true,
          cause: error,
        );
      }
      throw V2WorkflowSaveException(
        '这条学情暂时无法恢复，请稍后重试。',
        recordMayBeSaved: false,
        cause: error,
      );
    }
  }

  bool canReopenClosedCase(String caseId) {
    if (caseReopenDraftStore == null || _reopenDraftScopeKey(caseId) == null) {
      return false;
    }
    try {
      return _caseFor(caseId).status == LearningCaseStatus.closed;
    } on StateError {
      return false;
    }
  }

  Future<V2ReopenDraftSnapshot?> loadPendingReopen(String caseId) async {
    if (!canReopenClosedCase(caseId)) {
      return null;
    }
    final scopeKey = _reopenDraftScopeKey(caseId)!;
    try {
      final draft = await caseReopenDraftStore!.load(scopeKey);
      if (draft == null) {
        return null;
      }
      if (draft.caseId != caseId) {
        throw const FormatException('Case reopen draft identity mismatch.');
      }
      return V2ReopenDraftSnapshot(
        caseId: draft.caseId,
        recurrenceSummary: draft.evidenceSummary,
        nextActionTitle: draft.nextActionTitle,
        nextActionDueOn: draft.nextActionDueOn,
      );
    } catch (error) {
      throw V2WorkflowSaveException(
        '上次未完成的重新跟进暂时无法恢复，请重试。',
        recordMayBeSaved: false,
        cause: error,
      );
    }
  }

  Future<V2WorkflowResult> reopenClosedCase(V2ReopenWrite write) async {
    final learningCase = _caseFor(write.caseId);
    if (learningCase.status != LearningCaseStatus.closed) {
      throw const V2WorkflowSaveException(
        '这个问题已经不是已结束状态，请刷新后再处理。',
        recordMayBeSaved: false,
      );
    }
    final store = caseReopenDraftStore;
    final scopeKey = _reopenDraftScopeKey(write.caseId);
    if (store == null || scopeKey == null) {
      throw const V2WorkflowSaveException(
        '当前登录状态无法安全恢复重新跟进，请刷新或重新登录后再试。',
        recordMayBeSaved: false,
      );
    }

    CaseReopenDraft? draft;
    try {
      draft = await store.load(scopeKey);
    } catch (error) {
      throw V2WorkflowSaveException(
        '上次未完成的重新跟进暂时无法恢复，请重试。',
        recordMayBeSaved: false,
        cause: error,
      );
    }

    if (draft == null) {
      final summary = write.recurrenceSummary.trim();
      final nextActionTitle = write.nextActionTitle.trim();
      if (summary.isEmpty) {
        throw const V2WorkflowSaveException(
          '请先写清楚这次为什么需要重新跟进。',
          recordMayBeSaved: false,
        );
      }
      if (nextActionTitle.isEmpty) {
        throw const V2WorkflowSaveException(
          '请写清楚下一步准备做什么。',
          recordMayBeSaved: false,
        );
      }
      final dueOn = write.nextActionDueOn;
      if (dueOn != null) {
        final dueDay = DateTime(dueOn.year, dueOn.month, dueOn.day);
        final currentBusinessDate = businessDate;
        final businessDay = DateTime(
          currentBusinessDate.year,
          currentBusinessDate.month,
          currentBusinessDate.day,
        );
        if (dueDay.isBefore(businessDay)) {
          throw const V2WorkflowSaveException(
            '下一次跟进日期不能早于机构业务日。',
            recordMayBeSaved: false,
          );
        }
      }
      draft = CaseReopenDraft(
        schemaVersion: CaseReopenDraft.currentSchemaVersion,
        caseId: learningCase.id,
        expectedCaseVersion: learningCase.version,
        evidenceOperationId: createOperationId(),
        reopenOperationId: createOperationId(),
        sourceType: 'observation',
        evidenceTitle: '问题再次出现',
        evidenceSummary: summary,
        observedAt: write.observedAt ?? _now(),
        evidenceVersion: 1,
        nextActionTypeWire: CaseActionType.verify.wireValue,
        nextActionTitle: nextActionTitle,
        nextActionDueOn: dueOn,
      );
      try {
        await store.save(scopeKey, draft);
      } catch (error) {
        throw V2WorkflowSaveException(
          '重新跟进还没有开始保存，请检查本机存储后重试。',
          recordMayBeSaved: false,
          cause: error,
        );
      }
    } else if (draft.caseId != learningCase.id) {
      throw const V2WorkflowSaveException(
        '恢复的重新跟进与当前问题不一致，请刷新后再试。',
        recordMayBeSaved: false,
      );
    }

    var currentDraft = draft;
    var evidenceId = currentDraft.evidenceId;
    if (evidenceId == null) {
      late final CaseCommandReceipt evidenceReceipt;
      try {
        evidenceReceipt = await learningRepository.addCaseEvidence(
          AddCaseEvidenceCommand(
            operationId: currentDraft.evidenceOperationId,
            caseId: currentDraft.caseId,
            expectedCaseVersion: currentDraft.expectedCaseVersion,
            sourceType: currentDraft.sourceType,
            title: currentDraft.evidenceTitle,
            observedAt: currentDraft.observedAt,
            summary: currentDraft.evidenceSummary,
          ),
        );
      } catch (error) {
        throw V2WorkflowSaveException(
          '“再次出现”的证据尚未确认保存完整。原操作已经保留，请直接重试。',
          recordMayBeSaved: true,
          cause: error,
        );
      }
      evidenceId = evidenceReceipt.recordId;
      if (evidenceId == null || evidenceId.trim().isEmpty) {
        throw const V2WorkflowSaveException(
          '“再次出现”的证据可能已保存，但没有拿到关联信息。请直接重试。',
          recordMayBeSaved: true,
        );
      }
      currentDraft = CaseReopenDraft(
        schemaVersion: currentDraft.schemaVersion,
        caseId: currentDraft.caseId,
        expectedCaseVersion: evidenceReceipt.caseVersion,
        evidenceOperationId: currentDraft.evidenceOperationId,
        reopenOperationId: currentDraft.reopenOperationId,
        sourceType: currentDraft.sourceType,
        evidenceTitle: currentDraft.evidenceTitle,
        evidenceSummary: currentDraft.evidenceSummary,
        observedAt: currentDraft.observedAt,
        evidenceId: evidenceId,
        evidenceVersion: currentDraft.evidenceVersion,
        nextActionTypeWire: currentDraft.nextActionTypeWire,
        nextActionTitle: currentDraft.nextActionTitle,
        nextActionDueOn: currentDraft.nextActionDueOn,
      );
      try {
        await store.save(scopeKey, currentDraft);
      } catch (error) {
        throw V2WorkflowSaveException(
          '“再次出现”的证据已处理，但恢复信息还没保存完整。请直接重试。',
          recordMayBeSaved: true,
          cause: error,
        );
      }
    }

    late final CaseCommandReceipt reopenReceipt;
    try {
      reopenReceipt = await learningRepository.reopenCase(
        ReopenCaseCommand(
          operationId: currentDraft.reopenOperationId,
          caseId: currentDraft.caseId,
          expectedCaseVersion: currentDraft.expectedCaseVersion,
          recurrenceEvidenceIds: <String>[evidenceId],
          expectedEvidenceVersions: <String, int>{
            evidenceId: currentDraft.evidenceVersion,
          },
          nextActionType: _caseActionTypeFromWire(
            currentDraft.nextActionTypeWire,
          ),
          nextActionTitle: currentDraft.nextActionTitle,
          nextActionDueOn: currentDraft.nextActionDueOn,
        ),
      );
    } catch (error) {
      throw V2WorkflowSaveException(
        '重新跟进尚未完整完成。证据和操作编号已经保留，请直接重试。',
        recordMayBeSaved: true,
        cause: error,
      );
    }

    try {
      await store.clear(scopeKey);
    } catch (_) {
      // Keep the committed draft rather than hiding a successful server result.
      // Reusing the same operation id is idempotent and therefore safe.
    }

    return V2WorkflowResult(
      caseId: reopenReceipt.caseId,
      caseVersion: reopenReceipt.caseVersion,
      attachmentCount: 0,
    );
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
    final progressOccurredAt = needsCompanionEvidence
        ? (write.occurredAt ?? _now())
        : write.occurredAt;

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
            observedAt: progressOccurredAt!,
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
        occurredAt: progressOccurredAt,
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

  String? _reopenDraftScopeKey(String caseId) {
    final userId = sessionUserId?.trim();
    final organizationId = workspace.organizationId?.trim();
    final normalizedCaseId = caseId.trim();
    if (userId == null ||
        userId.isEmpty ||
        organizationId == null ||
        organizationId.isEmpty ||
        normalizedCaseId.isEmpty) {
      return null;
    }
    return 'user:$userId|organization:$organizationId|case:$normalizedCaseId';
  }

  CaseActionType _caseActionTypeFromWire(String wire) => switch (wire) {
    'reteach' => CaseActionType.reteach,
    'practice' => CaseActionType.practice,
    'verify' => CaseActionType.verify,
    'communicate' => CaseActionType.communicate,
    'review' => CaseActionType.review,
    'other' => CaseActionType.other,
    _ => throw StateError('Unsupported reopen next action type: $wire'),
  };

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
    CaseProgressKind.observation => v2ObservationPhotoCompanionTitle,
    CaseProgressKind.intervention => v2InterventionPhotoCompanionTitle,
    CaseProgressKind.assessment => v2AssessmentPhotoCompanionTitle,
  };

  String _voidReasonLabel(String wire) => switch (wire) {
    'mistake' => CaseVoidReason.mistake.label,
    'duplicate' => CaseVoidReason.duplicate.label,
    'wrong_student_subject' => CaseVoidReason.wrongStudentSubject.label,
    'legacy_delete' => '旧版删除记录',
    _ => CaseVoidReason.other.label,
  };

  bool _looksLikeNetworkError(String detail) =>
      detail.contains('network') ||
      detail.contains('socket') ||
      detail.contains('timeout') ||
      detail.contains('connection') ||
      detail.contains('handshake');

  String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
