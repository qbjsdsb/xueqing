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
      expect(grouped.openCaseCount, 3);
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
        'case-cn-stable',
        'case-math',
      });
      final stable = snapshot.focusItems.firstWhere(
        (item) => item.id == 'case-cn-stable',
      );
      expect(stable.nextStep, '两周后复查');
      expect(stable.actionTiming?.name, 'future');
      expect(stable.effectiveStatus.name, 'stable');

      final chinese = snapshot.focusItems.firstWhere(
        (item) => item.id == 'case-cn',
      );
      expect(chinese.studentId, 'student-lin');
      expect(chinese.subject, '语文');
      expect(chinese.nextStep, '周四再做一题');
      expect(chinese.dueLabel, '9 月 12 日');
      expect(chinese.effectiveStatus.name, 'intervening');

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

      expect(snapshot.closedItems.map((item) => item.id), ['case-cn-closed']);
      final closedBinding = snapshot.bindingForCase('case-cn-closed');
      expect(closedBinding, isNotNull);
      expect(closedBinding!.profileId, 'profile-cn');
      expect(closedBinding.caseVersion, 9);
      expect(snapshot.closedItems.single.closed, isTrue);
      expect(snapshot.closedItems.single.effectiveStatus.name, 'closed');
      expect(snapshot.closedItems.single.nextStep, '跟进已结束');
    });

    test('falls back to latest evidence without merging subject histories', () {
      final snapshot = V2ReadModelAdapter.fromWorkspace(_workspace());
      final math = snapshot.focusItems.firstWhere(
        (item) => item.id == 'case-math',
      );

      expect(math.subject, '数学');
      expect(math.summary, '最近一次仍不会从题意建立关系。');
      expect(math.nextStep, '安排一次复检');
      expect(math.dueLabel, '待安排');
      expect(math.pendingVerification, isTrue);
      expect(math.effectiveStatus.name, 'pendingVerification');
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
        expect(timeline.last.kind, '建立跟进');
        expect(timeline.last.body, '第一次发现概括遗漏。');
        expect(timeline.every((entry) => entry.teacher.isEmpty), isTrue);
        expect(snapshot.viewerName, '乔老师');
        expect(snapshot.organizationName, '测试机构');
      },
    );

    test(
      'closed history stays out of active work but remains longitudinal',
      () {
        final snapshot = V2ReadModelAdapter.fromWorkspace(_workspace());
        final student = snapshot.students.firstWhere(
          (item) => item.id == 'student-lin',
        );

        expect(student.openCaseCount, 3);
        expect(
          snapshot.focusItems.any((item) => item.id == 'case-cn-closed'),
          isFalse,
        );
        expect(snapshot.closedItemsForStudent('student-lin'), hasLength(1));
        expect(
          snapshot.timelineForCase('case-cn-closed').single.body,
          '结束前已经稳定完成。',
        );
        final allCaseIds = snapshot.workspaceData
            .timelineForStudent(student)
            .map((entry) => entry.caseId)
            .toSet();
        expect(allCaseIds, contains('case-cn-closed'));
      },
    );

    test(
      'removes duplicated assessment wording but preserves real follow-up text',
      () {
        final workspace = TeacherWorkspace(
          viewerName: '乔老师',
          organizationName: '测试机构',
          organizationTimeZone: 'Asia/Shanghai',
          hasTeachingAccess: true,
          loadedAt: DateTime(2026, 9, 11, 14),
          students: [
            WorkspaceStudent(
              id: 'student-1',
              profileId: 'profile-1',
              profileVersion: 1,
              name: '吴同学',
              grade: '初三',
              subject: '历史',
              context: '',
              positioning: null,
              strengths: null,
              cadenceNote: null,
              cases: [
                _case(
                  id: 'case-assessment-copy',
                  profileId: 'profile-1',
                  title: '拜占庭帝国',
                  status: LearningCaseStatus.closed,
                  version: 2,
                  timeline: [
                    WorkspaceTimelineEvent(
                      id: 'assessment-only',
                      occurredAt: DateTime(2026, 9, 9, 12, 30),
                      typeLabel: '检查结果 · 通过',
                      text: '检查结果：通过',
                    ),
                    WorkspaceTimelineEvent(
                      id: 'assessment-closed',
                      occurredAt: DateTime(2026, 9, 9, 13, 3),
                      typeLabel: '检查结果 · 通过',
                      text: '检查结果：通过\n结束跟进。',
                    ),
                  ],
                ),
              ],
              recentFacts: const [],
            ),
          ],
        );

        final timeline = V2ReadModelAdapter.fromWorkspace(workspace)
            .timelineForCase('case-assessment-copy');
        expect(timeline, hasLength(2));
        expect(timeline.first.kind, '检查结果 · 通过');
        expect(timeline.first.body, '结束跟进。');
        expect(timeline.last.body, isEmpty);
      },
    );

    test('presents pending review cases as concise teacher work', () {
      final workspace = TeacherWorkspace(
        viewerName: '乔老师',
        organizationName: '测试机构',
        organizationTimeZone: 'Asia/Shanghai',
        hasTeachingAccess: true,
        loadedAt: DateTime(2026, 9, 11, 19),
        businessDate: DateTime(2026, 9, 11),
        students: [
          WorkspaceStudent(
            id: 'student-li',
            profileId: 'profile-li-cn',
            profileVersion: 1,
            name: '李兆城',
            grade: '初三',
            subject: '语文',
            context: '',
            positioning: null,
            strengths: null,
            cadenceNote: null,
            cases: [
              _case(
                id: 'case-recitation-review',
                profileId: 'profile-li-cn',
                title: '咏雪，陈太丘背诵完成，有待复检',
                status: LearningCaseStatus.pendingVerification,
                version: 1,
                description: '咏雪，陈太丘背诵完成，有待复检',
                timeline: [
                  WorkspaceTimelineEvent(
                    id: 'event-created',
                    occurredAt: DateTime(2026, 9, 11, 18, 53),
                    typeLabel: '发现问题',
                    text: '咏雪，陈太丘背诵完成，有待复检\n学生表现：咏雪，陈太丘背诵完成，有待复检',
                  ),
                ],
              ),
            ],
            recentFacts: const [],
          ),
        ],
      );

      final snapshot = V2ReadModelAdapter.fromWorkspace(workspace);
      final item = snapshot.focusItems.single;
      final entry = snapshot.timeline.single;

      expect(item.title, '咏雪，陈太丘背诵完成');
      expect(item.summary, '已完成当前阶段，尚需再次检查确认是否稳定掌握。');
      expect(item.nextStep, '安排一次复检');
      expect(item.dueLabel, '待安排');
      expect(item.pendingVerification, isTrue);
      expect(entry.kind, '建立跟进');
      expect(entry.body, '咏雪，陈太丘背诵完成，有待复检');
    });

    test(
      'timeline deduplication never collapses distinct punctuation facts',
      () {
        final workspace = TeacherWorkspace(
          viewerName: '乔老师',
          organizationName: '测试机构',
          organizationTimeZone: 'Asia/Shanghai',
          hasTeachingAccess: true,
          loadedAt: DateTime(2026, 9, 11, 20),
          students: [
            WorkspaceStudent(
              id: 'student-punctuation',
              profileId: 'profile-punctuation',
              profileVersion: 1,
              name: '测试学生',
              grade: '初三',
              subject: '数学',
              context: '',
              positioning: null,
              strengths: null,
              cadenceNote: null,
              cases: [
                _case(
                  id: 'case-punctuation',
                  profileId: 'profile-punctuation',
                  title: '错题记录',
                  status: LearningCaseStatus.intervening,
                  version: 1,
                  timeline: [
                    WorkspaceTimelineEvent(
                      id: 'event-punctuation',
                      occurredAt: DateTime(2026, 9, 11, 19),
                      typeLabel: '新表现',
                      text: '第 3-1 题错误\n第 31 题错误',
                    ),
                  ],
                ),
              ],
              recentFacts: const [],
            ),
          ],
        );

        final entry = V2ReadModelAdapter.fromWorkspace(workspace)
            .timeline
            .single;
        expect(entry.body, '第 3-1 题错误\n第 31 题错误');
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
            id: 'case-cn-closed',
            profileId: 'profile-cn',
            title: '曾经的概括问题',
            status: LearningCaseStatus.closed,
            version: 9,
            description: '这条问题已经结束跟进。',
            timeline: [
              WorkspaceTimelineEvent(
                id: 'event-closed',
                occurredAt: DateTime(2026, 8, 28, 17, 20),
                typeLabel: '结束跟进',
                text: '结束前已经稳定完成。',
              ),
            ],
          ),
          _case(
            id: 'case-cn-stable',
            profileId: 'profile-cn',
            title: '已暂时稳定的问题',
            status: LearningCaseStatus.stable,
            version: 4,
            actions: [
              WorkspaceAction(
                id: 'action-stable',
                caseId: 'case-cn-stable',
                title: '两周后复查',
                actionType: 'review',
                status: WorkspaceActionStatus.pending,
                isPrimary: true,
                bucket: WorkspaceActionBucket.future,
                version: 1,
                dueAt: DateTime(2026, 9, 23, 10),
                businessDueDate: DateTime(2026, 9, 23),
              ),
            ],
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
