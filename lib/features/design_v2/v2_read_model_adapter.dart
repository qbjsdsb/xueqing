import '../../cloud/learning_repository.dart';
import 'v2_fixture.dart';
import 'v2_workspace_data.dart';

/// Read-only bridge from the existing production workspace model into the V2
/// presentation model. It deliberately contains no Supabase calls and no write
/// commands: all authorization and data loading stay behind LearningRepository.
class V2ReadModelSnapshot {
  const V2ReadModelSnapshot({
    required this.viewerName,
    required this.organizationName,
    required this.students,
    required this.focusItems,
    required this.closedItems,
    required this.timeline,
    required this.caseBindings,
    required this.businessDate,
  });

  final String viewerName;
  final String organizationName;
  final List<V2Student> students;
  final List<V2FocusItem> focusItems;
  final List<V2FocusItem> closedItems;
  final List<V2TimelineEntry> timeline;
  final List<V2CaseBinding> caseBindings;
  final DateTime? businessDate;

  V2WorkspaceData get workspaceData => V2WorkspaceData(
    students: students,
    focusItems: focusItems,
    closedItems: closedItems,
    timeline: timeline,
    businessDate: businessDate,
  );

  List<V2FocusItem> focusItemsForStudent(String studentId) => focusItems
      .where((item) => item.studentId == studentId)
      .toList(growable: false);

  List<V2FocusItem> closedItemsForStudent(String studentId) => closedItems
      .where((item) => item.studentId == studentId)
      .toList(growable: false);

  List<V2TimelineEntry> timelineForCase(String caseId) =>
      timeline.where((entry) => entry.caseId == caseId).toList(growable: false);

  V2CaseBinding? bindingForCase(String caseId) {
    for (final binding in caseBindings) {
      if (binding.caseId == caseId) {
        return binding;
      }
    }
    return null;
  }
}

/// Keeps the exact subject-profile and optimistic-lock identity that the V2 UI
/// must not lose when it groups multiple subject profiles into one visible
/// student.
class V2CaseBinding {
  const V2CaseBinding({
    required this.studentId,
    required this.profileId,
    required this.profileVersion,
    required this.caseId,
    required this.caseVersion,
    required this.subject,
  });

  final String studentId;
  final String profileId;
  final int profileVersion;
  final String caseId;
  final int caseVersion;
  final String subject;
}

class V2ReadModelAdapter {
  const V2ReadModelAdapter._();

