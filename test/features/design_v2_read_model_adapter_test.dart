import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/features/design_v2/v2_read_model_adapter.dart';

void main() {
  group('V2ReadModelAdapter', () {
    test('groups subject profiles by stable student id, never by name', () {
      final snapshot = V2ReadModelAdapter.fromWorkspace(_workspace());

      expect(snapshot.students, hasLength(2));

      final grouped = snapshot.students.firstWhere(
        (student) => student.id == 'student-lin',
      );
      expect(grouped.name, '林同学');
      expect(grouped.subjects, ['语文', '数学']);
      expect(grouped.openCaseCount, 2);
      expect(grouped.updatedLabel, '已有更新');

      final sameNameOtherPerson = snapshot.students.firstWhere(
        (student) => student.id == 'student-other',
      );
      expect(sameNameOtherPerson.name, '林同学');
      expect(sameNameOtherPerson.subjects, ['英语']);
    });

    test('preserves exact profile and case identity across subjects', () {
      final snapshot = V2ReadModelAdapter.fromWorkspace(_workspace());

      expect(snapshot.focusItems.map((item) => item.id).toSet(), {
        'case-cn',
        'case-math',
      });
      expect(
        snapshot.focusItems.any((item) => item.id == 'case-cn-stable'),
        isFalse,
      );

      final chinese = snapshot.focusItems.firstWhere(
        (item) => item.id == 'case-cn',
      );
      expect(chinese.studentId, 'student-lin');
      expect(chinese.subject, '语文');
      expect(chinese.nextStep, '周四再做一题');
      expect(chinese.dueLabel, '9 月 12 日');

      final chineseBinding = snapshot.bindingForCase('case-cn');
      expect(chineseBinding, isNotNull);
      expect(chineseBinding!.studentId, 'student-lin');
      expect(chineseBinding.profileId, 'profile-cn');
      expect(chineseBinding.profileVersion, 3);
      expect(chineseBinding.caseVersion, 7);
      expect(chineseBinding.subject, '语文');

      final mathBinding = snapshot.bindingForCase('case-math');
      expect(mathBinding, isNotNull);
      expect(mathBinding!.profileId, 'profile-math');
      expect(mathBinding.profileVersion, 5);
      expect(mathBinding.caseVersion, 2);
    });

    test('falls back to latest evidence without merging subject histories', () {
      final snapshot = V2ReadModelAdapter.fromWorkspace(_workspace());
      final math = snapshot.focusItems.firstWhere(
        (item) => item.id == 'case-math',
      );

      expect(math.subject, '数学');
      expect(math.summary, '最近一次仍不会从题意建立关系。');
      expect(math.nextStep, '待安排下一步');
      expect(math.dueLabel, '待安排');
      expect(math.pendingVerification, isTrue);
      expect(
        snapshot
            .focusItemsForStudent('student-lin')
            .map((item) => item.subject),
        containsAll(<String>['语文', '数学']),
      );
    });

    test(
      'never invents a historical teacher when workspace lacks provenance',
      () {
        final snapshot = V2ReadModelAdapter.fromWorkspace(_workspace());
        final timeline = snapshot.timelineForCase('case-cn');

        expect(timeline, hasLength(2));
        expect(timeline.first.body, '第二次检查仍漏结果。');
        expect(timeline.first.evidenceId, 'evidence-timeline');
        expect(timeline.last.body, '第一次发现概括遗漏。');
        expect(timeline.every((entry) => entry.teacher.isEmpty), isTrue);
        expect(snapshot.viewerName, '乔老师');
        expect(snapshot.organizationName, '测试机构');
      },
    );
  });
}

