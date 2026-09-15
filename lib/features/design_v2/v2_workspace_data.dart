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

  /// Open cases for one student, ordered by teacher attention rather than by
  /// storage/read-model insertion order.
  ///
  /// The ordering is intentionally deterministic and contains no inference:
  /// overdue/today actions come first, then cases waiting for verification,
  /// then cases with a concrete next step, then recently active cases, and
  /// finally everything else. Ties preserve the incoming read-model order so
  /// existing presentation remains stable when two cases have equal priority.
  List<V2FocusItem> focusItemsForStudent(V2Student student) {
    final result = focusItems
        .where((item) => item.studentId == student.id)
        .toList(growable: true);
    if (result.length < 2) {
      return List<V2FocusItem>.unmodifiable(result);
    }

    final sourceOrder = <String, int>{
      for (var index = 0; index < result.length; index++)
        result[index].id: index,
    };
    final latestActivity = _latestActivityByCaseId(result);

    result.sort((left, right) {
      final leftTiming = _effectiveActionTiming(left);
      final rightTiming = _effectiveActionTiming(right);
      final leftActivity = latestActivity[left.id];
      final rightActivity = latestActivity[right.id];

      final bucketComparison =
          _attentionBucket(
            left,
            timing: leftTiming,
            latestActivity: leftActivity,
          ).compareTo(
            _attentionBucket(
              right,
              timing: rightTiming,
              latestActivity: rightActivity,
            ),
          );
      if (bucketComparison != 0) return bucketComparison;

      final timingComparison = _timingRank(
        leftTiming,
      ).compareTo(_timingRank(rightTiming));
      if (timingComparison != 0) return timingComparison;

      final dueComparison = _compareNullableDateAscending(
        left.dueOn,
        right.dueOn,
      );
      if (dueComparison != 0) return dueComparison;

      final activityComparison = _compareNullableDateDescending(
        leftActivity,
        rightActivity,
      );
      if (activityComparison != 0) return activityComparison;

      return (sourceOrder[left.id] ?? 0).compareTo(sourceOrder[right.id] ?? 0);
    });

    return List<V2FocusItem>.unmodifiable(result);
  }

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

  Map<String, DateTime> _latestActivityByCaseId(List<V2FocusItem> items) {
    final caseIds = items.map((item) => item.id).toSet();
    final result = <String, DateTime>{};
    for (final entry in timeline) {
      final occurredAt = entry.occurredAt;
      if (occurredAt == null || !caseIds.contains(entry.caseId)) continue;
      final current = result[entry.caseId];
      if (current == null || occurredAt.isAfter(current)) {
        result[entry.caseId] = occurredAt;
      }
    }
    return result;
  }

  V2ActionTiming _effectiveActionTiming(V2FocusItem item) {
    final explicit = item.actionTiming;
    if (explicit != null) return explicit;

    final dueOn = item.dueOn;
    final reference = businessDate;
    if (dueOn == null || reference == null) return V2ActionTiming.undated;

    final dueDate = DateTime(dueOn.year, dueOn.month, dueOn.day);
    final businessDay = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    if (dueDate.isBefore(businessDay)) return V2ActionTiming.overdue;
    if (dueDate == businessDay) return V2ActionTiming.today;
    return V2ActionTiming.future;
  }

  int _attentionBucket(
    V2FocusItem item, {
    required V2ActionTiming timing,
    required DateTime? latestActivity,
  }) {
    if (timing == V2ActionTiming.overdue || timing == V2ActionTiming.today) {
      return 0;
    }
    if (item.effectiveStatus == V2CaseStatus.pendingVerification) {
      return 1;
    }
    if (_hasConcreteNextStep(item.nextStep)) {
      return 2;
    }
    if (latestActivity != null) {
      return 3;
    }
    return 4;
  }

  bool _hasConcreteNextStep(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), '');
    return normalized.isNotEmpty &&
        normalized != '待安排' &&
        normalized != '待安排下一步';
  }

  int _timingRank(V2ActionTiming timing) => switch (timing) {
    V2ActionTiming.overdue => 0,
    V2ActionTiming.today => 1,
    V2ActionTiming.future => 2,
    V2ActionTiming.undated => 3,
  };

  int _compareNullableDateAscending(DateTime? left, DateTime? right) {
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return left.compareTo(right);
  }

  int _compareNullableDateDescending(DateTime? left, DateTime? right) {
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
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
