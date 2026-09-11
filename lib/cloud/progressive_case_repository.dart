import 'package:supabase_flutter/supabase_flutter.dart';

import 'learning_repository.dart';

enum CaseProgressKind { observation, intervention, assessment }

extension CaseProgressKindPresentation on CaseProgressKind {
  String get wireValue => switch (this) {
    CaseProgressKind.observation => 'observation',
    CaseProgressKind.intervention => 'intervention',
    CaseProgressKind.assessment => 'assessment',
  };

  String get label => switch (this) {
    CaseProgressKind.observation => '新表现',
    CaseProgressKind.intervention => '教学处理',
    CaseProgressKind.assessment => '检查结果',
  };
}

enum CaseProgressNextStep { continueTracking, remind, close }

extension CaseProgressNextStepPresentation on CaseProgressNextStep {
  String get wireValue => switch (this) {
    CaseProgressNextStep.continueTracking => 'continue',
    CaseProgressNextStep.remind => 'remind',
    CaseProgressNextStep.close => 'close',
  };

  String get label => switch (this) {
    CaseProgressNextStep.continueTracking => '继续观察',
    CaseProgressNextStep.remind => '设置提醒',
    CaseProgressNextStep.close => '结束跟进',
  };
}

enum CaseClosureReason { resolved, pauseTracking, notIssue, other }

extension CaseClosureReasonPresentation on CaseClosureReason {
  String get wireValue => switch (this) {
    CaseClosureReason.resolved => 'resolved',
    CaseClosureReason.pauseTracking => 'pause_tracking',
    CaseClosureReason.notIssue => 'not_issue',
    CaseClosureReason.other => 'other',
  };

  String get label => switch (this) {
    CaseClosureReason.resolved => '问题已解决',
    CaseClosureReason.pauseTracking => '暂不继续跟进',
    CaseClosureReason.notIssue => '确认不是问题',
    CaseClosureReason.other => '结束当前跟进',
  };
}

enum CaseVoidReason { mistake, duplicate, wrongStudentSubject, other }

extension CaseVoidReasonPresentation on CaseVoidReason {
  String get wireValue => switch (this) {
    CaseVoidReason.mistake => 'mistake',
    CaseVoidReason.duplicate => 'duplicate',
    CaseVoidReason.wrongStudentSubject => 'wrong_student_subject',
    CaseVoidReason.other => 'other',
  };

  String get label => switch (this) {
    CaseVoidReason.mistake => '误记录',
    CaseVoidReason.duplicate => '重复记录',
    CaseVoidReason.wrongStudentSubject => '录错学生或学科',
    CaseVoidReason.other => '其他',
  };
}

class RecordCaseProgressCommand {
  const RecordCaseProgressCommand({
    required this.operationId,
    required this.caseId,
    required this.expectedCaseVersion,
    required this.progressKind,
    required this.summary,
    required this.nextStep,
    this.assessmentResult,
    this.occurredAt,
    this.completeCurrentAction = false,
    this.currentActionId,
    this.expectedActionVersion,
    this.nextActionTitle,
    this.nextActionDueOn,
    this.closeReason,
    this.closeNote,
  });

  final String operationId;
  final String caseId;
  final int expectedCaseVersion;
  final CaseProgressKind progressKind;
  final String summary;
  final CaseAssessmentResult? assessmentResult;
  final DateTime? occurredAt;
  final bool completeCurrentAction;
  final String? currentActionId;
  final int? expectedActionVersion;
  final CaseProgressNextStep nextStep;
  final String? nextActionTitle;
  final DateTime? nextActionDueOn;
  final CaseClosureReason? closeReason;
  final String? closeNote;

