import '../../cloud/learning_repository.dart';
import '../../cloud/responsibility_read_repository.dart';
import 'v2_read_model_adapter.dart';
import 'v2_workspace_data.dart';

/// A Personal-scope projection over the existing manager-capable workspace.
///
/// The source workspace remains untouched so Organization scope can continue to
/// reuse it later. Personal students are selected exclusively by the
/// server-authoritative Assignment facts from [WorkspaceResponsibilityContext].
class V2PersonalWorkspaceProjection {
  const V2PersonalWorkspaceProjection({
    required this.workspace,
    required this.snapshot,
    required this.personalProfileIds,
    required this.todayCaseIds,
  });

  final TeacherWorkspace workspace;
  final V2ReadModelSnapshot snapshot;
  final Set<String> personalProfileIds;
  final Set<String> todayCaseIds;

  bool get hasPersonalTeachingResponsibility => personalProfileIds.isNotEmpty;

  V2WorkspaceData get workspaceData => V2WorkspaceData(
    students: snapshot.students,
    focusItems: snapshot.focusItems,
    closedItems: snapshot.closedItems,
    timeline: snapshot.timeline,
    businessDate: snapshot.businessDate,
    todayFocusItemIds: todayCaseIds,
  );
}

abstract final class V2ResponsibilityProjection {
  static V2PersonalWorkspaceProjection personal({
    required TeacherWorkspace workspace,
    required WorkspaceResponsibilityContext responsibility,
  }) {
    final organizationId = workspace.organizationId?.trim();
    if (organizationId == null || organizationId.isEmpty) {
      throw const FormatException(
        'Personal responsibility projection requires organization_id.',
      );
    }
    if (responsibility.organizationId != organizationId) {
      throw const FormatException(
        'Responsibility context organization does not match workspace.',
      );
    }

    final profileIds = responsibility.personalProfileIds;
    final availableProfileIds = workspace.students
        .map((profile) => profile.profileId)
        .toSet();
    final missingProfileIds = profileIds.difference(availableProfileIds);
    if (missingProfileIds.isNotEmpty) {
      throw const FormatException(
        'Responsibility context references a Profile missing from workspace.',
      );
    }

    final personalProfiles = workspace.students
        .where((profile) => profileIds.contains(profile.profileId))
        .toList(growable: false);
    final personalWorkspace = TeacherWorkspace(
      viewerName: workspace.viewerName,
      organizationName: workspace.organizationName,
      organizationTimeZone: workspace.organizationTimeZone,
      hasTeachingAccess: responsibility.hasPersonalTeachingResponsibility,
      students: List<WorkspaceStudent>.unmodifiable(personalProfiles),
      loadedAt: workspace.loadedAt,
      businessDate: workspace.businessDate,
      organizationId: workspace.organizationId,
      caseTypes: workspace.caseTypes,
      roles: workspace.roles,
      canManageCaseTypes: workspace.canManageCaseTypes,
      canManageOrganization: workspace.canManageOrganization,
    );

    final todayCaseIds = <String>{};
    for (final profile in personalProfiles) {
      for (final learningCase in profile.cases) {
        final primaryAction = learningCase.primaryAction;
        if (primaryAction != null &&
            responsibility.isPersonalAction(primaryAction.id)) {
          todayCaseIds.add(learningCase.id);
        }
      }
    }

    return V2PersonalWorkspaceProjection(
      workspace: personalWorkspace,
      snapshot: V2ReadModelAdapter.fromWorkspace(personalWorkspace),
      personalProfileIds: Set<String>.unmodifiable(profileIds),
      todayCaseIds: Set<String>.unmodifiable(todayCaseIds),
    );
  }
}
