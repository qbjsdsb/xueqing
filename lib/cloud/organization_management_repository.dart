import 'package:supabase_flutter/supabase_flutter.dart';

enum OrganizationInvitationRole {
  owner,
  admin,
  academicAdmin,
  teacher,
}

extension OrganizationInvitationRolePresentation
    on OrganizationInvitationRole {
  String get wireValue => switch (this) {
    OrganizationInvitationRole.owner => 'org_owner',
    OrganizationInvitationRole.admin => 'org_admin',
    OrganizationInvitationRole.academicAdmin => 'academic_admin',
    OrganizationInvitationRole.teacher => 'teacher',
  };

  String get label => switch (this) {
    OrganizationInvitationRole.owner => '负责人',
    OrganizationInvitationRole.admin => '管理员',
    OrganizationInvitationRole.academicAdmin => '教务管理员',
    OrganizationInvitationRole.teacher => '老师',
  };
}

class OrganizationMember {
  const OrganizationMember({
    required this.appUserId,
    required this.membershipId,
    required this.email,
    required this.displayName,
    required this.status,
    required this.roles,
  });

  final String appUserId;
  final String membershipId;
  final String email;
  final String? displayName;
  final String status;
  final List<String> roles;

  bool get isActive => status == 'active';

  factory OrganizationMember.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    final roles = rawRoles is List
        ? <String>[
            for (final role in rawRoles)
              if (role is String && role.trim().isNotEmpty) role,
          ]
        : <String>[];
    return OrganizationMember(
      appUserId: _requiredString(json['app_user_id'], 'app_user_id'),
      membershipId: _requiredString(json['membership_id'], 'membership_id'),
      email: _stringValue(json['email']) ?? '—',
      displayName: _stringValue(json['display_name']),
      status: _stringValue(json['status']) ?? 'unknown',
      roles: List<String>.unmodifiable(roles),
    );
  }
}

class OrganizationInvitation {
  const OrganizationInvitation({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    required this.invitedByName,
    this.inviteCode,
  });

  final String id;
  final String email;
  final OrganizationInvitationRole role;
  final String status;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String? invitedByName;
  final String? inviteCode;

  bool get isAwaitingOwnerApproval => status == 'pending_owner_approval';
  bool get isPending => status == 'pending';

  factory OrganizationInvitation.fromJson(Map<String, dynamic> json) {
    return OrganizationInvitation(
      id: _requiredString(json['id'], 'id'),
      email: _stringValue(json['email']) ?? '—',
      role: _roleFromWire(json['role']),
      status: _stringValue(json['status']) ?? 'unknown',
      expiresAt: _dateTimeValue(json['expires_at']),
      createdAt: _dateTimeValue(json['created_at']),
      invitedByName: _stringValue(json['invited_by_name']),
      inviteCode: _stringValue(json['invite_code']),
    );
  }
}

abstract interface class OrganizationManagementRepository {
  Future<List<OrganizationMember>> listMembers({
    required String organizationId,
  });

  Future<List<OrganizationInvitation>> listInvitations({
    required String organizationId,
  });

  Future<OrganizationInvitation> createInvitation({
    required String organizationId,
    required String email,
    required OrganizationInvitationRole role,
  });

  Future<OrganizationInvitation> approveInvitation({
    required String invitationId,
  });

  Future<OrganizationInvitation> revokeInvitation({
    required String invitationId,
  });
}

class SupabaseOrganizationManagementRepository
    implements OrganizationManagementRepository {
  SupabaseOrganizationManagementRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<OrganizationMember>> listMembers({
    required String organizationId,
  }) async {
    final response = await _call(
      'list_organization_members',
      <String, dynamic>{'p_organization_id': organizationId},
    );
    return _mapList(response, OrganizationMember.fromJson);
  }

  @override
  Future<List<OrganizationInvitation>> listInvitations({
    required String organizationId,
  }) async {
    final response = await _call(
      'list_organization_invitations',
      <String, dynamic>{'p_organization_id': organizationId},
    );
    return _mapList(response, OrganizationInvitation.fromJson);
  }

  @override
  Future<OrganizationInvitation> createInvitation({
    required String organizationId,
    required String email,
    required OrganizationInvitationRole role,
  }) async {
    final response = await _call(
      'create_organization_invitation',
      <String, dynamic>{
        'p_organization_id': organizationId,
        'p_email': email.trim(),
        'p_role': role.wireValue,
      },
    );
    return OrganizationInvitation.fromJson(_mapResponse(response));
  }

  @override
  Future<OrganizationInvitation> approveInvitation({
    required String invitationId,
  }) async {
    final response = await _call(
      'approve_organization_invitation',
      <String, dynamic>{'p_invitation_id': invitationId},
    );
    return OrganizationInvitation.fromJson(_mapResponse(response));
  }

  @override
  Future<OrganizationInvitation> revokeInvitation({
    required String invitationId,
  }) async {
    final response = await _call(
      'revoke_organization_invitation',
      <String, dynamic>{'p_invitation_id': invitationId},
    );
    return OrganizationInvitation.fromJson(_mapResponse(response));
  }

  Future<dynamic> _call(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    final response = await _client.rpc(functionName, params: params);
    if (_client.auth.currentUser?.id != authUser.id) {
      throw const AuthException(
        'The active session changed while running organization management.',
      );
    }
    return response;
  }

  List<T> _mapList<T>(
    dynamic response,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (response is! List) {
      throw const FormatException(
        'Organization management returned an invalid list.',
      );
    }
    return <T>[
      for (final item in response)
        if (item is Map)
          fromJson(Map<String, dynamic>.from(item))
        else
          throw const FormatException(
            'Organization management returned an invalid item.',
          ),
    ];
  }

  Map<String, dynamic> _mapResponse(dynamic response) {
    if (response is! Map) {
      throw const FormatException(
        'Organization management returned an invalid result.',
      );
    }
    return Map<String, dynamic>.from(response);
  }
}

OrganizationInvitationRole _roleFromWire(Object? value) {
  final wire = _requiredString(value, 'role');
  return switch (wire) {
    'org_owner' => OrganizationInvitationRole.owner,
    'org_admin' => OrganizationInvitationRole.admin,
    'academic_admin' => OrganizationInvitationRole.academicAdmin,
    'teacher' => OrganizationInvitationRole.teacher,
    _ => throw FormatException('Unknown organization invitation role: $wire'),
  };
}

String? _stringValue(Object? value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String _requiredString(Object? value, String field) {
  final normalized = _stringValue(value);
  if (normalized == null) {
    throw FormatException('Missing organization management field: $field');
  }
  return normalized;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
