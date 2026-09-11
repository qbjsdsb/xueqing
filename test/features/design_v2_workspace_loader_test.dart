import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_loader.dart';

void main() {
  Widget app(V2WorkspaceLoad loadWorkspace) => MaterialApp(
    theme: V2Theme.light(),
    home: V2WorkspaceLoader(loadWorkspace: loadWorkspace),
  );

  testWidgets('shows a quiet loading state while workspace is pending', (
    tester,
  ) async {
    final completer = Completer<TeacherWorkspace>();

    await tester.pumpWidget(app(() => completer.future));
    await tester.pump();

    expect(find.text('正在同步学情'), findsOneWidget);
    expect(find.text('正在读取学生与学情记录。'), findsOneWidget);

    completer.complete(_workspace());
    await tester.pumpAndSettle();
    expect(find.text('真实学生'), findsWidgets);
  });

  testWidgets('maps an authorized workspace into the V2 UI', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(() async => _workspace()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('学生'));
    await tester.pumpAndSettle();

    expect(find.text('真实学生'), findsWidgets);
    expect(find.text('阅读概括仍会漏结果'), findsOneWidget);
    expect(find.textContaining('下一次课再验证'), findsOneWidget);
    expect(find.text('林同学'), findsNothing);
  });

  testWidgets('does not expose student UI without teaching access', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(() async => _workspace(hasTeachingAccess: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂时没有任课学情'), findsOneWidget);
    expect(find.textContaining('当前账号暂时没有可查看的任课学生'), findsOneWidget);
    expect(find.text('真实学生'), findsNothing);
  });

  testWidgets('error state retries the same read boundary', (tester) async {
    var attempts = 0;

    Future<TeacherWorkspace> loadWorkspace() async {
      attempts++;
      if (attempts == 1) {
        throw StateError('offline');
      }
      return _workspace();
    }

    await tester.pumpWidget(app(loadWorkspace));
    await tester.pumpAndSettle();

    expect(find.text('学情暂时无法读取'), findsOneWidget);
    expect(find.byKey(const Key('v2-workspace-retry')), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.byKey(const Key('v2-workspace-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('真实学生'), findsWidgets);
    expect(find.text('学情暂时无法读取'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('authorized workspace with zero students uses V2 empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(() async => _workspace(students: const <WorkspaceStudent>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂时还没有可查看的学生'), findsOneWidget);
    expect(find.text('暂时没有任课学情'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual refresh keeps current data on failure and can recover', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var attempts = 0;

    Future<TeacherWorkspace> loadWorkspace() async {
      attempts++;
      if (attempts == 2) throw StateError('offline');
      if (attempts >= 3) {
        return _workspace(students: const <WorkspaceStudent>[]);
      }
      return _workspace();
    }

    await tester.pumpWidget(app(loadWorkspace));
    await tester.pumpAndSettle();
    expect(find.text('真实学生'), findsWidgets);

    await tester.tap(find.byKey(const Key('v2-workspace-refresh')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('真实学生'), findsWidgets);
    expect(find.text('学情暂时无法读取'), findsNothing);
    expect(find.textContaining('刷新失败，请检查网络后重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(attempts, 3);
    expect(find.text('暂时还没有可查看的学生'), findsOneWidget);
    expect(find.text('真实学生'), findsNothing);
  });
}

TeacherWorkspace _workspace({
  bool hasTeachingAccess = true,
  List<WorkspaceStudent>? students,
}) {
  return TeacherWorkspace(
    viewerName: '乔老师',
    organizationName: '测试机构',
    organizationTimeZone: 'Asia/Shanghai',
    hasTeachingAccess: hasTeachingAccess,
    loadedAt: DateTime(2026, 9, 9, 21),
    businessDate: DateTime(2026, 9, 9),
    students: students ?? <WorkspaceStudent>[_student()],
  );
}

WorkspaceStudent _student() {
  return WorkspaceStudent(
    id: 'student-real',
    profileId: 'profile-real-cn',
    profileVersion: 4,
    name: '真实学生',
    grade: '初三',
    subject: '语文',
    context: '真实只读装配测试',
    positioning: null,
    strengths: null,
    cadenceNote: null,
    cases: <WorkspaceCase>[
      WorkspaceCase(
        id: 'case-real-reading',
        profileId: 'profile-real-cn',
        title: '阅读概括仍会漏结果',
        type: LearningCaseType.knowledge,
        status: LearningCaseStatus.pendingVerification,
        priority: 'normal',
        description: '已经会定位关键词，但结果要点仍可能遗漏。',
        firstObservedAt: DateTime(2026, 9, 4),
        version: 3,
        evidence: const <WorkspaceEvidence>[],
        interventions: const <WorkspaceIntervention>[],
        assessments: const <WorkspaceAssessment>[],
        actions: <WorkspaceAction>[
          WorkspaceAction(
            id: 'action-real-verify',
            caseId: 'case-real-reading',
            title: '下一次课再验证',
            actionType: 'verify',
            status: WorkspaceActionStatus.pending,
            isPrimary: true,
            bucket: WorkspaceActionBucket.future,
            version: 1,
            dueAt: DateTime(2026, 9, 12, 18),
            businessDueDate: DateTime(2026, 9, 12),
          ),
        ],
        timeline: <WorkspaceTimelineEvent>[
          WorkspaceTimelineEvent(
            id: 'event-real-check',
            occurredAt: DateTime(2026, 9, 9, 18, 31),
            typeLabel: '检查结果',
            text: '本次能够独立完成大部分概括，仍遗漏结果。',
          ),
        ],
      ),
    ],
    recentFacts: const <WorkspaceTimelineEvent>[],
  );
}
