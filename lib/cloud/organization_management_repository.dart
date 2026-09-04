import 'package:supabase_flutter/supabase_flutter.dart';

enum OrganizationInvitationRole { owner, admin, academicAdmin, teacher }

extension OrganizationInvitationRolePresentation on OrganizationInvitationRole {
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

class OrganizationSetupSubject {
  const OrganizationSetupSubject({required this.id, required this.displayName});

  final String id;
  final String displayName;

  factory OrganizationSetupSubject.fromJson(Map<String, dynamic> json) {
    return OrganizationSetupSubject(
      id: _requiredString(json['id'], 'id'),
      displayName: _stringValue(json['display_name']) ?? '未命名学科',
    );
  }
}

class OrganizationSetupTeacher {
  const OrganizationSetupTeacher({
    required this.membershipId,
    required this.displayName,
    required this.email,
  });

  final String membershipId;
  final String displayName;
  final String email;

  factory OrganizationSetupTeacher.fromJson(Map<String, dynamic> json) {
    return OrganizationSetupTeacher(
      membershipId: _requiredString(json['membership_id'], 'membership_id'),
      displayName: _stringValue(json['display_name']) ?? '未命名老师',
      email: _stringValue(json['email']) ?? '',
    );
  }
}

class OrganizationSetupOptions {
  const OrganizationSetupOptions({
    required this.subjects,
    required this.teachers,
  });

  final List<OrganizationSetupSubject> subjects;
  final List<OrganizationSetupTeacher> teachers;

  bool get canCreateStudent => subjects.isNotEmpty && teachers.isNotEmpty;

  factory OrganizationSetupOptions.fromJson(Map<String, dynamic> json) {
    final rawSubjects = json['subjects'];
    final rawTeachers = json['teachers'];
    if (rawSubjects is! List || rawTeachers is! List) {
      throw const FormatException(
        'Organization setup options returned invalid lists.',
      );
    }
    return OrganizationSetupOptions(
      subjects: List<OrganizationSetupSubject>.unmodifiable([
        for (final item in rawSubjects)
          if (item is Map)
            OrganizationSetupSubject.fromJson(Map<String, dynamic>.from(item))
          else
            throw const FormatException(
              'Organization setup returned an invalid subject.',
            ),
      ]),
      teachers: List<OrganizationSetupTeacher>.unmodifiable([
        for (final item in rawTeachers)
          if (item is Map)
            OrganizationSetupTeacher.fromJson(Map<String, dynamic>.from(item))
          else
            throw const FormatException(
              'Organization setup returned an invalid teacher.',
            ),
      ]),
    );
  }
}

class OrganizationStudentSetupResult {
  const OrganizationStudentSetupResult({
    required this.operationId,
    required this.studentId,
    required this.studentName,
    required this.studentSubjectProfileId,
    required this.organizationSubjectId,
    required this.subjectName,
    required this.teacherMembershipId,
    required this.teacherDisplayName,
    required this.startsOn,
  });

  final String operationId;
  final String studentId;
  final String studentName;
  final String studentSubjectProfileId;
  final String organizationSubjectId;
  final String subjectName;
  final String teacherMembershipId;
  final String teacherDisplayName;
  final DateTime? startsOn;

  factory OrganizationStudentSetupResult.fromJson(Map<String, dynamic> json) {
    return OrganizationStudentSetupResult(
      operationId: _requiredString(json['operation_id'], 'operation_id'),
      studentId: _requiredString(json['student_id'], 'student_id'),
      studentName: _stringValue(json['student_name']) ?? '未命名学生',
      studentSubjectProfileId: _requiredString(
        json['student_subject_profile_id'],
        'student_subject_profile_id',
      ),
      organizationSubjectId: _requiredString(
        json['organization_subject_id'],
        'organization_subject_id',
      ),
      subjectName: _stringValue(json['subject_name']) ?? '未命名学科',
      teacherMembershipId: _requiredString(
        json['teacher_membership_id'],
        'teacher_membership_id',
      ),
      teacherDisplayName: _stringValue(json['teacher_display_name']) ?? '未命名老师',
      startsOn: _dateTimeValue(json['starts_on']),
    );
  }
}

class OrganizationSubjectCatalogItem {
  const OrganizationSubjectCatalogItem({
    required this.id,
    required this.code,
    required this.displayName,
  });

  final String id;
  final String code;
  final String displayName;

  factory OrganizationSubjectCatalogItem.fromJson(Map<String, dynamic> json) {
    return OrganizationSubjectCatalogItem(
      id: _requiredString(json['id'], 'id'),
      code: _requiredString(json['code'], 'code'),
      displayName: _stringValue(json['display_name']) ?? '未命名学科',
    );
  }
}

class OrganizationSubjectSetupResult {
  const OrganizationSubjectSetupResult({
    required this.operationId,
    required this.organizationSubjectId,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
  });

