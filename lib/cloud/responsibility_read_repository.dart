import 'package:supabase_flutter/supabase_flutter.dart';

class WorkspacePersonalAssignment {
  const WorkspacePersonalAssignment({
    required this.assignmentId,
    required this.profileId,
    required this.membershipId,
    required this.assignmentRole,
    required this.businessDate,
  });

  final String assignmentId;
  final String profileId;
  final String membershipId;
  final String assignmentRole;
  final DateTime businessDate;

  factory WorkspacePersonalAssignment.fromJson(Map<String, dynamic> json) {
    return WorkspacePersonalAssignment(
      assignmentId: _requiredString(json['assignment_id'], 'assignment_id'),
      profileId: _requiredString(json['profile_id'], 'profile_id'),
      membershipId: _requiredString(json['membership_id'], 'membership_id'),
      assignmentRole: _requiredString(
        json['assignment_role'],
        'assignment_role',
      ),
      businessDate: _requiredDate(json['business_date'], 'business_date'),
    );
  }
}

class WorkspaceResponsibilityContext {
  const WorkspaceResponsibilityContext({
    required this.organizationId,
    required this.currentMembershipId,
    required this.personalAssignments,
    required this.caseOwnerMembershipIds,
    required this.actionAssignedMembershipIds,
    required this.eventActorMembershipIds,
    required this.memberDisplayNames,
    this.profileLeadMembershipIds = const <String, String?>{},
  });

  final String organizationId;
  final String currentMembershipId;
  final List<WorkspacePersonalAssignment> personalAssignments;
  final Map<String, String> caseOwnerMembershipIds;
  final Map<String, String> actionAssignedMembershipIds;
  final Map<String, String> eventActorMembershipIds;
  final Map<String, String> memberDisplayNames;
  final Map<String, String?> profileLeadMembershipIds;

  bool get hasPersonalTeachingResponsibility => personalAssignments.isNotEmpty;

  Set<String> get personalProfileIds => Set<String>.unmodifiable(
    personalAssignments.map((assignment) => assignment.profileId),
  );

  bool isPersonalProfile(String profileId) => personalAssignments.any(
    (assignment) => assignment.profileId == profileId,
  );

  bool isPersonalAction(String actionId) =>
      actionAssignedMembershipIds[actionId] == currentMembershipId;

  String? leadMembershipIdForProfile(String profileId) =>
      profileLeadMembershipIds[profileId];

  String? leadDisplayNameForProfile(String profileId) =>
      displayNameForMembership(leadMembershipIdForProfile(profileId));

  String? displayNameForMembership(String? membershipId) {
    if (membershipId == null || membershipId.trim().isEmpty) {
      return null;
    }
    return memberDisplayNames[membershipId];
  }

  factory WorkspaceResponsibilityContext.fromJson(Map<String, dynamic> json) {
    final personalAssignments = _mapList(
      json['personal_assignments'],
      'personal_assignments',
    ).map(WorkspacePersonalAssignment.fromJson).toList(growable: false);

    return WorkspaceResponsibilityContext(
      organizationId: _requiredString(
        json['organization_id'],
        'organization_id',
      ),
      currentMembershipId: _requiredString(
        json['current_membership_id'],
        'current_membership_id',
      ),
      personalAssignments: List<WorkspacePersonalAssignment>.unmodifiable(
        personalAssignments,
      ),
      caseOwnerMembershipIds: _membershipMap(
        json['case_owners'],
        keyField: 'case_id',
        collectionField: 'case_owners',
      ),
      actionAssignedMembershipIds: _membershipMap(
        json['action_assignees'],
        keyField: 'action_id',
        collectionField: 'action_assignees',
      ),
      eventActorMembershipIds: _membershipMap(
        json['event_actors'],
        keyField: 'event_id',
        collectionField: 'event_actors',
      ),
      memberDisplayNames: _displayNameMap(json['member_display_names']),
      profileLeadMembershipIds: _profileLeadMembershipMap(
        json['profile_responsibilities'],
      ),
    );
  }
}

abstract interface class ResponsibilityReadRepository {
  Future<WorkspaceResponsibilityContext> loadContext({
    required String organizationId,
  });
}

