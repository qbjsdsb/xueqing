import 'package:flutter/widgets.dart';

import 'v2_fixture.dart';

/// Presentation-only data contract for the V2 workspace.
///
/// It knows nothing about Supabase or repositories. The fixture and the
/// production read-model adapter can both supply the same shape.
class V2WorkspaceData {
  const V2WorkspaceData({
    required this.students,
    required this.focusItems,
    required this.timeline,
  });

  final List<V2Student> students;
  final List<V2FocusItem> focusItems;
  final List<V2TimelineEntry> timeline;

  List<V2FocusItem> focusItemsForStudent(V2Student student) => focusItems
      .where((item) => item.studentId == student.id)
      .toList(growable: false);

  V2Student? studentForFocusItemOrNull(V2FocusItem item) {
    for (final student in students) {
      if (student.id == item.studentId) {
        return student;
      }
    }
    return null;
  }

  V2Student studentForFocusItem(V2FocusItem item) {
    final student = studentForFocusItemOrNull(item);
    if (student == null) {
      throw StateError('Focus item ${item.id} has no matching student.');
    }
    return student;
  }

  List<V2TimelineEntry> timelineForCase(V2FocusItem item) => timeline
      .where((entry) => entry.caseId == item.id)
      .toList(growable: false);

  List<V2TimelineEntry> timelineForStudent(V2Student student) {
    final caseIds = focusItemsForStudent(student)
        .map((item) => item.id)
        .toSet();
    return timeline
        .where((entry) => caseIds.contains(entry.caseId))
        .toList(growable: false);
  }
}

class V2WorkspaceDataScope extends InheritedWidget {
  const V2WorkspaceDataScope({
    required this.data,
    required super.child,
    super.key,
  });

  final V2WorkspaceData data;

  static V2WorkspaceData of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<V2WorkspaceDataScope>();
    assert(scope != null, 'V2WorkspaceDataScope is missing above this widget.');
    return scope!.data;
  }

  @override
  bool updateShouldNotify(V2WorkspaceDataScope oldWidget) =>
      !identical(data, oldWidget.data);
}

const v2FixtureWorkspaceData = V2WorkspaceData(
  students: v2Students,
  focusItems: v2FocusItems,
  timeline: v2Timeline,
);