  final String operationId;
  final String organizationSubjectId;
  final String subjectId;
  final String subjectCode;
  final String subjectName;

  factory OrganizationSubjectSetupResult.fromJson(Map<String, dynamic> json) {
    return OrganizationSubjectSetupResult(
      operationId: _requiredString(json['operation_id'], 'operation_id'),
      organizationSubjectId: _requiredString(
        json['organization_subject_id'],
        'organization_subject_id',
      ),
      subjectId: _requiredString(json['subject_id'], 'subject_id'),
      subjectCode: _requiredString(json['subject_code'], 'subject_code'),
      subjectName: _stringValue(json['subject_name']) ?? '未命名学科',
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

  Future<OrganizationSetupOptions> listSetupOptions({
    required String organizationId,
  });

  Future<List<OrganizationSubjectCatalogItem>> listSubjectCatalog({
    required String organizationId,
  });

  Future<OrganizationSubjectSetupResult> createSubject({
    required String operationId,
    required String organizationId,
    required String subjectId,
  });

  Future<OrganizationStudentSetupResult> createStudent({
    required String operationId,
    required String organizationId,
    required String name,
    String? studentCode,
    String? grade,
    String? className,
    String? campus,
    required String organizationSubjectId,
    required String teacherMembershipId,
    DateTime? startsOn,
    String? positioning,
    String? strengths,
    String? cadenceNote,
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

/// Accepts a code after the invitee has authenticated with the invited email.
///
/// This is intentionally separate from [OrganizationManagementRepository]:
/// an invited teacher is allowed to accept their own invitation, but must not
/// gain access to the organization management list or controls.
abstract interface class OrganizationInvitationAcceptanceRepository {
  Future<void> acceptInvitation({
    required String inviteCode,
    String? displayName,
  });
}

class SupabaseOrganizationInvitationAcceptanceRepository
    implements OrganizationInvitationAcceptanceRepository {
  SupabaseOrganizationInvitationAcceptanceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> acceptInvitation({
    required String inviteCode,
    String? displayName,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }

    final normalizedDisplayName = displayName?.trim();
    final response = await _client.rpc(
      'accept_organization_invitation',
      params: <String, dynamic>{
        'p_invite_code': inviteCode.trim(),
        'p_display_name':
            normalizedDisplayName == null || normalizedDisplayName.isEmpty
            ? null
            : normalizedDisplayName,
      },
    );
    if (_client.auth.currentUser?.id != authUser.id) {
      throw const AuthException(
        'The active session changed while accepting the invitation.',
      );
    }
    if (response is! Map) {
      throw const FormatException(
        'Invitation acceptance returned an invalid result.',
      );
    }
  }
}

String? organizationSubjectSetupErrorMessage(Object error) {
  final detail = switch (error) {
    AuthException(:final message) => message.trim(),
    PostgrestException(:final message) => message.trim(),
    _ => null,
  };
  if (detail == null) {
    return null;
  }
  return switch (detail.toLowerCase()) {
    'invalid_organization_subject_input' => '学科信息不完整，请刷新后重试。',
    'organization_not_found' => '机构不存在或已归档，请刷新后重试。',
    'subject_not_found' => '这个全局学科已下线，请刷新后重新选择。',
    'organization_subject_already_enabled' => '这个学科已经在本机构启用，请刷新后继续。',
    'operation_id_reuse_conflict' => '这次操作编号已被用于另一项操作，请重新打开后再试。',
    'operation_incomplete' => '上一次操作还没有完成，请稍后重试。',
    'invalid_live_session' => '登录状态已失效，请重新登录。',
    'organization_manager_required' => '当前账号没有本机构管理权限。',
    _ => null,
  };
}

String? organizationStudentSetupErrorMessage(Object error) {
  final detail = switch (error) {
    AuthException(:final message) => message.trim(),
    PostgrestException(:final message) => message.trim(),
    _ => null,
  };
  if (detail == null) {
    return null;
  }
  return switch (detail.toLowerCase()) {
    'invalid_student_setup_input' => '学生信息不完整或过长，请检查后重试。',
    'organization_not_found' => '机构不存在或已归档，请刷新后重试。',
    'organization_subject_not_found' => '所选学科已变化，请刷新后重新选择。',
    'teacher_membership_not_found' => '所选老师已不是本机构的在岗老师，请刷新后重新选择。',
    'teacher_role_required' => '所选成员还没有老师角色，暂不能分配学生。',
    'operation_id_reuse_conflict' => '这次操作编号已被用于另一项操作，请重新打开表单后再试。',
    'operation_incomplete' => '上一次操作还没有完成，请稍后重试。',
    'invalid_live_session' => '登录状态已失效，请重新登录。',
    'organization_manager_required' => '当前账号没有本机构管理权限。',
    _ => null,
  };
}

String? organizationInvitationErrorMessage(Object error) {
  final detail = switch (error) {
    AuthException(:final message) => message.trim(),
    PostgrestException(:final message) => message.trim(),
    _ => null,
  };
  if (detail == null) {
    return null;
  }
  return switch (detail.toLowerCase()) {
    'invalid_invitation_input' => '邀请信息不完整，请检查邮箱和角色。',
    'invalid_live_session' => '登录状态已失效，请重新登录。',
    'organization_manager_required' => '当前账号没有本机构管理权限。',
    'organization_owner_required' => '这项操作需要负责人确认。',
    'role_not_allowed' => '当前账号不能邀请这个角色。',
    'invitee_already_member' => '这个账号已经是本机构成员。',
    'invitation_already_exists' => '这个邮箱已有相同角色的待处理邀请。',
    'invitation_not_awaiting_approval' => '这条邀请已经变化，请刷新后再试。',
    'invitation_not_revocable' => '这条邀请已经不能撤销。',
    'invitation_not_found' => '邀请代码无效，请确认代码完整且仍在有效期内。',
    'invitation_not_approved' => '该负责人邀请还在等待现有负责人的审批。',
    'invitation_not_available' => '该邀请已被使用或撤销。',
    'invitation_expired' => '该邀请已过期，请让负责人重新创建邀请。',
    'invitation_email_mismatch' => '当前登录邮箱与邀请邮箱不一致。',
    'invitation_already_member' => '当前账号已经拥有该机构的这个身份。',
    'user_already_member_elsewhere' => '当前账号已经加入其他机构，暂不能跨机构加入。',
    'app_user_disabled' => '当前账号已被停用，请联系机构负责人。',
    _ => null,
  };
}

class SupabaseOrganizationManagementRepository
    implements OrganizationManagementRepository {
  SupabaseOrganizationManagementRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<OrganizationMember>> listMembers({
    required String organizationId,
  }) async {
    final response = await _call('list_organization_members', <String, dynamic>{
      'p_organization_id': organizationId,
    });
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
  Future<OrganizationSetupOptions> listSetupOptions({
    required String organizationId,
  }) async {
    final response = await _call(
      'list_organization_setup_options',
      <String, dynamic>{'p_organization_id': organizationId},
    );
    return OrganizationSetupOptions.fromJson(_mapResponse(response));
  }

  @override
  Future<List<OrganizationSubjectCatalogItem>> listSubjectCatalog({
    required String organizationId,
  }) async {
    final response = await _call(
      'list_organization_subject_catalog',
      <String, dynamic>{'p_organization_id': organizationId},
    );
    return _mapList(response, OrganizationSubjectCatalogItem.fromJson);
  }

  @override
  Future<OrganizationSubjectSetupResult> createSubject({
    required String operationId,
    required String organizationId,
    required String subjectId,
  }) async {
    if (operationId.trim().isEmpty || subjectId.trim().isEmpty) {
      throw ArgumentError(
        'Organization subject setup identity cannot be empty.',
      );
    }
    final response = await _call(
      'create_organization_subject',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_subject_id': subjectId,
      },
    );
    return OrganizationSubjectSetupResult.fromJson(_mapResponse(response));
  }

  @override
  Future<OrganizationStudentSetupResult> createStudent({
    required String operationId,
    required String organizationId,
    required String name,
    String? studentCode,
    String? grade,
    String? className,
    String? campus,
    required String organizationSubjectId,
    required String teacherMembershipId,
    DateTime? startsOn,
    String? positioning,
    String? strengths,
    String? cadenceNote,
  }) async {
    if (operationId.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Student setup identity cannot be empty.');
    }
    final response = await _call(
      'create_organization_student',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_name': name.trim(),
        'p_student_code': _nullableText(studentCode),
        'p_grade': _nullableText(grade),
        'p_class_name': _nullableText(className),
        'p_campus': _nullableText(campus),
        'p_organization_subject_id': organizationSubjectId,
        'p_teacher_membership_id': teacherMembershipId,
        'p_starts_on': _dateOnlyValue(startsOn),
        'p_positioning': _nullableText(positioning),
        'p_strengths': _nullableText(strengths),
        'p_cadence_note': _nullableText(cadenceNote),
      },
    );
    return OrganizationStudentSetupResult.fromJson(_mapResponse(response));
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

String? _nullableText(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? _dateOnlyValue(DateTime? value) {
  if (value == null) {
    return null;
  }
  String pad(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${pad(value.month)}-${pad(value.day)}';
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