class SupabaseResponsibilityReadRepository
    implements ResponsibilityReadRepository {
  SupabaseResponsibilityReadRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<WorkspaceResponsibilityContext> loadContext({
    required String organizationId,
  }) async {
    final normalizedOrganizationId = organizationId.trim();
    if (normalizedOrganizationId.isEmpty) {
      throw ArgumentError('organizationId is required.');
    }

    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    final expectedUserId = authUser.id;

    _assertSameSession(expectedUserId);
    final response = await _client.rpc(
      'get_workspace_responsibility_context',
      params: <String, dynamic>{'p_organization_id': normalizedOrganizationId},
    );
    _assertSameSession(expectedUserId);

    if (response is! Map) {
      throw const FormatException(
        'Workspace responsibility context returned an invalid result.',
      );
    }

    return WorkspaceResponsibilityContext.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  void _assertSameSession(String expectedUserId) {
    if (_client.auth.currentUser?.id != expectedUserId) {
      throw const AuthException(
        'The active session changed while loading responsibility context.',
      );
    }
  }
}

String? responsibilityReadErrorMessage(Object error) {
  final detail = switch (error) {
    AuthException(:final message) => message.trim().toLowerCase(),
    PostgrestException(:final message) => message.trim().toLowerCase(),
    _ => null,
  };
  if (detail == null) {
    return null;
  }
  return switch (detail) {
    'invalid_live_session' || 'no active session.' => '登录状态已失效，请重新登录。',
    'organization_membership_required' => '当前账号已不属于这个机构，请重新进入。',
    'invalid_organization_id' => '机构信息不完整，请刷新后重试。',
    'the active session changed while loading responsibility context.' =>
      '登录账号刚刚发生变化，请重新进入后再试。',
    _ => null,
  };
}

List<Map<String, dynamic>> _mapList(Object? value, String field) {
  if (value is! List) {
    throw FormatException('Missing or invalid $field.');
  }
  return List<Map<String, dynamic>>.unmodifiable([
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item) else _invalidRow(field),
  ]);
}

Map<String, String> _membershipMap(
  Object? value, {
  required String keyField,
  required String collectionField,
}) {
  final result = <String, String>{};
  for (final row in _mapList(value, collectionField)) {
    final key = _requiredString(row[keyField], keyField);
    final membershipId = _requiredString(row['membership_id'], 'membership_id');
    if (result.containsKey(key)) {
      throw FormatException('Duplicate $keyField in $collectionField.');
    }
    result[key] = membershipId;
  }
  return Map<String, String>.unmodifiable(result);
}

Map<String, String?> _profileLeadMembershipMap(Object? value) {
  if (value == null) {
    return const <String, String?>{};
  }
  final result = <String, String?>{};
  for (final row in _mapList(value, 'profile_responsibilities')) {
    final profileId = _requiredString(row['profile_id'], 'profile_id');
    final rawLeadMembershipId = row['lead_membership_id'];
    final leadMembershipId = rawLeadMembershipId == null
        ? null
        : _requiredString(rawLeadMembershipId, 'lead_membership_id');
    if (result.containsKey(profileId)) {
      throw const FormatException(
        'Duplicate profile_id in profile_responsibilities.',
      );
    }
    result[profileId] = leadMembershipId;
  }
  return Map<String, String?>.unmodifiable(result);
}

Map<String, String> _displayNameMap(Object? value) {
  final result = <String, String>{};
  for (final row in _mapList(value, 'member_display_names')) {
    final membershipId = _requiredString(row['membership_id'], 'membership_id');
    final displayName = _requiredString(row['display_name'], 'display_name');
    if (result.containsKey(membershipId)) {
      throw const FormatException(
        'Duplicate membership_id in member_display_names.',
      );
    }
    result[membershipId] = displayName;
  }
  return Map<String, String>.unmodifiable(result);
}

Never _invalidRow(String field) {
  throw FormatException('Invalid row in $field.');
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $field.');
  }
  return value.trim();
}

DateTime _requiredDate(Object? value, String field) {
  if (value is DateTime) {
    return DateTime(value.year, value.month, value.day);
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
  }
  throw FormatException('Missing or invalid $field.');
}
