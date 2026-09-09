import '../../cloud/learning_repository.dart';
import 'v2_fixture.dart';

/// Read-only bridge from the existing production workspace model into the V2
/// presentation model. It deliberately contains no Supabase calls and no write
/// commands: all authorization and data loading stay behind LearningRepository.
class V2ReadModelSnapshot {
  const V2ReadModelSnapshot({
    required this.viewerName,
    required this.organizationName,
    required this.students,
    required this.focusItems,
    required this.timeline,
    required this.caseBindings,
  });

  final String viewerName;
  final String organizationName;
  final List<V2Student> students;
  final List<V2FocusItem> focusItems;
  final List<V2TimelineEntry> timeline;
  final List<V2CaseBinding> caseBindings;

  List<V2FocusItem> focusItemsForStudent(String studentId) => focusItems
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

      for (final profile in profiles) {
        final subject = profile.subject.trim();
        if (subject.isNotEmpty && seenSubjects.add(subject)) {
          subjects.add(subject);
        }
        if (profile.cases.isNotEmpty || profile.recentFacts.isNotEmpty) {
          hasLearningHistory = true;
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
          teacherSummary: _workspaceSummary(
            viewerName: workspace.viewerName,
            subjects: subjects,
          ),
        ),
      );
    }

    final focusItems = <V2FocusItem>[];
    final timeline = <V2TimelineEntry>[];
    final bindings = <V2CaseBinding>[];

    for (final profile in workspace.students) {
      for (final learningCase in profile.cases) {
        if (!_isActiveCase(learningCase)) {
          continue;
        }

        final primaryAction = learningCase.primaryAction;
        focusItems.add(
          V2FocusItem(
            id: learningCase.id,
            studentId: profile.id,
            title: learningCase.title,
            summary: _caseSummary(learningCase),
            nextStep: _nextStep(primaryAction),
            dueLabel: _dueLabel(primaryAction),
            subject: profile.subject,
          ),
        );
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
      timeline: List<V2TimelineEntry>.unmodifiable(timeline),
      caseBindings: List<V2CaseBinding>.unmodifiable(bindings),
    );
  }

  static bool _isActiveCase(WorkspaceCase learningCase) =>
      learningCase.status != LearningCaseStatus.stable &&
      learningCase.status != LearningCaseStatus.closed;

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

  static String _dueLabel(WorkspaceAction? action) {
    if (action == null) {
      return '待安排';
    }
    final date = action.businessDueDate ?? action.dueAt;
    return date == null ? '待安排' : _dateLabel(date);
  }

  static String _workspaceSummary({
    required String viewerName,
    required List<String> subjects,
  }) {
    final viewer = viewerName.trim();
    final subjectText = subjects.join('、');
    if (viewer.isEmpty && subjectText.isEmpty) {
      return '当前工作区';
    }
    if (viewer.isEmpty) {
      return '当前工作区 · $subjectText';
    }
    if (subjectText.isEmpty) {
      return '当前工作区 · $viewer';
    }
    return '当前工作区 · $viewer · $subjectText';
  }

  static String _dateLabel(DateTime value) => '${value.month} 月 ${value.day} 日';

  static String _timeLabel(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