  void validate() {
    _validateCaseIdentity(
      operationId: operationId,
      caseId: caseId,
      expectedCaseVersion: expectedCaseVersion,
    );
    if (summary.trim().isEmpty) {
      throw ArgumentError('summary cannot be empty.');
    }
    if (progressKind == CaseProgressKind.assessment) {
      if (assessmentResult == null) {
        throw ArgumentError('assessmentResult is required for assessment.');
      }
    } else if (assessmentResult != null) {
      throw ArgumentError('assessmentResult is only valid for assessment.');
    }
    if (completeCurrentAction) {
      if (currentActionId == null ||
          currentActionId!.trim().isEmpty ||
          expectedActionVersion == null ||
          expectedActionVersion! <= 0) {
        throw ArgumentError(
          'current action identity is required when completing an action.',
        );
      }
    } else if (currentActionId != null || expectedActionVersion != null) {
      throw ArgumentError(
        'current action identity is only valid when completing an action.',
      );
    }
    if (nextStep == CaseProgressNextStep.remind) {
      if (nextActionTitle != null && nextActionTitle!.trim().isEmpty) {
        throw ArgumentError('nextActionTitle cannot be blank.');
      }
      if (closeReason != null || closeNote != null) {
        throw ArgumentError('closure fields are not valid for reminder.');
      }
    } else if (nextStep == CaseProgressNextStep.close) {
      if (closeReason == null) {
        throw ArgumentError('closeReason is required when closing.');
      }
      if (nextActionTitle != null || nextActionDueOn != null) {
        throw ArgumentError('next action fields are not valid when closing.');
      }
    } else {
      if (nextActionTitle != null ||
          nextActionDueOn != null ||
          closeReason != null ||
          closeNote != null) {
        throw ArgumentError(
          'next action and closure fields are not valid when continuing.',
        );
      }
    }
  }
}

class EndCaseFollowUpCommand {
  const EndCaseFollowUpCommand({
    required this.operationId,
    required this.caseId,
    required this.expectedCaseVersion,
    required this.reason,
    this.note,
    this.closedAt,
  });

  final String operationId;
  final String caseId;
  final int expectedCaseVersion;
  final CaseClosureReason reason;
  final String? note;
  final DateTime? closedAt;

  void validate() {
    _validateCaseIdentity(
      operationId: operationId,
      caseId: caseId,
      expectedCaseVersion: expectedCaseVersion,
    );
  }
}

class VoidLearningCaseCommand {
  const VoidLearningCaseCommand({
    required this.operationId,
    required this.caseId,
    required this.expectedCaseVersion,
    required this.reason,
    this.note,
  });

  final String operationId;
  final String caseId;
  final int expectedCaseVersion;
  final CaseVoidReason reason;
  final String? note;

  void validate() => _validateCaseIdentity(
    operationId: operationId,
    caseId: caseId,
    expectedCaseVersion: expectedCaseVersion,
  );
}

class RestoreLearningCaseCommand {
  const RestoreLearningCaseCommand({
    required this.operationId,
    required this.caseId,
    required this.expectedCaseVersion,
  });

  final String operationId;
  final String caseId;
  final int expectedCaseVersion;

  void validate() => _validateCaseIdentity(
    operationId: operationId,
    caseId: caseId,
    expectedCaseVersion: expectedCaseVersion,
  );
}

class VoidedLearningCaseSummary {
  const VoidedLearningCaseSummary({
    required this.caseId,
    required this.profileId,
    required this.title,
    required this.caseStatus,
    required this.caseVersion,
    required this.voidReason,
    required this.voidedAt,
    required this.voidedByName,
    this.voidNote,
  });

  final String caseId;
  final String profileId;
  final String title;
  final String caseStatus;
  final int caseVersion;
  final String voidReason;
  final String? voidNote;
  final DateTime voidedAt;
  final String voidedByName;

  factory VoidedLearningCaseSummary.fromJson(Map<String, dynamic> json) =>
      VoidedLearningCaseSummary(
        caseId: _requiredString(json['case_id'], 'case_id'),
        profileId: _requiredString(json['profile_id'], 'profile_id'),
        title: _requiredString(json['title'], 'title'),
        caseStatus: _requiredString(json['case_status'], 'case_status'),
        caseVersion: _requiredInt(json['case_version'], 'case_version'),
        voidReason: _requiredString(json['void_reason'], 'void_reason'),
        voidNote: _stringValue(json['void_note']),
        voidedAt: _requiredDateTime(json['voided_at'], 'voided_at'),
        voidedByName: _requiredString(json['voided_by_name'], 'voided_by_name'),
      );
}

class ProgressiveCaseReceipt {
  const ProgressiveCaseReceipt({
    required this.operationId,
    required this.caseId,
    required this.status,
    required this.caseVersion,
    this.nextStep,
    this.recordId,
    this.completedActionId,
    this.nextActionId,
    this.progressEventId,
    this.actionEventId,
    this.stableEventId,
    this.closeEventId,
    this.eventId,
  });

  final String operationId;
  final String caseId;
  final String status;
  final int caseVersion;
  final String? nextStep;
  final String? recordId;
  final String? completedActionId;
  final String? nextActionId;
  final String? progressEventId;
  final String? actionEventId;
  final String? stableEventId;
  final String? closeEventId;
  final String? eventId;

