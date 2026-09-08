import 'package:supabase_flutter/supabase_flutter.dart';

import '../export/learning_history_export.dart';
import 'paged_rows.dart';

abstract interface class LearningExportRepository {
  Future<LearningHistoryExportData> loadStudentSubjectHistory({
    required String organizationId,
    required String profileId,
    required String studentName,
    required String subjectName,
    required Map<String, String> teacherNamesByMembershipId,
  });

  Future<LearningHistoryExportData> loadTeacherHistory({
    required String organizationId,
    required String membershipId,
    required String teacherName,
    required Map<String, String> teacherNamesByMembershipId,
  });
}

class SupabaseLearningExportRepository implements LearningExportRepository {
  SupabaseLearningExportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<LearningHistoryExportData> loadStudentSubjectHistory({
    required String organizationId,
    required String profileId,
    required String studentName,
    required String subjectName,
    required Map<String, String> teacherNamesByMembershipId,
  }) async {
    final records = await _loadReadableHistory(
      organizationId: organizationId,
      teacherNamesByMembershipId: teacherNamesByMembershipId,
    );
    final filtered = <LearningHistoryRecord>[
      for (final item in records)
        if (item.profileId == profileId) item.record,
    ];
    final date = _fileDate(DateTime.now());
    return LearningHistoryExportData(
      title: '$studentName · $subjectName · 学情记录',
      suggestedFileName: sanitizeLearningHistoryFileName(
        '${studentName}_${subjectName}_学情记录_$date',
      ),
      records: List<LearningHistoryRecord>.unmodifiable(filtered),
    );
  }

  @override
  Future<LearningHistoryExportData> loadTeacherHistory({
    required String organizationId,
    required String membershipId,
    required String teacherName,
    required Map<String, String> teacherNamesByMembershipId,
  }) async {
    final records = await _loadReadableHistory(
      organizationId: organizationId,
      teacherNamesByMembershipId: teacherNamesByMembershipId,
    );
    final filtered = <LearningHistoryRecord>[
      for (final item in records)
        if (item.record.actorMembershipId == membershipId) item.record,
    ];
    final date = _fileDate(DateTime.now());
    return LearningHistoryExportData(
      title: '$teacherName · 教学记录',
      suggestedFileName: sanitizeLearningHistoryFileName(
        '${teacherName}_教学记录_$date',
      ),
      records: List<LearningHistoryRecord>.unmodifiable(filtered),
    );
  }

