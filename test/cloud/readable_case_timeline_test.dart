import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/learning_repository.dart';

void main() {
  test('folds one progressive assessment operation into one teacher record', () {
    final occurredAt = DateTime(2026, 9, 12, 20, 5);
    final timeline = buildTeacherReadableTimeline(
      caseTitle: '概括题漏点',
      firstObservedAt: DateTime(2026, 9, 8, 19, 40),
      evidence: <WorkspaceEvidence>[
        WorkspaceEvidence(
          id: 'evidence-1',
          sourceType: 'observation',
          title: '概括题漏点',
          observedAt: DateTime(2026, 9, 8, 19, 40),
          summary: '经常只答一个方面。',
          status: 'finalized',
        ),
      ],
      interventions: const <WorkspaceIntervention>[],
      assessments: <WorkspaceAssessment>[
        WorkspaceAssessment(
          id: 'assessment-1',
          result: 'passed',
          evidenceSummary: '连续两次独立完成。',
          notes: null,
          assessedAt: occurredAt,
        ),
      ],
      actions: const <WorkspaceAction>[],
      eventRows: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'event-created',
          'event_type': 'case_created',
          'occurred_at': DateTime(2026, 9, 8, 19, 40).toIso8601String(),
          'operation_id': 'operation-created',
          'metadata': <String, dynamic>{'evidence_id': 'evidence-1'},
        },
        <String, dynamic>{
          'id': 'event-assessment',
          'event_type': 'assessment_recorded',
          'occurred_at': occurredAt.toIso8601String(),
          'operation_id': 'operation-progress',
          'metadata': <String, dynamic>{
            'record_id': 'assessment-1',
            'next_step': 'close',
          },
        },
        <String, dynamic>{
          'id': 'event-stable',
          'event_type': 'case_stabilized',
          'occurred_at': occurredAt.toIso8601String(),
          'operation_id': 'operation-progress',
          'metadata': const <String, dynamic>{},
        },
        <String, dynamic>{
          'id': 'event-closed',
          'event_type': 'case_closed',
          'occurred_at': occurredAt.toIso8601String(),
          'operation_id': 'operation-progress',
          'metadata': <String, dynamic>{'closure_reason': 'resolved'},
        },
      ],
    );

    expect(timeline, hasLength(2));
    expect(timeline.first.typeLabel, '检查结果 · 结束跟进');
    expect(timeline.first.text, contains('连续两次独立完成'));
    expect(timeline.last.typeLabel, '发现问题');
    expect(
      timeline.where((item) => item.typeLabel == '结束跟进'),
      isEmpty,
    );
  });

  test('keeps an independently recorded reopen event visible', () {
    final timeline = buildTeacherReadableTimeline(
      caseTitle: '作业漏步骤',
      firstObservedAt: DateTime(2026, 9, 1),
      evidence: const <WorkspaceEvidence>[],
      interventions: const <WorkspaceIntervention>[],
      assessments: const <WorkspaceAssessment>[],
      actions: const <WorkspaceAction>[],
      eventRows: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'event-reopen',
          'event_type': 'case_reopened',
          'occurred_at': DateTime(2026, 9, 6).toIso8601String(),
          'operation_id': 'operation-reopen',
          'metadata': const <String, dynamic>{},
        },
      ],
    );

    expect(timeline, hasLength(1));
    expect(timeline.single.typeLabel, '重新跟进');
  });
}