  static V2ReadModelSnapshot fromWorkspace(TeacherWorkspace workspace) {
    final profilesByStudent = <String, List<WorkspaceStudent>>{};
    for (final profile in workspace.students) {
      profilesByStudent
          .putIfAbsent(profile.id, () => <WorkspaceStudent>[])
          .add(profile);
    }

    final students = <V2Student>[];
    for (final profiles in profilesByStudent.values) {
      final first = profiles.first;
      final subjects = <String>[];
      final seenSubjects = <String>{};
      var openCaseCount = 0;
      var hasLearningHistory = false;
      DateTime? lastActivityAt;

      for (final profile in profiles) {
        final subject = profile.subject.trim();
        if (subject.isNotEmpty && seenSubjects.add(subject)) {
          subjects.add(subject);
        }
        if (profile.cases.isNotEmpty || profile.recentFacts.isNotEmpty) {
          hasLearningHistory = true;
        }
        for (final fact in profile.recentFacts) {
          if (lastActivityAt == null ||
              fact.occurredAt.isAfter(lastActivityAt)) {
            lastActivityAt = fact.occurredAt;
          }
        }
        for (final learningCase in profile.cases) {
          if (lastActivityAt == null ||
              learningCase.firstObservedAt.isAfter(lastActivityAt)) {
            lastActivityAt = learningCase.firstObservedAt;
          }
          for (final event in learningCase.timeline) {
            if (lastActivityAt == null ||
                event.occurredAt.isAfter(lastActivityAt)) {
              lastActivityAt = event.occurredAt;
            }
          }
        }
        openCaseCount += profile.cases.where(_isActiveCase).length;
      }

      students.add(
        V2Student(
          id: first.id,
          name: first.name,
          grade: first.grade,
          subjects: List<String>.unmodifiable(subjects),
          openCaseCount: openCaseCount,
          updatedLabel: hasLearningHistory ? '已有更新' : '暂无记录',
          teacherSummary: '',
          lastActivityAt: lastActivityAt,
        ),
      );
    }

    final focusItems = <V2FocusItem>[];
    final closedItems = <V2FocusItem>[];
    final timeline = <V2TimelineEntry>[];
    final bindings = <V2CaseBinding>[];

    for (final profile in workspace.students) {
      for (final learningCase in profile.cases) {
        final closed = learningCase.status == LearningCaseStatus.closed;
        final primaryAction = closed ? null : learningCase.primaryAction;
        final item = V2FocusItem(
          id: learningCase.id,
          studentId: profile.id,
          title: learningCase.title,
          summary: _caseSummary(learningCase),
          nextStep: closed ? '跟进已结束' : _nextStep(primaryAction),
          dueLabel: closed ? '已结束' : _dueLabel(primaryAction),
          subject: profile.subject,
          actionTiming: closed ? null : _actionTiming(primaryAction),
          dueOn: closed ? null : _actionDueOn(primaryAction),
          pendingVerification:
              !closed &&
              learningCase.status == LearningCaseStatus.pendingVerification,
          closed: closed,
        );
        if (closed) {
          closedItems.add(item);
        } else {
          focusItems.add(item);
        }
        bindings.add(
          V2CaseBinding(
            studentId: profile.id,
            profileId: profile.profileId,
            profileVersion: profile.profileVersion,
            caseId: learningCase.id,
            caseVersion: learningCase.version,
            subject: profile.subject,
          ),
        );

        final caseTimeline = learningCase.timeline.toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        for (final event in caseTimeline) {
          timeline.add(
            V2TimelineEntry(
              caseId: learningCase.id,
              date: _dateLabel(event.occurredAt),
              kind: event.typeLabel,
              body: event.text,
              // WorkspaceTimelineEvent currently has no historical actor name.
              // An empty value is intentional: never attribute old records to
              // the current viewer just to fill the UI.
              teacher: '',
              time: _timeLabel(event.occurredAt),
              evidenceId: event.evidenceId,
            ),
          );
        }
      }
    }

    return V2ReadModelSnapshot(
      viewerName: workspace.viewerName,
      organizationName: workspace.organizationName,
      students: List<V2Student>.unmodifiable(students),
      focusItems: List<V2FocusItem>.unmodifiable(focusItems),
      closedItems: List<V2FocusItem>.unmodifiable(closedItems),
      timeline: List<V2TimelineEntry>.unmodifiable(timeline),
      caseBindings: List<V2CaseBinding>.unmodifiable(bindings),
      businessDate: workspace.businessDate,
    );
  }

  static bool _isActiveCase(WorkspaceCase learningCase) =>
      learningCase.status != LearningCaseStatus.closed;

  static V2ActionTiming? _actionTiming(WorkspaceAction? action) =>
      switch (action?.bucket) {
        WorkspaceActionBucket.overdue => V2ActionTiming.overdue,
        WorkspaceActionBucket.today => V2ActionTiming.today,
        WorkspaceActionBucket.future => V2ActionTiming.future,
        WorkspaceActionBucket.undated => V2ActionTiming.undated,
        null => null,
      };

  static String _caseSummary(WorkspaceCase learningCase) {
    final description = learningCase.description?.trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }
    if (learningCase.evidence.isEmpty) {
      return '暂无补充说明';
    }
    final evidence = learningCase.evidence.toList(growable: false)
      ..sort((a, b) => b.observedAt.compareTo(a.observedAt));
    final summary = evidence.first.summary.trim();
    return summary.isEmpty ? '暂无补充说明' : summary;
  }

  static String _nextStep(WorkspaceAction? action) {
    final title = action?.title.trim();
    return title == null || title.isEmpty ? '待安排下一步' : title;
  }

  static DateTime? _actionDueOn(WorkspaceAction? action) =>
      action?.businessDueDate ?? action?.dueAt;

  static String _dueLabel(WorkspaceAction? action) {
    final date = _actionDueOn(action);
    return date == null ? '待安排' : _dateLabel(date);
  }

  static String _dateLabel(DateTime value) => '${value.month} 月 ${value.day} 日';

  static String _timeLabel(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