  Future<List<_ScopedHistoryRecord>> _loadReadableHistory({
    required String organizationId,
    required Map<String, String> teacherNamesByMembershipId,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    final expectedUserId = authUser.id;
    final rows = await Future.wait<List<Map<String, dynamic>>>([
      _rows(
        (from, to) => _client
            .from('student_subject_profiles')
            .select('id,student_id,organization_subject_id')
            .eq('organization_id', organizationId)
            .order('id')
            .range(from, to),
        expectedUserId,
      ),
      _rows(
        (from, to) => _client
            .from('students')
            .select('id,name')
            .eq('organization_id', organizationId)
            .order('id')
            .range(from, to),
        expectedUserId,
      ),
      _rows(
        (from, to) => _client
            .from('organization_subjects')
            .select('id,display_name')
            .eq('organization_id', organizationId)
            .order('id')
            .range(from, to),
        expectedUserId,
      ),
      _rows(
        (from, to) => _client
            .from('learning_cases')
            .select(
              'id,student_subject_profile_id,title,status,first_observed_at,'
              'created_by_membership_id',
            )
            .eq('organization_id', organizationId)
            .order('id')
            .range(from, to),
        expectedUserId,
      ),
      _rows(
        (from, to) => _client
            .from('case_evidence')
            .select(
              'id,learning_case_id,title,observed_at,summary,'
              'created_by_membership_id',
            )
            .eq('organization_id', organizationId)
            .order('id')
            .range(from, to),
        expectedUserId,
      ),
      _rows(
        (from, to) => _client
            .from('interventions')
            .select(
              'id,learning_case_id,strategy,notes,occurred_at,'
              'performed_by_membership_id',
            )
            .eq('organization_id', organizationId)
            .order('id')
            .range(from, to),
        expectedUserId,
      ),
      _rows(
        (from, to) => _client
            .from('assessments')
            .select(
              'id,learning_case_id,result,evidence_summary,notes,assessed_at,'
              'assessed_by_membership_id',
            )
            .eq('organization_id', organizationId)
            .order('id')
            .range(from, to),
        expectedUserId,
      ),
      _rows(
        (from, to) => _client
            .from('case_events')
            .select(
              'id,learning_case_id,event_type,actor_membership_id,occurred_at,'
              'metadata,operation_id,operation_event_key',
            )
            .eq('organization_id', organizationId)
            .order('id')
            .range(from, to),
        expectedUserId,
      ),
      _rows(
        (from, to) => _client
            .from('case_actions')
            .select('id,learning_case_id,title,due_at,status')
            .eq('organization_id', organizationId)
            .order('id')
            .range(from, to),
        expectedUserId,
      ),
      _rows(
        (from, to) => _client
            .from('case_evidence_attachments')
            .select('id,case_evidence_id,original_file_name')
            .eq('organization_id', organizationId)
            .order('id')
            .range(from, to),
        expectedUserId,
      ),
    ]);
    _assertSameSession(expectedUserId);

    final profiles = <String, Map<String, dynamic>>{
      for (final row in rows[0]) _requiredString(row['id'], 'profile_id'): row,
    };
    final students = <String, String>{
      for (final row in rows[1])
        _requiredString(row['id'], 'student_id'):
            _stringValue(row['name']) ?? '未命名学生',
    };
    final subjects = <String, String>{
      for (final row in rows[2])
        _requiredString(row['id'], 'subject_id'):
            _stringValue(row['display_name']) ?? '未命名学科',
    };
    final cases = <String, Map<String, dynamic>>{
      for (final row in rows[3]) _requiredString(row['id'], 'case_id'): row,
    };
    final evidenceByCase = _groupRows(rows[4], 'learning_case_id');
    final interventionsByCase = _groupRows(rows[5], 'learning_case_id');
    final assessmentsByCase = _groupRows(rows[6], 'learning_case_id');
    final eventsByCase = _groupRows(rows[7], 'learning_case_id');
    final actionsById = <String, Map<String, dynamic>>{
      for (final row in rows[8]) _requiredString(row['id'], 'action_id'): row,
    };
    final attachmentsByEvidence = _groupRows(rows[9], 'case_evidence_id');

    final result = <_ScopedHistoryRecord>[];
    for (final entry in cases.entries) {
      final caseId = entry.key;
      final learningCase = entry.value;
      final profileId = _requiredString(
        learningCase['student_subject_profile_id'],
        'student_subject_profile_id',
      );
      final profile = profiles[profileId];
      if (profile == null) {
        continue;
      }
      final studentName =
          students[_requiredString(profile['student_id'], 'student_id')] ??
          '未命名学生';
      final subjectName =
          subjects[_requiredString(
            profile['organization_subject_id'],
            'organization_subject_id',
          )] ??
          '未命名学科';
      final caseTitle = _stringValue(learningCase['title']) ?? '未命名问题';
      final currentStatus = _caseStatusLabel(learningCase['status']);
      final eventRows = eventsByCase[caseId] ?? const <Map<String, dynamic>>[];
      final operationTypes = <String, Set<String>>{};
      final eventByRecordId = <String, Map<String, dynamic>>{};
      final initialEvidenceIds = <String>{};
      for (final event in eventRows) {
        final operationId = _stringValue(event['operation_id']);
        final eventType = _stringValue(event['event_type']) ?? 'event';
        if (operationId != null) {
          operationTypes.putIfAbsent(operationId, () => <String>{}).add(eventType);
        }
        final metadata = _metadata(event['metadata']);
        final recordId = _recordIdFromMetadata(metadata);
        if (recordId != null) {
          eventByRecordId[recordId] = event;
        }
        if (eventType == 'case_created') {
          final evidenceId = _stringValue(metadata['evidence_id']);
          if (evidenceId != null) {
            initialEvidenceIds.add(evidenceId);
          }
        }
      }

      final foldedOperationIds = <String>{};
      for (final evidence in evidenceByCase[caseId] ?? const <Map<String, dynamic>>[]) {
        final evidenceId = _requiredString(evidence['id'], 'evidence_id');
        final event = eventByRecordId[evidenceId] ?? _caseCreatedEventForEvidence(
          eventRows,
          evidenceId,
        );
        final operationId = _stringValue(event?['operation_id']);
        if (operationId != null) {
          foldedOperationIds.add(operationId);
        }
        final actorMembershipId =
            _stringValue(evidence['created_by_membership_id']) ??
            _stringValue(event?['actor_membership_id']);
        final isInitial = initialEvidenceIds.contains(evidenceId) ||
            (initialEvidenceIds.isEmpty &&
                _isInitialEvidenceFallback(evidence, learningCase));
        final title = _stringValue(evidence['title']) ?? caseTitle;
        final summary = _stringValue(evidence['summary']) ?? '';
        final content = isInitial && title == caseTitle
            ? summary
            : '$title：$summary';
        result.add(
          _ScopedHistoryRecord(
            profileId: profileId,
            record: LearningHistoryRecord(
              occurredAt: _requiredDateTime(evidence['observed_at'], 'observed_at'),
              studentName: studentName,
              subjectName: subjectName,
              caseTitle: caseTitle,
              recordType: isInitial ? '发现问题' : '学生表现',
              content: content,
              nextStep: _nextStepForEvent(event, actionsById),
              teacherName: _teacherName(
                actorMembershipId,
                teacherNamesByMembershipId,
              ),
              attachmentSummary: _attachmentSummary(
                attachmentsByEvidence[evidenceId],
              ),
              currentStatus: currentStatus,
              actorMembershipId: actorMembershipId,
            ),
          ),
        );
      }

      for (final intervention in interventionsByCase[caseId] ?? const <Map<String, dynamic>>[]) {
        final id = _requiredString(intervention['id'], 'intervention_id');
        final event = eventByRecordId[id];
        final operationId = _stringValue(event?['operation_id']);
        if (operationId != null) {
          foldedOperationIds.add(operationId);
        }
        final actorMembershipId =
            _stringValue(intervention['performed_by_membership_id']) ??
            _stringValue(event?['actor_membership_id']);
        final strategy = _stringValue(intervention['strategy']) ?? '';
        final notes = _stringValue(intervention['notes']);
        result.add(
          _ScopedHistoryRecord(
            profileId: profileId,
            record: LearningHistoryRecord(
              occurredAt: _requiredDateTime(intervention['occurred_at'], 'occurred_at'),
              studentName: studentName,
              subjectName: subjectName,
              caseTitle: caseTitle,
              recordType: '教学处理',
              content: notes == null ? strategy : '$strategy\n$notes',
              nextStep: _nextStepForEvent(event, actionsById),
              teacherName: _teacherName(
                actorMembershipId,
                teacherNamesByMembershipId,
              ),
              currentStatus: currentStatus,
              actorMembershipId: actorMembershipId,
            ),
          ),
        );
      }

      for (final assessment in assessmentsByCase[caseId] ?? const <Map<String, dynamic>>[]) {
        final id = _requiredString(assessment['id'], 'assessment_id');
        final event = eventByRecordId[id];
        final operationId = _stringValue(event?['operation_id']);
        final types = operationId == null
            ? const <String>{}
            : operationTypes[operationId] ?? const <String>{};
        if (operationId != null) {
          foldedOperationIds.add(operationId);
        }
        final actorMembershipId =
            _stringValue(assessment['assessed_by_membership_id']) ??
            _stringValue(event?['actor_membership_id']);
        final resultLabel = _assessmentResultLabel(assessment['result']);
        final recordType = types.contains('case_closed')
            ? '检查结果 · 结束跟进'
            : types.contains('case_stabilized')
            ? '检查结果 · 暂时稳定'
            : '检查结果';
        final summary = _stringValue(assessment['evidence_summary']) ?? '';
        final notes = _stringValue(assessment['notes']);
        result.add(
          _ScopedHistoryRecord(
            profileId: profileId,
            record: LearningHistoryRecord(
              occurredAt: _requiredDateTime(assessment['assessed_at'], 'assessed_at'),
              studentName: studentName,
              subjectName: subjectName,
              caseTitle: caseTitle,
              recordType: recordType,
              content: notes == null ? summary : '$summary\n$notes',
              assessmentResult: resultLabel,
              nextStep: _nextStepForEvent(event, actionsById),
              teacherName: _teacherName(
                actorMembershipId,
                teacherNamesByMembershipId,
              ),
              currentStatus: currentStatus,
              actorMembershipId: actorMembershipId,
            ),
          ),
        );
      }

      for (final event in eventRows) {
        final eventType = _stringValue(event['event_type']) ?? 'event';
        final operationId = _stringValue(event['operation_id']);
        if (operationId != null && foldedOperationIds.contains(operationId)) {
          continue;
        }
        final lifecycle = _lifecyclePresentation(eventType, event['metadata']);
        if (lifecycle == null) {
          continue;
        }
        final actorMembershipId = _stringValue(event['actor_membership_id']);
        result.add(
          _ScopedHistoryRecord(
            profileId: profileId,
            record: LearningHistoryRecord(
              occurredAt: _requiredDateTime(event['occurred_at'], 'event_occurred_at'),
              studentName: studentName,
              subjectName: subjectName,
              caseTitle: caseTitle,
              recordType: lifecycle.type,
              content: lifecycle.text,
              nextStep: _nextStepForEvent(event, actionsById),
              teacherName: _teacherName(
                actorMembershipId,
                teacherNamesByMembershipId,
              ),
              currentStatus: currentStatus,
              actorMembershipId: actorMembershipId,
            ),
          ),
        );
      }
    }

    result.sort(
      (left, right) => left.record.occurredAt.compareTo(right.record.occurredAt),
    );
    return List<_ScopedHistoryRecord>.unmodifiable(result);
  }

  Future<List<Map<String, dynamic>>> _rows(
    PagedRowLoader loader,
    String expectedUserId,
  ) {
    return collectPagedRows(
      loadPage: loader,
      assertSession: () => _assertSameSession(expectedUserId),
      invalidResponseMessage: '导出记录读取失败。',
    );
  }

  void _assertSameSession(String expectedUserId) {
    if (_client.auth.currentUser?.id != expectedUserId) {
      throw const AuthException('The active session changed while exporting.');
    }
  }
}

class _ScopedHistoryRecord {
  const _ScopedHistoryRecord({required this.profileId, required this.record});

