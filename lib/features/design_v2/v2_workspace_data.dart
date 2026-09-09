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

  V2Student studentForFocusItem(V2FocusItem item) => students.firstWhere(
    (student) => student.id == item.studentId,
  );

  List<V2TimelineEntry> timelineForCase(V2FocusItem item) => timeline
      .where((entry) => entry.caseId == item.id)
      .toList(growable: false);

  List<V2TimelineEntry> timelineForStudent(V2Student student) {
    final caseIds = focusItemsForStudent(student).map((item) => item.id).toSet();
    return timeline
        .where((entry) => caseIds.contains(entry.caseId))
        .toList(growable: false);
  }
}

const v2FixtureWorkspaceData = V2WorkspaceData(
  students: v2Students,
  focusItems: v2FocusItems,
  timeline: v2Timeline,
);