  factory ProgressiveCaseReceipt.fromJson(Map<String, dynamic> json) {
    return ProgressiveCaseReceipt(
      operationId: _requiredString(json['operation_id'], 'operation_id'),
      caseId: _requiredString(json['case_id'], 'case_id'),
      status: _requiredString(json['status'], 'status'),
      caseVersion: _requiredInt(json['case_version'], 'case_version'),
      nextStep: _stringValue(json['next_step']),
      recordId: _stringValue(json['record_id']),
      completedActionId: _stringValue(json['completed_action_id']),
      nextActionId: _stringValue(json['next_action_id']),
      progressEventId: _stringValue(json['progress_event_id']),
      actionEventId: _stringValue(json['action_event_id']),
      stableEventId: _stringValue(json['stable_event_id']),
      closeEventId: _stringValue(json['close_event_id']),
      eventId: _stringValue(json['event_id']),
    );
  }
}

class LearningCaseRecordReceipt {
  const LearningCaseRecordReceipt({
    required this.operationId,
    required this.caseId,
    required this.recordState,
    required this.caseStatus,
    required this.caseVersion,
    required this.eventId,
  });

  final String operationId;
  final String caseId;
  final String recordState;
  final String caseStatus;
  final int caseVersion;
  final String eventId;

  factory LearningCaseRecordReceipt.fromJson(Map<String, dynamic> json) =>
      LearningCaseRecordReceipt(
        operationId: _requiredString(json['operation_id'], 'operation_id'),
        caseId: _requiredString(json['case_id'], 'case_id'),
        recordState: _requiredString(json['record_state'], 'record_state'),
        caseStatus: _requiredString(json['case_status'], 'case_status'),
        caseVersion: _requiredInt(json['case_version'], 'case_version'),
        eventId: _requiredString(json['event_id'], 'event_id'),
      );
}

abstract interface class ProgressiveCaseRepository {
  Future<ProgressiveCaseReceipt> recordProgress(
    RecordCaseProgressCommand command,
  );

  Future<ProgressiveCaseReceipt> endFollowUp(EndCaseFollowUpCommand command);
}

/// Optional governance capability kept separate from the teaching-progress
/// interface so existing form fakes and alternate repositories remain valid.
abstract interface class LearningCaseRecordRepository {
  Future<LearningCaseRecordReceipt> voidLearningCase(
    VoidLearningCaseCommand command,
  );

  Future<LearningCaseRecordReceipt> restoreLearningCase(
    RestoreLearningCaseCommand command,
  );

  Future<List<VoidedLearningCaseSummary>> listVoidedLearningCases({
    required String profileId,
  });
}