TeacherWorkspace _workspace() {
  return TeacherWorkspace(
    viewerName: '乔老师',
    organizationName: '测试机构',
    organizationTimeZone: 'Asia/Shanghai',
    hasTeachingAccess: true,
    loadedAt: DateTime(2026, 9, 9, 20),
    businessDate: DateTime(2026, 9, 9),
    students: [
      WorkspaceStudent(
        id: 'student-lin',
        profileId: 'profile-cn',
        profileVersion: 3,
        name: '林同学',
        grade: '初三',
        subject: '语文',
        context: '语文测试档案',
        positioning: null,
        strengths: null,
        cadenceNote: null,
        cases: [
          _case(
            id: 'case-cn',
            profileId: 'profile-cn',
            title: '阅读概括不完整',
            status: LearningCaseStatus.intervening,
            version: 7,
            description: '能够定位关键词，但概括仍容易遗漏结果。',
            actions: [
              WorkspaceAction(
                id: 'action-cn',
                caseId: 'case-cn',
                title: '周四再做一题',
                actionType: 'verify',
                status: WorkspaceActionStatus.pending,
                isPrimary: true,
                bucket: WorkspaceActionBucket.future,
                version: 2,
                dueAt: DateTime(2026, 9, 12, 10),
                businessDueDate: DateTime(2026, 9, 12),
              ),
            ],
            timeline: [
              WorkspaceTimelineEvent(
                id: 'event-old',
                occurredAt: DateTime(2026, 9, 3, 15, 40),
                typeLabel: '发现问题',
                text: '第一次发现概括遗漏。',
              ),
              WorkspaceTimelineEvent(
                id: 'event-new',
                occurredAt: DateTime(2026, 9, 9, 18, 31),
                typeLabel: '新表现',
                text: '第二次检查仍漏结果。',
                evidenceId: 'evidence-timeline',
              ),
            ],
          ),
          _case(
            id: 'case-cn-stable',
            profileId: 'profile-cn',
            title: '已暂时稳定的问题',
            status: LearningCaseStatus.stable,
            version: 4,
          ),
        ],
        recentFacts: const [],
      ),
      WorkspaceStudent(
        id: 'student-lin',
        profileId: 'profile-math',
        profileVersion: 5,
        name: '林同学',
        grade: '初三',
        subject: '数学',
        context: '数学测试档案',
        positioning: null,
        strengths: null,
        cadenceNote: null,
        cases: [
          _case(
            id: 'case-math',
            profileId: 'profile-math',
            title: '函数应用题思路不清',
            status: LearningCaseStatus.pendingVerification,
            version: 2,
            evidence: [
              WorkspaceEvidence(
                id: 'evidence-old',
                sourceType: 'lesson',
                title: '第一次观察',
                observedAt: DateTime(2026, 9, 5),
                summary: '会套公式。',
                status: 'active',
              ),
              WorkspaceEvidence(
                id: 'evidence-new',
                sourceType: 'lesson',
                title: '最近观察',
                observedAt: DateTime(2026, 9, 8),
                summary: '最近一次仍不会从题意建立关系。',
                status: 'active',
              ),
            ],
          ),
        ],
        recentFacts: const [],
      ),
      WorkspaceStudent(
        id: 'student-other',
        profileId: 'profile-other-en',
        profileVersion: 1,
        name: '林同学',
        grade: '初二',
        subject: '英语',
        context: '同名但不同学生',
        positioning: null,
        strengths: null,
        cadenceNote: null,
        cases: const [],
        recentFacts: const [],
      ),
    ],
  );
}

WorkspaceCase _case({
  required String id,
  required String profileId,
  required String title,
  required LearningCaseStatus status,
  required int version,
  String? description,
  List<WorkspaceEvidence> evidence = const [],
  List<WorkspaceAction> actions = const [],
  List<WorkspaceTimelineEvent> timeline = const [],
}) {
  return WorkspaceCase(
    id: id,
    profileId: profileId,
    title: title,
    type: LearningCaseType.knowledge,
    status: status,
    priority: 'normal',
    description: description,
    firstObservedAt: DateTime(2026, 9, 1),
    version: version,
    evidence: evidence,
    interventions: const [],
    assessments: const [],
    actions: actions,
    timeline: timeline,
  );
}
