import 'package:supabase_flutter/supabase_flutter.dart';

import 'organization_management_repository.dart';

class OrganizationMemberProvisioningResult {
  const OrganizationMemberProvisioningResult({
    required this.mode,
    required this.email,
    this.organizationId,
    this.membershipId,
    this.role,
    this.status,
    this.expiresAt,
    this.temporaryPassword,
    this.invitation,
  });

  final String mode;
  final String email;
  final String? organizationId;
  final String? membershipId;
  final String? role;
  final String? status;
  final DateTime? expiresAt;
  final String? temporaryPassword;
  final OrganizationInvitation? invitation;

  bool get hasTemporaryPassword =>
      mode == 'temporary_password' && temporaryPassword != null;

  bool get isInviteCode => mode == 'invite_code';

  bool get isWaitingForOwnerApproval => mode == 'owner_approval';

  factory OrganizationMemberProvisioningResult.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawInvitation = json['invitation'];
    return OrganizationMemberProvisioningResult(
      mode: _requiredString(json['mode'], 'mode'),
      email:
          _stringValue(json['email']) ??
          (rawInvitation is Map
              ? _stringValue(rawInvitation['email']) ?? '—'
              : '—'),
      organizationId: _stringValue(json['organization_id']),
      membershipId: _stringValue(json['membership_id']),
      role:
          _stringValue(json['role']) ??
          (rawInvitation is Map ? _stringValue(rawInvitation['role']) : null),
      status:
          _stringValue(json['status']) ??
          (rawInvitation is Map ? _stringValue(rawInvitation['status']) : null),
      expiresAt: _dateTimeValue(json['expires_at']),
      temporaryPassword: _stringValue(json['temporary_password']),
      invitation: rawInvitation is Map
          ? OrganizationInvitation.fromJson(
              Map<String, dynamic>.from(rawInvitation),
            )
          : null,
    );
  }
}

abstract interface class OrganizationMemberProvisioningRepository {
  Future<OrganizationMemberProvisioningResult> provisionMember({
    required String organizationId,
    required String email,
    required OrganizationInvitationRole role,
  });

  Future<OrganizationMemberProvisioningResult> provisionExistingInvitation({
    required String invitationId,
  });

  Future<OrganizationMemberProvisioningResult> reissueMemberCredential({
    required String organizationId,
    required String membershipId,
  });
}

class SupabaseOrganizationMemberProvisioningRepository
    implements OrganizationMemberProvisioningRepository {
  SupabaseOrganizationMemberProvisioningRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<OrganizationMemberProvisioningResult> provisionMember({
    required String organizationId,
    required String email,
    required OrganizationInvitationRole role,
  }) {
    return _invoke(<String, dynamic>{
      'action': 'provision',
      'email': email.trim(),
      'organization_id': organizationId,
      'role': role.wireValue,
    });
  }

  @override
  Future<OrganizationMemberProvisioningResult> provisionExistingInvitation({
    required String invitationId,
  }) {
    return _invoke(<String, dynamic>{
      'action': 'provision_existing_invitation',
      'invitation_id': invitationId,
    });
  }

  @override
  Future<OrganizationMemberProvisioningResult> reissueMemberCredential({
    required String organizationId,
    required String membershipId,
  }) {
    return _invoke(<String, dynamic>{
      'action': 'reissue_member_credential',
      'membership_id': membershipId,
      'organization_id': organizationId,
    });
  }

  Future<OrganizationMemberProvisioningResult> _invoke(
    Map<String, dynamic> body,
  ) async {
    final authUser = _client.auth.currentUser;
    final accessToken = _client.auth.currentSession?.accessToken;
    if (authUser == null || accessToken == null) {
      throw const AuthException('No active session.');
    }

    final response = await _client.functions.invoke(
      'organization-member-credentials',
      body: body,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
    _assertSameSession(authUser.id);
    final raw = response.data;
    if (raw is! Map) {
      throw const FormatException(
        'Member provisioning returned an invalid result.',
      );
    }
    final json = Map<String, dynamic>.from(raw);
    if (json['ok'] == false) {
      throw OrganizationMemberProvisioningException(
        _stringValue(json['error']) ?? 'member_provisioning_failed',
      );
    }
    return OrganizationMemberProvisioningResult.fromJson(json);
  }

  void _assertSameSession(String userId) {
    if (_client.auth.currentUser?.id != userId) {
      throw const AuthException(
        'The active session changed while running member provisioning.',
      );
    }
  }
}

class OrganizationMembershipState {
  const OrganizationMembershipState({
    required this.status,
    required this.appUserId,
    this.membershipId,
    this.organizationId,
    this.organizationName,
    this.displayName,
    this.onboardingExpiresAt,
  });

  final String status;
  final String? appUserId;
  final String? membershipId;
  final String? organizationId;
  final String? organizationName;
  final String? displayName;
  final DateTime? onboardingExpiresAt;

  bool get isOnboarding => status == 'onboarding';
  bool get isDisabled => status == 'disabled';

  factory OrganizationMembershipState.fromJson(Map<String, dynamic> json) {
    return OrganizationMembershipState(
      status: _stringValue(json['status']) ?? 'unknown',
      appUserId: _stringValue(json['app_user_id']),
      membershipId: _stringValue(json['membership_id']),
      organizationId: _stringValue(json['organization_id']),
      organizationName: _stringValue(json['organization_name']),
      displayName: _stringValue(json['display_name']),
      onboardingExpiresAt: _dateTimeValue(json['onboarding_expires_at']),
    );
  }
}

abstract interface class OrganizationMemberLifecycleRepository {
  Future<OrganizationMembershipState> loadCurrentMembershipState();

  Future<OrganizationMembershipState> completeOnboarding();
}

class SupabaseOrganizationMemberLifecycleRepository
    implements OrganizationMemberLifecycleRepository {
  SupabaseOrganizationMemberLifecycleRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<OrganizationMembershipState> loadCurrentMembershipState() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    final response = await _client.rpc('get_my_membership_state');
    _assertSameSession(authUser.id);
    return OrganizationMembershipState.fromJson(_mapResponse(response));
  }

  @override
  Future<OrganizationMembershipState> completeOnboarding() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    final response = await _client.rpc('complete_member_onboarding');
    _assertSameSession(authUser.id);
    return OrganizationMembershipState.fromJson(_mapResponse(response));
  }

  void _assertSameSession(String userId) {
    if (_client.auth.currentUser?.id != userId) {
      throw const AuthException(
        'The active session changed while running member onboarding.',
      );
    }
  }
}

