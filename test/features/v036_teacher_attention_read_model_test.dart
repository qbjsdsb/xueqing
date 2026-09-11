import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/features/design_v2/v2_read_model_adapter.dart';

void main() {
  test(
    'active cases are ordered by teacher attention instead of database order',
    () {
      final snapshot = V2ReadModelAdapter.fromWorkspace(
        _workspace([
          _case('stable', LearningCaseStatus.stable),
          _case('normal', LearningCaseStatus.confirmed),
          _case(
            'future',
            LearningCaseStatus.intervening,
            action: _action(
              'future',
              WorkspaceActionBucket.future,
              DateTime(2026, 9, 20),
            ),
          ),
          _case('new', LearningCaseStatus.newCase),
          _case('review', LearningCaseStatus.pendingVerification),
          _case(
            'undated',
            LearningCaseStatus.intervening,
            action: _action('undated', WorkspaceActionBucket.undated, null),
          ),
          _case(
            'today',
            LearningCaseStatus.confirmed,
            action: _action(
              'today',
              WorkspaceActionBucket.today,
              DateTime(2026, 9, 11),
            ),
          ),
          _case(
            'overdue',
            LearningCaseStatus.confirmed,
            action: _action(
              'overdue',
              WorkspaceActionBucket.overdue,
              DateTime(2026, 9, 10),
            ),
          ),
        ]),
      );

      expect(snapshot.focusItems.map((item) => item.id).toList(), <String>[
        'overdue',
        'today',
        'undated',
        'review',
        'new',
        'future',
        'normal',
        'stable',
      ]);
    },
  );

  test('current judgment prefers latest assessment over old description', () {
    final learningCase = _case(
      'assessment',
      LearningCaseStatus.pendingVerification,
      description: '最初发现：经常漏看限制词。',
      evidence: <WorkspaceEvidence>[
        WorkspaceEvidence(
          id: 'evidence-1',
          sourceType: 'observation',
          title: '新表现',
          observedAt: DateTime(2026, 9, 8, 10),
          summary: '已经能主动圈出限制词。',
          status: 'finalized',
        ),
      ],
      assessments: <WorkspaceAssessment>[
        WorkspaceAssessment(
          id: 'assessment-old',
          result: 'partial',
          evidenceSummary: '第一次复检仍有遗漏。',
          notes: null,
          assessedAt: DateTime(2026, 9, 9, 10),
        ),
        WorkspaceAssessment(
          id: 'assessment-new',
          result: 'passed',
          evidenceSummary: '本次能独立圈出全部限制词。',
          notes: '仍需延迟复检确认是否稳定。',
          assessedAt: DateTime(2026, 9, 11, 10),
        ),
      ],
    );

    final item = V2ReadModelAdapter.fromWorkspace(_workspace([learningCase]))
        .focusItems
        .single;

    expect(item.summary, '本次能独立圈出全部限制词。\n仍需延迟复检确认是否稳定。');
  });
}

TeacherWorkspace _workspace(List<WorkspaceCase> cases) => TeacherWorkspace(
  viewerName: '测试老师',
  organizationName: '测试机构',
  organizationTimeZone: 'Asia/Shanghai',
  hasTeachingAccess: true,
  loadedAt: DateTime(2026, 9, 11, 20),
  businessDate: DateTime(2026, 9, 11),
  students: <WorkspaceStudent>[
    WorkspaceStudent(
      id: 'student-1',
      profileId: 'profile-1',
      profileVersion: 1,
      name: '测试学生',
      grade: '初三',
      subject: '语文',
      context: '',
      positioning: null,
      strengths: null,
      cadenceNote: null,
      cases: cases,
      recentFacts: const <WorkspaceTimelineEvent>[],
    ),
  ],
);

WorkspaceCase _case(
  String id,
  LearningCaseStatus status, {
  WorkspaceAction? action,
  String? description,
  List<WorkspaceEvidence> evidence = const <WorkspaceEvidence>[],
  List<WorkspaceAssessment> assessments = const <WorkspaceAssessment>[],
}) => WorkspaceCase(
  id: id,
  profileId: 'profile-1',
  title: '问题 $id',
  type: LearningCaseType.knowledge,
  status: status,
  priority: 'normal',
  description: description,
  firstObservedAt: DateTime(2026, 9, 1),
  version: 1,
  evidence: evidence,
  interventions: const <WorkspaceIntervention>[],
  assessments: assessments,
  actions: action == null
      ? const <WorkspaceAction>[]
      : <WorkspaceAction>[action],
  timeline: const <WorkspaceTimelineEvent>[],
);

WorkspaceAction _action(
  String id,
  WorkspaceActionBucket bucket,
  DateTime? dueOn,
) => WorkspaceAction(
  id: 'action-$id',
  caseId: id,
  title: '处理 $id',
  actionType: 'review',
  status: WorkspaceActionStatus.pending,
  isPrimary: true,
  bucket: bucket,
  version: 1,
  dueAt: dueOn,
  businessDueDate: dueOn,
);
