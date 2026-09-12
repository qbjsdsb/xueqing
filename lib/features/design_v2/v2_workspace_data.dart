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
    this.closedItems = const <V2FocusItem>[],
    this.businessDate,
    this.todayFocusItemIds,
  });

  final List<V2Student> students;
  final List<V2FocusItem> focusItems;
  final List<V2FocusItem> closedItems;
  final List<V2TimelineEntry> timeline;
  final DateTime? businessDate;

  /// When supplied, Today may only surface cases whose current primary Action
  /// is assigned to the current Personal membership. A null value preserves
  /// the fixture/legacy behavior where every actionable focus item is eligible.
  ///
  /// This is intentionally independent from [focusItems]: a teacher must still
  /// see the complete Case history for every Profile they currently teach even
  /// when a collaborator owns the next Action.
  final Set<String>? todayFocusItemIds;

  List<V2FocusItem> get todayFocusItems {
    final ids = todayFocusItemIds;
    if (ids == null) {
      return focusItems;
    }
    return focusItems
        .where((item) => ids.contains(item.id))
        .toList(growable: false);
  }

  List<V2FocusItem> focusItemsForStudent(V2Student student) => focusItems
      .where((item) => item.studentId == student.id)
      .toList(growable: false);

  List<V2FocusItem> closedItemsForStudent(V2Student student) => closedItems
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

  List<V2TimelineEntry> timelineForCase(V2FocusItem item) =>
      _orderedTimeline(timeline.where((entry) => entry.caseId == item.id));

  List<V2TimelineEntry> timelineForStudent(V2Student student) {
    final caseIds = <String>{
      ...focusItemsForStudent(student).map((item) => item.id),
      ...closedItemsForStudent(student).map((item) => item.id),
    };
    return _orderedTimeline(
      timeline.where((entry) => caseIds.contains(entry.caseId)),
    );
  }

  List<V2TimelineEntry> _orderedTimeline(Iterable<V2TimelineEntry> source) {
    final result = source.toList(growable: false);
    if (!result.any((entry) => entry.occurredAt != null)) {
      return result;
    }
    final sortable = result.toList(growable: true)
      ..sort((left, right) {
        final leftAt = left.occurredAt;
        final rightAt = right.occurredAt;
        if (leftAt == null && rightAt == null) return 0;
        if (leftAt == null) return 1;
        if (rightAt == null) return -1;
        return rightAt.compareTo(leftAt);
      });
    return List<V2TimelineEntry>.unmodifiable(sortable);
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