class OrganizationMemberProvisioningException implements Exception {
  const OrganizationMemberProvisioningException(this.code);

  final String code;

  @override
  String toString() => code;
}

String? organizationMemberProvisioningErrorMessage(Object error) {
  final code = switch (error) {
    OrganizationMemberProvisioningException(:final code) => code,
    PostgrestException(:final message) => message.trim(),
    _ => null,
  };
  return switch (code) {
    'app_user_disabled' => '这个账号已被停用，不能通过邀请恢复，请先走成员恢复流程。',
    'auth_user_not_found' => '账号开通未完成，请重新发放临时密码或邀请。',
    'credential_update_failed' => '临时密码更新失败，成员仍保持待接管状态，请稍后重新发放。',
    'current_membership_immutable' => '不能修改当前登录账号的成员凭据。',
    'invitation_already_exists' => '这个邮箱已有待处理邀请，请在邀请列表中重新发放或继续开通。',
    'invitation_not_approved' => '负责人提名还没有通过审批。',
    'invitation_not_available' => '这条邀请已被使用或撤销，请刷新后重试。',
    'invitation_not_found' => '邀请已不存在，请刷新后重试。',
    'member_not_onboarding' => '该成员已经完成接管或当前不在待接管状态。',
    'member_provisioning_failed' => '账号开通未完成，成员没有获得学生业务权限，请稍后重试。',
    'onboarding_completion_required' => '成员仍需完成首次接管，不能由管理员直接激活。',
    'onboarding_expired' => '接管凭据已过期，请让管理员重新发放临时密码。',
    'onboarding_relogin_required' => '请先用新密码重新登录，再完成账号接管。',
    'organization_manager_required' => '当前账号没有本机构成员管理权限。',
    'organization_owner_required' => '这项操作需要负责人确认。',
    'provision_cleanup_required' => '账号开通遇到恢复异常，请暂时不要重复创建同邮箱账号，并联系维护人员处理。',
    'provision_recovery_required' =>
      '账号开通结果正在恢复中；请刷新邀请列表后点击“继续开通”或“重新发放临时密码”，不要再次创建同邮箱邀请。',
    'user_already_member_elsewhere' => '该账号已经加入其他机构，暂不能重复开通。',
    _ => null,
  };
}

Map<String, dynamic> _mapResponse(dynamic response) {
  if (response is! Map) {
    throw const FormatException('Member lifecycle returned an invalid result.');
  }
  return Map<String, dynamic>.from(response);
}

String? _stringValue(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String _requiredString(Object? value, String field) {
  final normalized = _stringValue(value);
  if (normalized == null) {
    throw FormatException('Missing member provisioning field: $field');
  }
  return normalized;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