class SupabaseProgressiveCaseRepository
    implements ProgressiveCaseRepository, LearningCaseRecordRepository {
  SupabaseProgressiveCaseRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ProgressiveCaseReceipt> recordProgress(
    RecordCaseProgressCommand command,
  ) async {
    command.validate();
    return _invokeProgress(
      functionName: 'record_case_progress',
      params: <String, dynamic>{
        'p_operation_id': command.operationId,
        'p_case_id': command.caseId,
        'p_expected_case_version': command.expectedCaseVersion,
        'p_progress_kind': command.progressKind.wireValue,
        'p_summary': command.summary.trim(),
        'p_assessment_result': command.assessmentResult?.wireValue,
        'p_occurred_at': command.occurredAt?.toUtc().toIso8601String(),
        'p_complete_current_action': command.completeCurrentAction,
        'p_current_action_id': command.currentActionId,
        'p_expected_action_version': command.expectedActionVersion,
        'p_next_step': command.nextStep.wireValue,
        'p_next_action_title': command.nextActionTitle?.trim(),
        'p_next_action_due_on': _dateOnlyString(command.nextActionDueOn),
        'p_close_reason': command.closeReason?.wireValue,
        'p_close_note': command.closeNote?.trim(),
      },
    );
  }

  @override
  Future<ProgressiveCaseReceipt> endFollowUp(
    EndCaseFollowUpCommand command,
  ) async {
    command.validate();
    return _invokeProgress(
      functionName: 'end_case_follow_up',
      params: <String, dynamic>{
        'p_operation_id': command.operationId,
        'p_case_id': command.caseId,
        'p_expected_case_version': command.expectedCaseVersion,
        'p_reason': command.reason.wireValue,
        'p_note': command.note?.trim(),
        'p_closed_at': command.closedAt?.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<LearningCaseRecordReceipt> voidLearningCase(
    VoidLearningCaseCommand command,
  ) async {
    command.validate();
    return _invokeRecordCommand(
      functionName: 'void_learning_case',
      params: <String, dynamic>{
        'p_operation_id': command.operationId,
        'p_case_id': command.caseId,
        'p_expected_case_version': command.expectedCaseVersion,
        'p_reason': command.reason.wireValue,
        'p_note': command.note?.trim(),
      },
    );
  }

  @override
  Future<LearningCaseRecordReceipt> restoreLearningCase(
    RestoreLearningCaseCommand command,
  ) async {
    command.validate();
    return _invokeRecordCommand(
      functionName: 'restore_learning_case',
      params: <String, dynamic>{
        'p_operation_id': command.operationId,
        'p_case_id': command.caseId,
        'p_expected_case_version': command.expectedCaseVersion,
      },
    );
  }

  @override
  Future<List<VoidedLearningCaseSummary>> listVoidedLearningCases({
    required String profileId,
  }) async {
    if (profileId.trim().isEmpty) {
      throw ArgumentError('profileId is required.');
    }
    final expectedUserId = _requireSession();
    final response = await _client.rpc(
      'list_voided_learning_cases',
      params: <String, dynamic>{'p_profile_id': profileId},
    );
    _assertSameSession(expectedUserId);
    if (response is! List) {
      throw const FormatException(
        'list_voided_learning_cases returned an invalid result.',
      );
    }
    return List<VoidedLearningCaseSummary>.unmodifiable([
      for (final item in response)
        if (item is Map)
          VoidedLearningCaseSummary.fromJson(
            Map<String, dynamic>.from(item),
          )
        else
          throw const FormatException(
            'list_voided_learning_cases returned an invalid row.',
          ),
    ]);
  }

  Future<ProgressiveCaseReceipt> _invokeProgress({
    required String functionName,
    required Map<String, dynamic> params,
  }) async {
    final expectedUserId = _requireSession();
    final response = await _client.rpc(functionName, params: params);
    _assertSameSession(expectedUserId);
    if (response is! Map) {
      throw FormatException('$functionName returned an invalid result.');
    }
    return ProgressiveCaseReceipt.fromJson(Map<String, dynamic>.from(response));
  }

  Future<LearningCaseRecordReceipt> _invokeRecordCommand({
    required String functionName,
    required Map<String, dynamic> params,
  }) async {
    final expectedUserId = _requireSession();
    final response = await _client.rpc(functionName, params: params);
    _assertSameSession(expectedUserId);
    if (response is! Map) {
      throw FormatException('$functionName returned an invalid result.');
    }
    return LearningCaseRecordReceipt.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  String _requireSession() {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    return authUser.id;
  }

  void _assertSameSession(String expectedUserId) {
    if (_client.auth.currentUser?.id != expectedUserId) {
      throw const AuthException(
        'The active session changed while saving Case progress.',
      );
    }
  }
}

void _validateCaseIdentity({
  required String operationId,
  required String caseId,
  required int expectedCaseVersion,
}) {
  if (operationId.trim().isEmpty) {
    throw ArgumentError('operationId cannot be empty.');
  }
  if (caseId.trim().isEmpty) {
    throw ArgumentError('caseId cannot be empty.');
  }
  if (expectedCaseVersion <= 0) {
    throw ArgumentError('expectedCaseVersion must be positive.');
  }
}

String? _dateOnlyString(DateTime? value) {
  if (value == null) {
    return null;
  }
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _requiredString(dynamic value, String field) {
  final result = _stringValue(value);
  if (result == null || result.isEmpty) {
    throw FormatException('Missing $field in server response.');
  }
  return result;
}

String? _stringValue(dynamic value) {
  if (value == null) {
    return null;
  }
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

int _requiredInt(dynamic value, String field) {
  if (value is int) {
    return value;
  }
  final result = int.tryParse(value?.toString() ?? '');
  if (result == null) {
    throw FormatException('Missing $field in server response.');
  }
  return result;
}

DateTime _requiredDateTime(dynamic value, String field) {
  if (value is DateTime) return value;
  final result = DateTime.tryParse(value?.toString() ?? '');
  if (result == null) {
    throw FormatException('Missing $field in server response.');
  }
  return result;
}