  final String profileId;
  final LearningHistoryRecord record;
}

class _LifecyclePresentation {
  const _LifecyclePresentation(this.type, this.text);

  final String type;
  final String text;
}

Map<String, List<Map<String, dynamic>>> _groupRows(
  List<Map<String, dynamic>> rows,
  String key,
) {
  final result = <String, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    final value = _stringValue(row[key]);
    if (value != null) {
      result.putIfAbsent(value, () => <Map<String, dynamic>>[]).add(row);
    }
  }
  return result;
}

Map<String, dynamic> _metadata(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

String? _recordIdFromMetadata(Map<String, dynamic> metadata) {
  for (final key in const <String>[
    'record_id',
    'evidence_id',
    'intervention_id',
    'assessment_id',
  ]) {
    final value = _stringValue(metadata[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

Map<String, dynamic>? _caseCreatedEventForEvidence(
  List<Map<String, dynamic>> events,
  String evidenceId,
) {
  for (final event in events) {
    if (_stringValue(event['event_type']) != 'case_created') {
      continue;
    }
    if (_stringValue(_metadata(event['metadata'])['evidence_id']) == evidenceId) {
      return event;
    }
  }
  return null;
}

bool _isInitialEvidenceFallback(
  Map<String, dynamic> evidence,
  Map<String, dynamic> learningCase,
) {
  final observedAt = _dateTimeValue(evidence['observed_at']);
  final firstObservedAt = _dateTimeValue(learningCase['first_observed_at']);
  if (observedAt == null || firstObservedAt == null) {
    return false;
  }
  return observedAt.difference(firstObservedAt).abs() < const Duration(seconds: 2) &&
      _stringValue(evidence['title']) == _stringValue(learningCase['title']);
}

String _teacherName(
  String? membershipId,
  Map<String, String> teacherNamesByMembershipId,
) {
  if (membershipId == null) {
    return '未记录老师';
  }
  return teacherNamesByMembershipId[membershipId] ?? '其他老师';
}

String? _attachmentSummary(List<Map<String, dynamic>>? rows) {
  if (rows == null || rows.isEmpty) {
    return null;
  }
  final names = <String>[
    for (final row in rows)
      if (_stringValue(row['original_file_name']) case final String name) name,
  ];
  if (names.isEmpty) {
    return '${rows.length} 个附件';
  }
  return '${rows.length} 个：${names.join('；')}';
}

String? _nextStepForEvent(
  Map<String, dynamic>? event,
  Map<String, Map<String, dynamic>> actionsById,
) {
  if (event == null) {
    return null;
  }
  final metadata = _metadata(event['metadata']);
  final actionId =
      _stringValue(metadata['next_action_id']) ??
      _stringValue(metadata['action_id']);
  if (actionId == null) {
    return null;
  }
  final action = actionsById[actionId];
  if (action == null) {
    return null;
  }
  final title = _stringValue(action['title']);
  if (title == null) {
    return null;
  }
  final dueAt = _dateTimeValue(action['due_at']);
  return dueAt == null ? title : '$title（${_shortDate(dueAt)}）';
}

_LifecyclePresentation? _lifecyclePresentation(
  String eventType,
  dynamic rawMetadata,
) {
  final metadata = _metadata(rawMetadata);
  return switch (eventType) {
    'case_stabilized' => const _LifecyclePresentation(
      '确认暂时稳定',
      '老师确认当前表现已经达到预期。',
    ),
    'case_closed' => _LifecyclePresentation(
      '结束跟进',
      _closureText(metadata),
    ),
    'case_reopened' => const _LifecyclePresentation(
      '重新跟进',
      '出现新的相关表现，重新开始跟进。',
    ),
    'action_completed' => const _LifecyclePresentation(
      '完成一步',
      '完成了当前安排，并继续处理下一步。',
    ),
    'action_rescheduled' => const _LifecyclePresentation(
      '调整提醒',
      '调整了下一次提醒时间。',
    ),
    _ => null,
  };
}

String _closureText(Map<String, dynamic> metadata) {
  final note = _stringValue(metadata['closure_note']);
  if (note != null) {
    return note;
  }
  return switch (_stringValue(metadata['closure_reason'])) {
    'resolved' => '当前问题已经达到预期，本轮跟进结束。',
    'pause_tracking' => '目前暂不继续跟进，历史记录完整保留。',
    'not_issue' => '确认无需继续作为问题跟进。',
    _ => '本轮跟进结束，历史记录完整保留。',
  };
}

String _caseStatusLabel(dynamic value) {
  return switch (_stringValue(value)) {
    'new' => '待整理',
    'confirmed' => '跟进中',
    'intervening' => '跟进中',
    'pending_verification' => '待验证',
    'stable' => '暂时稳定',
    'closed' => '已结束',
    _ => '未知状态',
  };
}

String _assessmentResultLabel(dynamic value) {
  return switch (_stringValue(value)) {
    'passed' => '达到预期',
    'partial' => '部分改善',
    'not_passed' => '暂未达到预期',
    _ => '待判断',
  };
}

String _shortDate(DateTime value) => '${value.month}月${value.day}日';

String _fileDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _requiredString(dynamic value, String field) {
  final result = _stringValue(value);
  if (result == null) {
    throw FormatException('Missing $field in export response.');
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

DateTime? _dateTimeValue(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString())?.toLocal();
}

DateTime _requiredDateTime(dynamic value, String field) {
  final result = _dateTimeValue(value);
  if (result == null) {
    throw FormatException('Missing $field in export response.');
  }
  return result;
}
