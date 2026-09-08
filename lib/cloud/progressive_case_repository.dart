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
      if (nextActionTitle == null || nextActionTitle!.trim().isEmpty) {
        throw ArgumentError('nextActionTitle is required for reminder.');
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

abstract interface class ProgressiveCaseRepository {
  Future<ProgressiveCaseReceipt> recordProgress(
    RecordCaseProgressCommand command,
  );

  Future<ProgressiveCaseReceipt> endFollowUp(EndCaseFollowUpCommand command);
}

class SupabaseProgressiveCaseRepository implements ProgressiveCaseRepository {
  SupabaseProgressiveCaseRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ProgressiveCaseReceipt> recordProgress(
    RecordCaseProgressCommand command,
  ) async {
    command.validate();
    return _invoke(
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
    return _invoke(
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

  Future<ProgressiveCaseReceipt> _invoke({
    required String functionName,
    required Map<String, dynamic> params,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    final expectedUserId = authUser.id;
    final response = await _client.rpc(functionName, params: params);
    if (_client.auth.currentUser?.id != expectedUserId) {
      throw const AuthException(
        'The active session changed while saving Case progress.',
      );
    }
    if (response is! Map) {
      throw FormatException('$functionName returned an invalid result.');
    }
    return ProgressiveCaseReceipt.fromJson(Map<String, dynamic>.from(response));
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
