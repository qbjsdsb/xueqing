import 'package:supabase_flutter/supabase_flutter.dart';

import 'paged_rows.dart';

enum OrganizationInvitationRole { owner, admin, teacher }

extension OrganizationInvitationRolePresentation on OrganizationInvitationRole {
  String get wireValue => switch (this) {
    OrganizationInvitationRole.owner => 'org_owner',
    OrganizationInvitationRole.admin => 'org_admin',
    OrganizationInvitationRole.teacher => 'teacher',
  };

  String get label => switch (this) {
    OrganizationInvitationRole.owner => '负责人',
    OrganizationInvitationRole.admin => '管理员',
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
    this.version = 1,
    this.onboardingExpiresAt,
  });

  final String appUserId;
  final String membershipId;
  final String email;
  final String? displayName;
  final String status;
  final List<String> roles;
  final int version;
  final DateTime? onboardingExpiresAt;

  bool get isActive => status == 'active';
  bool get isOnboarding => status == 'onboarding';

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
      version: _intValue(json['version']) ?? 1,
      onboardingExpiresAt: _dateTimeValue(json['onboarding_expires_at']),
    );
  }
}

class OrganizationMemberStatusUpdateResult {
  const OrganizationMemberStatusUpdateResult({
    required this.operationId,
    required this.membershipId,
    required this.appUserId,
    required this.status,
    required this.version,
    required this.endedScopeCount,
    required this.endedAssignmentCount,
  });

  final String operationId;
  final String membershipId;
  final String appUserId;
  final String status;
  final int version;
  final int endedScopeCount;
  final int endedAssignmentCount;

  factory OrganizationMemberStatusUpdateResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationMemberStatusUpdateResult(
      operationId: _requiredString(json['operation_id'], 'operation_id'),
      membershipId: _requiredString(json['membership_id'], 'membership_id'),
      appUserId: _requiredString(json['app_user_id'], 'app_user_id'),
      status: _stringValue(json['status']) ?? 'unknown',
      version: _intValue(json['version']) ?? 1,
      endedScopeCount: _intValue(json['ended_scope_count']) ?? 0,
      endedAssignmentCount: _intValue(json['ended_assignment_count']) ?? 0,
    );
  }
}

class OrganizationTeacherSubjectScope {
  const OrganizationTeacherSubjectScope({
    required this.scopeId,
    required this.membershipId,
    required this.organizationSubjectId,
    required this.teacherName,
    required this.teacherEmail,
    required this.membershipStatus,
    required this.subjectName,
    required this.subjectCode,
    required this.scopeKind,
    required this.status,
    required this.version,
    required this.activeFrom,
    required this.activeTo,
  });

  final String scopeId;
  final String membershipId;
  final String organizationSubjectId;
  final String teacherName;
  final String teacherEmail;
  final String membershipStatus;
  final String subjectName;
  final String subjectCode;
  final String scopeKind;
  final String status;
  final int version;
  final DateTime? activeFrom;
  final DateTime? activeTo;

  bool get isActive => status == 'active';
  bool get isEnded => status == 'ended';

  factory OrganizationTeacherSubjectScope.fromJson(Map<String, dynamic> json) {
    return OrganizationTeacherSubjectScope(
      scopeId: _requiredString(json['scope_id'], 'scope_id'),
      membershipId: _requiredString(json['membership_id'], 'membership_id'),
      organizationSubjectId: _requiredString(
        json['organization_subject_id'],
        'organization_subject_id',
      ),
      teacherName: _stringValue(json['teacher_name']) ?? '未命名老师',
      teacherEmail: _stringValue(json['teacher_email']) ?? '',
      membershipStatus: _stringValue(json['membership_status']) ?? 'unknown',
      subjectName: _stringValue(json['subject_name']) ?? '未命名学科',
      subjectCode: _stringValue(json['subject_code']) ?? '—',
      scopeKind: _stringValue(json['scope_kind']) ?? 'teaching',
      status: _stringValue(json['status']) ?? 'unknown',
      version: _intValue(json['version']) ?? 1,
      activeFrom: _dateTimeValue(json['active_from']),
      activeTo: _dateTimeValue(json['active_to']),
    );
  }
}

class OrganizationTeacherSubjectScopeUpdateResult {
  const OrganizationTeacherSubjectScopeUpdateResult({
    required this.operationId,
    required this.organizationId,
    required this.membershipId,
    required this.organizationSubjectId,
    required this.scopeId,
    required this.status,
    required this.version,
    required this.activeFrom,
    required this.activeTo,
  });

  final String operationId;
  final String organizationId;
  final String membershipId;
  final String organizationSubjectId;
  final String scopeId;
  final String status;
  final int version;
  final DateTime? activeFrom;
  final DateTime? activeTo;

  factory OrganizationTeacherSubjectScopeUpdateResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationTeacherSubjectScopeUpdateResult(
      operationId: _requiredString(json['operation_id'], 'operation_id'),
      organizationId: _requiredString(
        json['organization_id'],
        'organization_id',
      ),
      membershipId: _requiredString(json['membership_id'], 'membership_id'),
      organizationSubjectId: _requiredString(
        json['organization_subject_id'],
        'organization_subject_id',
      ),
      scopeId: _requiredString(json['scope_id'], 'scope_id'),
      status: _stringValue(json['status']) ?? 'unknown',
      version: _intValue(json['version']) ?? 1,
      activeFrom: _dateTimeValue(json['active_from']),
      activeTo: _dateTimeValue(json['active_to']),
    );
  }
}

class OrganizationStudentTeacherAssignment {
  const OrganizationStudentTeacherAssignment({
    required this.assignmentId,
    required this.organizationId,
    required this.studentSubjectProfileId,
    required this.studentId,
    required this.studentName,
    required this.organizationSubjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.membershipId,
    required this.teacherName,
    required this.teacherEmail,
    required this.assignmentRole,
    required this.status,
    required this.version,
    required this.activeFrom,
    required this.activeTo,
    required this.endedAt,
  });

  final String assignmentId;
  final String organizationId;
  final String studentSubjectProfileId;
  final String studentId;
  final String studentName;
  final String organizationSubjectId;
  final String subjectName;
  final String subjectCode;
  final String membershipId;
  final String teacherName;
  final String teacherEmail;
  final String assignmentRole;
  final String status;
  final int version;
  final DateTime? activeFrom;
  final DateTime? activeTo;
  final DateTime? endedAt;

  bool get isActive => status == 'active';
  bool get isLead => assignmentRole == 'lead';

  factory OrganizationStudentTeacherAssignment.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationStudentTeacherAssignment(
      assignmentId: _requiredString(json['assignment_id'], 'assignment_id'),
      organizationId: _requiredString(
        json['organization_id'],
        'organization_id',
      ),
      studentSubjectProfileId: _requiredString(
        json['student_subject_profile_id'],
        'student_subject_profile_id',
      ),
      studentId: _requiredString(json['student_id'], 'student_id'),
      studentName: _stringValue(json['student_name']) ?? '未命名学生',
      organizationSubjectId: _requiredString(
        json['organization_subject_id'],
        'organization_subject_id',
      ),
      subjectName: _stringValue(json['subject_name']) ?? '未命名学科',
      subjectCode: _stringValue(json['subject_code']) ?? '—',
      membershipId: _requiredString(json['membership_id'], 'membership_id'),
      teacherName: _stringValue(json['teacher_name']) ?? '未命名老师',
      teacherEmail: _stringValue(json['teacher_email']) ?? '',
      assignmentRole: _stringValue(json['assignment_role']) ?? 'collaborator',
      status: _stringValue(json['status']) ?? 'unknown',
      version: _intValue(json['version']) ?? 1,
      activeFrom: _dateTimeValue(json['active_from']),
      activeTo: _dateTimeValue(json['active_to']),
      endedAt: _dateTimeValue(json['ended_at']),
    );
  }
}

class OrganizationStudentTeacherAssignmentTransferResult {
  const OrganizationStudentTeacherAssignmentTransferResult({
    required this.operationId,
    required this.organizationId,
    required this.studentSubjectProfileId,
    required this.studentId,
    required this.studentName,
    required this.organizationSubjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.assignmentRole,
    required this.previousAssignmentId,
    required this.previousMembershipId,
    required this.previousTeacherName,
    required this.previousTeacherEmail,
    required this.previousAssignmentVersion,
    required this.replacementAssignmentId,
    required this.replacementMembershipId,
    required this.replacementTeacherName,
    required this.replacementTeacherEmail,
    required this.replacementScopeId,
    required this.replacementAssignmentVersion,
    required this.status,
    required this.activeFrom,
  });

  final String operationId;
  final String organizationId;
  final String studentSubjectProfileId;
  final String studentId;
  final String studentName;
  final String organizationSubjectId;
  final String subjectName;
  final String subjectCode;
  final String assignmentRole;
  final String previousAssignmentId;
  final String previousMembershipId;
  final String previousTeacherName;
  final String previousTeacherEmail;
  final int previousAssignmentVersion;
  final String replacementAssignmentId;
  final String replacementMembershipId;
  final String replacementTeacherName;
  final String replacementTeacherEmail;
  final String replacementScopeId;
  final int replacementAssignmentVersion;
  final String status;
  final DateTime? activeFrom;

  factory OrganizationStudentTeacherAssignmentTransferResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationStudentTeacherAssignmentTransferResult(
      operationId: _requiredString(json['operation_id'], 'operation_id'),
      organizationId: _requiredString(
        json['organization_id'],
        'organization_id',
      ),
      studentSubjectProfileId: _requiredString(
        json['student_subject_profile_id'],
        'student_subject_profile_id',
      ),
      studentId: _requiredString(json['student_id'], 'student_id'),
      studentName: _stringValue(json['student_name']) ?? '未命名学生',
      organizationSubjectId: _requiredString(
        json['organization_subject_id'],
        'organization_subject_id',
      ),
      subjectName: _stringValue(json['subject_name']) ?? '未命名学科',
      subjectCode: _stringValue(json['subject_code']) ?? '—',
      assignmentRole: _stringValue(json['assignment_role']) ?? 'collaborator',
      previousAssignmentId: _requiredString(
        json['previous_assignment_id'],
        'previous_assignment_id',
      ),
      previousMembershipId: _requiredString(
        json['previous_membership_id'],
        'previous_membership_id',
      ),
      previousTeacherName:
          _stringValue(json['previous_teacher_name']) ?? '未命名老师',
      previousTeacherEmail: _stringValue(json['previous_teacher_email']) ?? '',
      previousAssignmentVersion:
          _intValue(json['previous_assignment_version']) ?? 1,
      replacementAssignmentId: _requiredString(
        json['replacement_assignment_id'],
        'replacement_assignment_id',
      ),
      replacementMembershipId: _requiredString(
        json['replacement_membership_id'],
        'replacement_membership_id',
      ),
      replacementTeacherName:
          _stringValue(json['replacement_teacher_name']) ?? '未命名老师',
      replacementTeacherEmail:
          _stringValue(json['replacement_teacher_email']) ?? '',
      replacementScopeId: _requiredString(
        json['replacement_scope_id'],
        'replacement_scope_id',
      ),
      replacementAssignmentVersion:
          _intValue(json['replacement_assignment_version']) ?? 1,
      status: _stringValue(json['status']) ?? 'unknown',
      activeFrom: _dateTimeValue(json['active_from']),
    );
  }
}

class OrganizationStudentSubjectLeadResult {
  const OrganizationStudentSubjectLeadResult({
    required this.operationId,
    required this.organizationId,
    required this.studentId,
    required this.studentName,
    required this.studentSubjectProfileId,
    required this.organizationSubjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.assignmentId,
    required this.assignmentRole,
    required this.assignmentStatus,
    required this.assignmentVersion,
    required this.teacherMembershipId,
    required this.teacherDisplayName,
    required this.teacherEmail,
    required this.teacherScopeId,
    required this.activeFrom,
  });

  final String operationId;
  final String organizationId;
  final String studentId;
  final String studentName;
  final String studentSubjectProfileId;
  final String organizationSubjectId;
  final String subjectName;
  final String subjectCode;
  final String assignmentId;
  final String assignmentRole;
  final String assignmentStatus;
  final int assignmentVersion;
  final String teacherMembershipId;
  final String teacherDisplayName;
  final String teacherEmail;
  final String teacherScopeId;
  final DateTime? activeFrom;

  factory OrganizationStudentSubjectLeadResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationStudentSubjectLeadResult(
      operationId: _requiredString(json['operation_id'], 'operation_id'),
      organizationId: _requiredString(
        json['organization_id'],
        'organization_id',
      ),
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
      subjectCode: _stringValue(json['subject_code']) ?? '—',
      assignmentId: _requiredString(json['assignment_id'], 'assignment_id'),
      assignmentRole: _requiredString(
        json['assignment_role'],
        'assignment_role',
      ),
      assignmentStatus: _requiredString(
        json['assignment_status'],
        'assignment_status',
      ),
      assignmentVersion: _requiredPositiveInt(
        json['assignment_version'],
        'assignment_version',
      ),
      teacherMembershipId: _requiredString(
        json['teacher_membership_id'],
        'teacher_membership_id',
      ),
      teacherDisplayName: _stringValue(json['teacher_display_name']) ?? '未命名老师',
      teacherEmail: _stringValue(json['teacher_email']) ?? '',
      teacherScopeId: _requiredString(
        json['teacher_scope_id'],
        'teacher_scope_id',
      ),
      activeFrom: _dateTimeValue(json['active_from']),
    );
  }
}

class OrganizationTeachingHandoffCase {
  const OrganizationTeachingHandoffCase({
    required this.id,
    required this.title,
    required this.status,
    required this.version,
    required this.ownerMembershipId,
    required this.movesOwner,
  });

  final String id;
  final String title;
  final String status;
  final int version;
  final String ownerMembershipId;
  final bool movesOwner;

  factory OrganizationTeachingHandoffCase.fromJson(Map<String, dynamic> json) {
    return OrganizationTeachingHandoffCase(
      id: _requiredString(json['id'], 'handoff_case_id'),
      title: _stringValue(json['title']) ?? '未命名问题',
      status: _stringValue(json['status']) ?? 'unknown',
      version: _requiredPositiveInt(json['version'], 'handoff_case_version'),
      ownerMembershipId: _requiredString(
        json['owner_membership_id'],
        'handoff_case_owner_membership_id',
      ),
      movesOwner: json['moves_owner'] == true,
    );
  }

  Map<String, dynamic> toPlanJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'status': status,
    'version': version,
    'owner_membership_id': ownerMembershipId,
    'moves_owner': movesOwner,
  };
}

class OrganizationTeachingHandoffAction {
  const OrganizationTeachingHandoffAction({
    required this.id,
    required this.caseId,
    required this.title,
    required this.version,
  });

  final String id;
  final String caseId;
  final String title;
  final int version;

  factory OrganizationTeachingHandoffAction.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationTeachingHandoffAction(
      id: _requiredString(json['id'], 'handoff_action_id'),
      caseId: _requiredString(json['case_id'], 'handoff_action_case_id'),
      title: _stringValue(json['title']) ?? '未命名行动',
      version: _requiredPositiveInt(json['version'], 'handoff_action_version'),
    );
  }

  Map<String, dynamic> toPlanJson() => <String, dynamic>{
    'id': id,
    'case_id': caseId,
    'title': title,
    'version': version,
  };
}

class OrganizationTeachingHandoffPlan {
  const OrganizationTeachingHandoffPlan({
    required this.organizationId,
    required this.businessDate,
    required this.studentSubjectProfileId,
    required this.studentId,
    required this.studentName,
    required this.organizationSubjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.assignmentId,
    required this.assignmentRole,
    required this.assignmentVersion,
    required this.sourceMembershipId,
    required this.sourceTeacherName,
    required this.replacementMembershipId,
    required this.replacementTeacherName,
    required this.replacementScopeId,
    required this.affectedCases,
    required this.affectedActions,
  });

  final String organizationId;
  final DateTime businessDate;
  final String studentSubjectProfileId;
  final String studentId;
  final String studentName;
  final String organizationSubjectId;
  final String subjectName;
  final String subjectCode;
  final String assignmentId;
  final String assignmentRole;
  final int assignmentVersion;
  final String sourceMembershipId;
  final String sourceTeacherName;
  final String replacementMembershipId;
  final String replacementTeacherName;
  final String replacementScopeId;
  final List<OrganizationTeachingHandoffCase> affectedCases;
  final List<OrganizationTeachingHandoffAction> affectedActions;

  int get affectedCaseCount => affectedCases.length;
  int get affectedActionCount => affectedActions.length;

  List<Map<String, dynamic>> get expectedCasesPayload => <Map<String, dynamic>>[
    for (final item in affectedCases) item.toPlanJson(),
  ];

  List<Map<String, dynamic>> get expectedActionsPayload =>
      <Map<String, dynamic>>[
        for (final item in affectedActions) item.toPlanJson(),
      ];

  factory OrganizationTeachingHandoffPlan.fromJson(Map<String, dynamic> json) {
    final rawCases = json['affected_cases'];
    final rawActions = json['affected_actions'];
    if (rawCases is! List || rawActions is! List) {
      throw const FormatException(
        'Teaching handoff plan returned invalid responsibility lists.',
      );
    }
    final cases = <OrganizationTeachingHandoffCase>[
      for (final item in rawCases)
        if (item is Map)
          OrganizationTeachingHandoffCase.fromJson(
            Map<String, dynamic>.from(item),
          )
        else
          throw const FormatException(
            'Teaching handoff plan returned an invalid Case item.',
          ),
    ];
    final actions = <OrganizationTeachingHandoffAction>[
      for (final item in rawActions)
        if (item is Map)
          OrganizationTeachingHandoffAction.fromJson(
            Map<String, dynamic>.from(item),
          )
        else
          throw const FormatException(
            'Teaching handoff plan returned an invalid Action item.',
          ),
    ];
    final businessDate = _dateTimeValue(json['business_date']);
    if (businessDate == null) {
      throw const FormatException(
        'Teaching handoff plan returned invalid business_date.',
      );
    }
    final plan = OrganizationTeachingHandoffPlan(
      organizationId: _requiredString(
        json['organization_id'],
        'organization_id',
      ),
      businessDate: businessDate,
      studentSubjectProfileId: _requiredString(
        json['student_subject_profile_id'],
        'student_subject_profile_id',
      ),
      studentId: _requiredString(json['student_id'], 'student_id'),
      studentName: _stringValue(json['student_name']) ?? '未命名学生',
      organizationSubjectId: _requiredString(
        json['organization_subject_id'],
        'organization_subject_id',
      ),
      subjectName: _stringValue(json['subject_name']) ?? '未命名学科',
      subjectCode: _stringValue(json['subject_code']) ?? '—',
      assignmentId: _requiredString(json['assignment_id'], 'assignment_id'),
      assignmentRole: _requiredString(
        json['assignment_role'],
        'assignment_role',
      ),
      assignmentVersion: _requiredPositiveInt(
        json['assignment_version'],
        'assignment_version',
      ),
      sourceMembershipId: _requiredString(
        json['source_membership_id'],
        'source_membership_id',
      ),
      sourceTeacherName: _stringValue(json['source_teacher_name']) ?? '未命名老师',
      replacementMembershipId: _requiredString(
        json['replacement_membership_id'],
        'replacement_membership_id',
      ),
      replacementTeacherName:
          _stringValue(json['replacement_teacher_name']) ?? '未命名老师',
      replacementScopeId: _requiredString(
        json['replacement_scope_id'],
        'replacement_scope_id',
      ),
      affectedCases: List<OrganizationTeachingHandoffCase>.unmodifiable(cases),
      affectedActions: List<OrganizationTeachingHandoffAction>.unmodifiable(
        actions,
      ),
    );
    final reportedCaseCount = _intValue(json['affected_case_count']);
    final reportedActionCount = _intValue(json['affected_action_count']);
    if (reportedCaseCount != null &&
        reportedCaseCount != plan.affectedCaseCount) {
      throw const FormatException(
        'Teaching handoff plan returned inconsistent Case count.',
      );
    }
    if (reportedActionCount != null &&
        reportedActionCount != plan.affectedActionCount) {
      throw const FormatException(
        'Teaching handoff plan returned inconsistent Action count.',
      );
    }
    return plan;
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
    required this.organizationSubjectIds,
  });

  final String membershipId;
  final String displayName;
  final String email;
  final List<String> organizationSubjectIds;

  bool supportsSubject(String organizationSubjectId) =>
      organizationSubjectIds.contains(organizationSubjectId);

  factory OrganizationSetupTeacher.fromJson(Map<String, dynamic> json) {
    final rawOrganizationSubjectIds = json['organization_subject_ids'];
    if (rawOrganizationSubjectIds is! List) {
      throw const FormatException(
        'Organization setup teacher returned invalid subject ids.',
      );
    }
    return OrganizationSetupTeacher(
      membershipId: _requiredString(json['membership_id'], 'membership_id'),
      displayName: _stringValue(json['display_name']) ?? '未命名老师',
      email: _stringValue(json['email']) ?? '',
      organizationSubjectIds: List<String>.unmodifiable([
        for (final item in rawOrganizationSubjectIds)
          _requiredString(item, 'organization_subject_id'),
      ]),
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

  List<OrganizationSetupSubject> get subjectsWithAvailableTeachers {
    final availableSubjects = <OrganizationSetupSubject>[];
    for (final subject in subjects) {
      if (teachers.any((teacher) => teacher.supportsSubject(subject.id))) {
        availableSubjects.add(subject);
      }
    }
    return List<OrganizationSetupSubject>.unmodifiable(availableSubjects);
  }

  List<OrganizationSetupTeacher> teachersForSubject(
    String organizationSubjectId,
  ) {
    final availableTeachers = <OrganizationSetupTeacher>[];
    for (final teacher in teachers) {
      if (teacher.supportsSubject(organizationSubjectId)) {
        availableTeachers.add(teacher);
      }
    }
    return List<OrganizationSetupTeacher>.unmodifiable(availableTeachers);
  }

  bool get canCreateStudent => subjectsWithAvailableTeachers.isNotEmpty;

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

class OrganizationStudentSubjectService {
  const OrganizationStudentSubjectService({
    required this.profileId,
    required this.organizationSubjectId,
    required this.subjectName,
    required this.status,
    required this.version,
  });

  final String profileId;
  final String organizationSubjectId;
  final String subjectName;
  final String status;
  final int version;

  bool get isActive => status == 'active';
  bool get isInactive => status == 'inactive';
  bool get isArchived => status == 'archived';

  factory OrganizationStudentSubjectService.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationStudentSubjectService(
      profileId: _requiredString(
        json['student_subject_profile_id'],
        'student_subject_profile_id',
      ),
      organizationSubjectId: _requiredString(
        json['organization_subject_id'],
        'organization_subject_id',
      ),
      subjectName: _stringValue(json['display_name']) ?? '未命名学科',
      status: _stringValue(json['status']) ?? 'unknown',
      version: _intValue(json['version']) ?? 1,
    );
  }
}

class OrganizationStudentRecord {
  const OrganizationStudentRecord({
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.status,
    required this.version,
    required this.grade,
    required this.className,
    required this.campus,
    required this.startsOn,
    required this.endsOn,
    required this.subjectNames,
    this.subjectServices = const <OrganizationStudentSubjectService>[],
  });

  final String studentId;
  final String studentName;
  final String? studentCode;
  final String status;
  final int version;
  final String? grade;
  final String? className;
  final String? campus;
  final DateTime? startsOn;
  final DateTime? endsOn;
  final List<String> subjectNames;
  final List<OrganizationStudentSubjectService> subjectServices;

  bool get isActive => status == 'active';
  bool get isMerged => status == 'merged';

  factory OrganizationStudentRecord.fromJson(Map<String, dynamic> json) {
    final rawSubjects = json['subjects'];
    final subjectNames = <String>[];
    final subjectServices = <OrganizationStudentSubjectService>[];
    if (rawSubjects is List) {
      for (final item in rawSubjects) {
        if (item is! Map) continue;
        final mapped = Map<String, dynamic>.from(item);
        final name = _stringValue(mapped['display_name']);
        final profileId = _stringValue(mapped['student_subject_profile_id']);
        if (profileId == null) {
          // Backward-compatible with a server that has not deployed the
          // lifecycle read shape yet.
          if (name != null) subjectNames.add(name);
          continue;
        }
        final service = OrganizationStudentSubjectService.fromJson(mapped);
        subjectServices.add(service);
        if (service.isActive) subjectNames.add(service.subjectName);
      }
    }
    return OrganizationStudentRecord(
      studentId: _requiredString(json['student_id'], 'student_id'),
      studentName: _stringValue(json['student_name']) ?? '未命名学生',
      studentCode: _stringValue(json['student_code']),
      status: _stringValue(json['status']) ?? 'unknown',
      version: _intValue(json['version']) ?? 1,
      grade: _stringValue(json['grade']),
      className: _stringValue(json['class_name']),
      campus: _stringValue(json['campus']),
      startsOn: _dateTimeValue(json['starts_on']),
      endsOn: _dateTimeValue(json['ends_on']),
      subjectNames: List<String>.unmodifiable(subjectNames),
      subjectServices: List<OrganizationStudentSubjectService>.unmodifiable(
        subjectServices,
      ),
    );
  }
}

class OrganizationStudentSubjectLifecycleResult {
  const OrganizationStudentSubjectLifecycleResult({
    required this.operationId,
    required this.organizationId,
    required this.studentId,
    required this.studentName,
    required this.studentSubjectProfileId,
    required this.organizationSubjectId,
    required this.subjectName,
    required this.status,
    required this.profileVersion,
    required this.endedAssignmentCount,
    this.assignmentId,
    this.teacherMembershipId,
    this.teacherDisplayName,
    this.startsOn,
  });

  final String operationId;
  final String organizationId;
  final String studentId;
  final String studentName;
  final String studentSubjectProfileId;
  final String organizationSubjectId;
  final String subjectName;
  final String status;
  final int profileVersion;
  final int endedAssignmentCount;
  final String? assignmentId;
  final String? teacherMembershipId;
  final String? teacherDisplayName;
  final DateTime? startsOn;

  factory OrganizationStudentSubjectLifecycleResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationStudentSubjectLifecycleResult(
      operationId: _requiredString(json['operation_id'], 'operation_id'),
      organizationId: _requiredString(
        json['organization_id'],
        'organization_id',
      ),
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
      status: _stringValue(json['status']) ?? 'unknown',
      profileVersion: _intValue(json['profile_version']) ?? 1,
      endedAssignmentCount: _intValue(json['ended_assignment_count']) ?? 0,
      assignmentId: _stringValue(json['assignment_id']),
      teacherMembershipId: _stringValue(json['teacher_membership_id']),
      teacherDisplayName: _stringValue(json['teacher_display_name']),
      startsOn: _dateTimeValue(json['starts_on']),
    );
  }
}

class OrganizationStudentTeachingLifecycleResult {
  const OrganizationStudentTeachingLifecycleResult({
    required this.operationId,
    required this.organizationId,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.status,
    required this.version,
  });

  final String operationId;
  final String organizationId;
  final String studentId;
  final String studentName;
  final String? studentCode;
  final String status;
  final int version;

  factory OrganizationStudentTeachingLifecycleResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationStudentTeachingLifecycleResult(
      operationId: _requiredString(json['operation_id'], 'operation_id'),
      organizationId: _requiredString(
        json['organization_id'],
        'organization_id',
      ),
      studentId: _requiredString(json['student_id'], 'student_id'),
      studentName: _stringValue(json['student_name']) ?? '未命名学生',
      studentCode: _stringValue(json['student_code']),
      status: _stringValue(json['status']) ?? 'unknown',
      version: _intValue(json['version']) ?? 1,
    );
  }
}

class OrganizationStudentUpdateResult {
  const OrganizationStudentUpdateResult({
    required this.operationId,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.status,
    required this.version,
  });

  final String operationId;
  final String studentId;
  final String studentName;
  final String? studentCode;
  final String status;
  final int version;

  factory OrganizationStudentUpdateResult.fromJson(Map<String, dynamic> json) {
    return OrganizationStudentUpdateResult(
      operationId: _requiredString(json['operation_id'], 'operation_id'),
      studentId: _requiredString(json['student_id'], 'student_id'),
      studentName: _stringValue(json['student_name']) ?? '未命名学生',
      studentCode: _stringValue(json['student_code']),
      status: _stringValue(json['status']) ?? 'unknown',
      version: _intValue(json['version']) ?? 1,
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

  Future<OrganizationMemberStatusUpdateResult> updateMemberStatus({
    required String operationId,
    required String organizationId,
    required String membershipId,
    required int expectedMembershipVersion,
    required String status,
  });

  Future<List<OrganizationTeacherSubjectScope>> listTeacherSubjectScopes({
    required String organizationId,
  });

  Future<OrganizationTeacherSubjectScopeUpdateResult>
  updateTeacherSubjectScope({
    required String operationId,
    required String organizationId,
    required String membershipId,
    required String organizationSubjectId,
    String? scopeId,
    int? expectedScopeVersion,
    required String status,
  });

  Future<List<OrganizationStudentTeacherAssignment>>
  listStudentTeacherAssignments({required String organizationId});

  Future<OrganizationStudentSubjectLeadResult> setStudentSubjectLead({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
    required String teacherMembershipId,
  });

  Future<OrganizationStudentSetupResult> addStudentSubject({
    required String operationId,
    required String organizationId,
    required String studentId,
    required String organizationSubjectId,
    required String teacherMembershipId,
    DateTime? startsOn,
  });

  Future<OrganizationStudentSubjectLifecycleResult> endStudentSubjectService({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
  });

  Future<OrganizationStudentSubjectLifecycleResult>
  restoreStudentSubjectService({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
    required String teacherMembershipId,
    DateTime? startsOn,
  });

  Future<OrganizationStudentTeachingLifecycleResult> pauseStudentTeaching({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
  });

  Future<OrganizationStudentTeachingLifecycleResult> resumeStudentTeaching({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
  });

  Future<OrganizationStudentTeacherAssignmentTransferResult>
  transferStudentTeacherAssignment({
    required String operationId,
    required String organizationId,
    required String assignmentId,
    required int expectedAssignmentVersion,
    required String replacementMembershipId,
  });

  Future<OrganizationTeachingHandoffPlan> previewStudentTeacherHandoff({
    required String organizationId,
    required String assignmentId,
    required String replacementMembershipId,
  });

  Future<OrganizationStudentTeacherAssignmentTransferResult>
  commitStudentTeacherHandoff({
    required String operationId,
    required OrganizationTeachingHandoffPlan plan,
  });

  Future<List<OrganizationStudentRecord>> listStudents({
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

  Future<OrganizationStudentUpdateResult> updateStudent({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    required String status,
  });

  Future<OrganizationStudentUpdateResult> updateStudentProfile({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    required String grade,
    String? className,
    String? campus,
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

String? organizationBackendCompatibilityErrorMessage(Object error) {
  if (error is! PostgrestException) return null;
  final code = error.code?.trim().toUpperCase() ?? '';
  final detail = [
    error.message,
    error.details,
    error.hint,
  ].whereType<Object>().map((item) => item.toString()).join(' ').toLowerCase();
  if (code == 'PGRST202' ||
      detail.contains('could not find the function') ||
      detail.contains('schema cache')) {
    return '当前软件与服务端版本暂不一致，请刷新后重试；如仍出现，请联系负责人更新服务端。';
  }
  return null;
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

String? organizationMemberLifecycleErrorMessage(Object error) {
  final detail = switch (error) {
    AuthException(:final message) => message.trim(),
    PostgrestException(:final message) => message.trim(),
    _ => null,
  };
  if (detail == null) {
    return null;
  }
  return switch (detail.toLowerCase()) {
    'invalid_membership_status_input' => '成员状态信息不完整，请刷新后重试。',
    'organization_not_found' => '机构不存在或已归档，请刷新后重试。',
    'membership_not_found' => '成员档案已变化，请刷新后重试。',
    'membership_version_conflict' => '这位成员刚刚被别人修改，请刷新后重试。',
    'membership_status_unchanged' => '成员状态没有变化，请刷新后重试。',
    'membership_status_transition_invalid' => '当前成员状态不能执行这项转换。',
    'membership_handoff_required' => '这位成员还有未交接的进行中事项，请先完成案件和行动交接。',
    'current_membership_immutable' => '不能停用或恢复当前正在使用的账号。',
    'onboarding_completion_required' => '成员仍需完成首次接管，不能由管理员直接激活。',
    'organization_owner_required' => '负责人状态只能由另一位负责人调整。',
    'last_owner_immutable' => '机构至少要保留一位正常负责人的账号。',
    'operation_id_reuse_conflict' => '这次操作编号已被用于另一项操作，请重新打开后再试。',
    'operation_incomplete' => '上一次操作还没有完成，请稍后重试。',
    'invalid_live_session' => '登录状态已失效，请重新登录。',
    'organization_manager_required' => '当前账号没有本机构管理权限。',
    _ => null,
  };
}

String? organizationTeacherSubjectScopeErrorMessage(Object error) {
  final detail = switch (error) {
    AuthException(:final message) => message.trim(),
    PostgrestException(:final message) => message.trim(),
    _ => null,
  };
  if (detail == null) {
    return null;
  }
  return switch (detail.toLowerCase()) {
    'invalid_teacher_subject_scope_input' => '可教学科配置不完整，请刷新后重试。',
    'organization_not_found' => '机构不存在或已归档，请刷新后重试。',
    'membership_not_found' => '这位老师已不在本机构，请刷新后重试。',
    'teacher_membership_not_active' => '这位老师当前不是在岗状态，请刷新后重试。',
    'teacher_role_required' => '该成员还没有老师角色，请先调整成员角色。',
    'organization_subject_not_found' => '所选学科已变化，请刷新后重新选择。',
    'teacher_subject_scope_already_active' => '这位老师已经拥有该学科的有效范围。',
    'teacher_subject_scope_not_found' => '这条教学范围已变化，请刷新后重试。',
    'teacher_subject_scope_not_active' => '这条教学范围已经结束，请刷新后刷新列表。',
    'teacher_subject_scope_version_conflict' => '这条教学范围刚刚被别人修改，请刷新后重试。',
    'teacher_scope_handoff_required' => '仍有学生任课、开放案件或待办行动未交接，请先完成交接。',
    'operation_id_reuse_conflict' => '这次操作编号已被用于另一项操作，请重新打开后再试。',
    'operation_incomplete' => '上一次操作还没有完成，请稍后重试。',
    'invalid_live_session' => '登录状态已失效，请重新登录。',
    'organization_manager_required' => '当前账号没有本机构管理权限。',
    _ => null,
  };
}

String? organizationStudentTeacherAssignmentErrorMessage(Object error) {
  final detail = switch (error) {
    AuthException(:final message) => message.trim(),
    PostgrestException(:final message) => message.trim(),
    _ => null,
  };
  if (detail == null) {
    return null;
  }
  return switch (detail.toLowerCase()) {
    'invalid_student_subject_lead_assignment_input' => '主责老师设置信息不完整，请刷新后重试。',
    'student_subject_profile_version_conflict' => '这门学生学科档案刚刚发生变化，请刷新后重试。',
    'student_subject_lead_already_assigned' => '这门学科刚刚已经明确了主责老师，请刷新后核对。',
    'teacher_membership_not_found' => '所选老师已不在本机构，请刷新后重新选择。',
    'invalid_student_teacher_assignment_transfer_input' => '任课交接信息不完整，请刷新后重试。',
    'organization_not_found' => '机构不存在或已归档，请刷新后重试。',
    'membership_not_found' => '原任课老师已不在本机构，请刷新后重试。',
    'replacement_teacher_membership_not_found' => '接收老师已不在本机构，请刷新后重试。',
    'student_teacher_assignment_not_found' => '这条任课关系已变化，请刷新后重试。',
    'student_teacher_assignment_version_conflict' => '这条任课关系刚刚被别人修改，请刷新后重试。',
    'student_teacher_assignment_not_active' => '这条任课关系已经结束，请刷新后刷新列表。',
    'student_teacher_assignment_not_current' => '这条任课关系当前不在生效日期内，请刷新后重试。',
    'student_subject_profile_not_found' => '学生学科档案已变化，请刷新后重试。',
    'student_subject_profile_not_active' => '该学生学科档案当前不能交接。',
    'student_not_found' => '学生档案已变化，请刷新后重试。',
    'student_not_active' => '学生当前不是正常教学状态，请先恢复学生状态。',
    'organization_subject_not_found' => '学科档案已变化，请刷新后重试。',
    'organization_subject_not_active' => '该学科已停用，不能建立新的任课关系。',
    'teacher_membership_not_active' => '接收老师当前不是在岗状态，请刷新后重试。',
    'teacher_app_user_not_active' => '接收老师账号当前不可用，请刷新后重试。',
    'teacher_role_required' => '接收成员还没有老师角色，请先调整成员角色。',
    'teacher_subject_scope_required' => '接收老师还没有该学科的有效教学范围，请先配置教学范围。',
    'teacher_assignment_same_teacher' => '接收老师不能与原任课老师相同。',
    'teacher_assignment_already_active' => '接收老师已经拥有同类型的有效任课关系，请刷新后重试。',
    'teacher_scope_handoff_required' => '该老师仍负责未关闭学情或待执行行动，请先完成对应交接，再变更任课关系。',
    'invalid_student_teacher_handoff_input' => '教学责任交接信息不完整，请重新打开交接窗口。',
    'teacher_handoff_plan_stale' => '交接范围刚刚发生变化，请重新核对问题和行动后再确认。',
    'operation_id_reuse_conflict' => '这次操作编号已被用于另一项操作，请重新打开后再试。',
    'operation_incomplete' => '上一次操作还没有完成，请稍后重试。',
    'invalid_live_session' => '登录状态已失效，请重新登录。',
    'organization_manager_required' => '当前账号没有本机构管理权限。',
    _ => null,
  };
}

String? organizationStudentSubjectLifecycleErrorMessage(Object error) {
  final detail = switch (error) {
    AuthException(:final message) => message.trim(),
    PostgrestException(:final message) => message.trim(),
    _ => null,
  };
  if (detail == null) return null;
  return switch (detail.toLowerCase()) {
    'invalid_student_subject_lifecycle_input' => '学科服务状态信息不完整，请刷新后重试。',
    'student_subject_profile_not_found' => '这门学生学科档案已变化，请刷新后重试。',
    'student_subject_profile_archived' => '这门学科档案已经归档，不能直接恢复。',
    'student_subject_service_not_active' => '这门学科当前已经不是进行中状态，请刷新后重试。',
    'student_subject_service_not_inactive' => '这门学科当前不处于可恢复状态，请刷新后重试。',
    'student_subject_pending_actions' => '这门学科还有待执行行动，请先完成、取消或交接行动后再结束学科。',
    'student_subject_open_cases' => '这门学科还有未关闭的学情问题，请先完成验证并关闭 Case 后再结束学科。',
    'student_subject_active_assignment_exists' => '这门学科仍有当前任课关系，请刷新后核对。',
    'student_not_active' => '学生当前不是正常教学状态，恢复学科前请先恢复学生状态。',
    'organization_subject_not_active' => '该机构学科已停用，暂不能恢复学生学科服务。',
    'teacher_membership_not_found' => '所选老师已不在本机构，请刷新后重新选择。',
    'teacher_membership_not_active' => '所选老师当前不是在岗状态，请刷新后重新选择。',
    'teacher_app_user_not_active' => '所选老师账号当前不可用，请刷新后重新选择。',
    'teacher_role_required' => '所选成员还没有老师角色，暂不能负责学生。',
    'teacher_subject_scope_required' => '所选老师没有该学科的有效教学范围，请先配置教学范围。',
    'version_conflict' => '这门学生学科档案刚刚被别人修改，请刷新后重试。',
    'operation_id_reuse_conflict' => '这次操作编号已被用于另一项操作，请重新打开后再试。',
    'operation_incomplete' => '上一次操作还没有完成，请稍后重试。',
    'invalid_live_session' => '登录状态已失效，请重新登录。',
    'organization_not_found' => '机构不存在或已归档，请刷新后重试。',
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
    'invalid_student_subject_setup_input' => '学生、学科或负责老师信息不完整，请刷新后重试。',
    'student_subject_profile_already_exists' =>
      '这个学生已经有这门学科的档案；如需恢复历史学科，请不要重复新增。',
    'student_code_already_exists' => '这个学生编号已被本机构其他学生使用，请核对后修改。',
    'possible_duplicate_student' => '已存在姓名、年级、班级和校区相同的学生；请先核对，确为不同学生时填写不同学生编号。',
    'organization_not_found' => '机构不存在或已归档，请刷新后重试。',
    'organization_subject_not_found' => '所选学科已变化，请刷新后重新选择。',
    'teacher_membership_not_found' => '所选老师已不是本机构的在岗老师，请刷新后重新选择。',
    'teacher_role_required' => '所选成员还没有老师角色，暂不能分配学生。',
    'teacher_subject_scope_required' => '所选老师没有该学科的有效教学范围，请先配置教学范围。',
    'operation_id_reuse_conflict' => '这次操作编号已被用于另一项操作，请重新打开表单后再试。',
    'operation_incomplete' => '上一次操作还没有完成，请稍后重试。',
    'invalid_live_session' => '登录状态已失效，请重新登录。',
    'organization_manager_required' => '当前账号没有本机构管理权限。',
    _ => null,
  };
}

String? organizationStudentTeachingLifecycleErrorMessage(Object error) {
  final detail = switch (error) {
    AuthException(:final message) => message.trim(),
    PostgrestException(:final message) => message.trim(),
    _ => null,
  };
  if (detail == null) return null;
  return switch (detail.toLowerCase()) {
    'invalid_student_teaching_lifecycle_input' => '学生教学状态信息不完整，请刷新后重试。',
    'organization_not_found' => '机构不存在或已归档，请刷新后重试。',
    'student_not_found' => '学生档案已变化，请刷新后重试。',
    'student_merged_immutable' => '已合并学生不能再修改教学状态。',
    'student_archived_immutable' => '已归档学生不能通过暂停/恢复改变状态。',
    'student_teaching_not_active' => '学生当前已经不是正常教学状态，请刷新后重试。',
    'student_teaching_not_paused' => '学生当前不处于暂停教学状态，请刷新后重试。',
    'version_conflict' => '这位学生刚刚被别人修改，请刷新后重试。',
    'operation_id_reuse_conflict' => '这次操作编号已被用于另一项操作，请重新打开后再试。',
    'operation_incomplete' => '上一次操作还没有完成，请稍后重试。',
    'invalid_live_session' => '登录状态已失效，请重新登录。',
    'organization_manager_required' => '当前账号没有本机构管理权限。',
    _ => null,
  };
}

String? organizationStudentLifecycleErrorMessage(Object error) {
  final detail = switch (error) {
    AuthException(:final message) => message.trim(),
    PostgrestException(:final message) => message.trim(),
    _ => null,
  };
  if (detail == null) {
    return null;
  }
  return switch (detail.toLowerCase()) {
    'invalid_student_update_input' => '学生姓名、编号或状态不符合要求。',
    'invalid_student_profile_update_input' => '学生姓名和年级必填；学生编号、班级和校区可以留空。',
    'student_code_already_exists' => '这个学生编号已被本机构其他学生使用，请核对后修改。',
    'possible_duplicate_student' => '已存在姓名、年级、班级和校区相同的学生；请先核对，确为不同学生时填写不同学生编号。',
    'student_enrollment_not_found' => '这位学生缺少可编辑的在读资料，请刷新后重试。',
    'organization_not_found' => '机构不存在或已归档，请刷新后重试。',
    'student_not_found' => '学生档案已变化，请刷新后重试。',
    'student_merged_immutable' => '已合并的学生档案不能直接修改。',
    'student_archive_requires_paused' => '归档前请先暂停教学；临时停课不需要归档。',
    'student_archive_active_subjects' => '这位学生仍有进行中的学科服务，请先逐科完成结束后再归档。',
    'student_unarchive_requires_inactive' => '取消归档后必须先回到暂不教学状态，再决定是否恢复教学。',
    'version_conflict' => '这条学生档案刚刚被别人修改，请刷新后重试。',
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
    'organization_not_available' => '机构已归档，不能接受邀请，请联系负责人。',
    'invitation_already_member' => '当前账号已经拥有该机构的这个身份。',
    'user_already_member_elsewhere' => '当前账号已经加入其他机构，暂不能跨机构加入。',
    'app_user_disabled' => '当前账号已被停用，请联系机构负责人。',
    'onboarding_completion_required' => '当前账号仍需完成首次接管，不能直接通过邀请激活。',
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
    final response = await _callRows(
      'list_organization_members',
      <String, dynamic>{'p_organization_id': organizationId},
    );
    return _mapList(response, OrganizationMember.fromJson);
  }

  @override
  Future<OrganizationMemberStatusUpdateResult> updateMemberStatus({
    required String operationId,
    required String organizationId,
    required String membershipId,
    required int expectedMembershipVersion,
    required String status,
  }) async {
    if (operationId.trim().isEmpty ||
        membershipId.trim().isEmpty ||
        status.trim().isEmpty) {
      throw ArgumentError('Member status identity cannot be empty.');
    }
    final response = await _call(
      'update_organization_membership_status',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_membership_id': membershipId,
        'p_expected_membership_version': expectedMembershipVersion,
        'p_status': status.trim(),
      },
    );
    return OrganizationMemberStatusUpdateResult.fromJson(
      _mapResponse(response),
    );
  }

  @override
  Future<List<OrganizationInvitation>> listInvitations({
    required String organizationId,
  }) async {
    final response = await _callRows(
      'list_organization_invitations',
      <String, dynamic>{'p_organization_id': organizationId},
    );
    return _mapList(response, OrganizationInvitation.fromJson);
  }

  @override
  Future<List<OrganizationTeacherSubjectScope>> listTeacherSubjectScopes({
    required String organizationId,
  }) async {
    final response = await _callRows(
      'list_organization_teacher_subject_scopes',
      <String, dynamic>{'p_organization_id': organizationId},
    );
    return _mapList(response, OrganizationTeacherSubjectScope.fromJson);
  }

  @override
  Future<OrganizationTeacherSubjectScopeUpdateResult>
  updateTeacherSubjectScope({
    required String operationId,
    required String organizationId,
    required String membershipId,
    required String organizationSubjectId,
    String? scopeId,
    int? expectedScopeVersion,
    required String status,
  }) async {
    final normalizedStatus = status.trim();
    final normalizedScopeId = scopeId?.trim();
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        membershipId.trim().isEmpty ||
        organizationSubjectId.trim().isEmpty ||
        normalizedStatus.isEmpty ||
        normalizedStatus != 'active' && normalizedStatus != 'ended' ||
        normalizedScopeId != null && normalizedScopeId.isEmpty ||
        normalizedStatus == 'active' &&
            (normalizedScopeId != null || expectedScopeVersion != null) ||
        normalizedStatus == 'ended' &&
            (normalizedScopeId == null ||
                expectedScopeVersion == null ||
                expectedScopeVersion <= 0)) {
      throw ArgumentError('Teacher subject scope identity is invalid.');
    }
    final response = await _call(
      'update_organization_teacher_subject_scope',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_membership_id': membershipId,
        'p_organization_subject_id': organizationSubjectId,
        'p_scope_id': normalizedScopeId,
        'p_expected_scope_version': expectedScopeVersion,
        'p_status': normalizedStatus,
      },
    );
    return OrganizationTeacherSubjectScopeUpdateResult.fromJson(
      _mapResponse(response),
    );
  }

  @override
  Future<List<OrganizationStudentTeacherAssignment>>
  listStudentTeacherAssignments({required String organizationId}) async {
    final response = await _callRows(
      'list_organization_student_teacher_assignments',
      <String, dynamic>{'p_organization_id': organizationId},
    );
    return _mapList(response, OrganizationStudentTeacherAssignment.fromJson);
  }

  @override
  Future<OrganizationStudentSubjectLeadResult> setStudentSubjectLead({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
    required String teacherMembershipId,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentSubjectProfileId.trim().isEmpty ||
        expectedProfileVersion <= 0 ||
        teacherMembershipId.trim().isEmpty) {
      throw ArgumentError(
        'Student subject Lead assignment identity is invalid.',
      );
    }
    final response = await _call(
      'set_organization_student_subject_lead',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_subject_profile_id': studentSubjectProfileId,
        'p_expected_profile_version': expectedProfileVersion,
        'p_teacher_membership_id': teacherMembershipId,
      },
    );
    return OrganizationStudentSubjectLeadResult.fromJson(
      _mapResponse(response),
    );
  }

  @override
  Future<OrganizationStudentSetupResult> addStudentSubject({
    required String operationId,
    required String organizationId,
    required String studentId,
    required String organizationSubjectId,
    required String teacherMembershipId,
    DateTime? startsOn,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentId.trim().isEmpty ||
        organizationSubjectId.trim().isEmpty ||
        teacherMembershipId.trim().isEmpty) {
      throw ArgumentError('Student subject setup identity is invalid.');
    }
    final response = await _call(
      'add_organization_student_subject_service',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_id': studentId,
        'p_organization_subject_id': organizationSubjectId,
        'p_teacher_membership_id': teacherMembershipId,
        'p_starts_on': _dateOnlyValue(startsOn),
      },
    );
    return OrganizationStudentSetupResult.fromJson(_mapResponse(response));
  }

  @override
  Future<OrganizationStudentSubjectLifecycleResult> endStudentSubjectService({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentSubjectProfileId.trim().isEmpty ||
        expectedProfileVersion <= 0) {
      throw ArgumentError('Student subject lifecycle identity is invalid.');
    }
    final response = await _call(
      'end_organization_student_subject_service',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_subject_profile_id': studentSubjectProfileId,
        'p_expected_profile_version': expectedProfileVersion,
      },
    );
    return OrganizationStudentSubjectLifecycleResult.fromJson(
      _mapResponse(response),
    );
  }

  @override
  Future<OrganizationStudentSubjectLifecycleResult>
  restoreStudentSubjectService({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
    required String teacherMembershipId,
    DateTime? startsOn,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentSubjectProfileId.trim().isEmpty ||
        expectedProfileVersion <= 0 ||
        teacherMembershipId.trim().isEmpty) {
      throw ArgumentError('Student subject lifecycle identity is invalid.');
    }
    final response = await _call(
      'restore_organization_student_subject_service',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_subject_profile_id': studentSubjectProfileId,
        'p_expected_profile_version': expectedProfileVersion,
        'p_teacher_membership_id': teacherMembershipId,
        'p_starts_on': _dateOnlyValue(startsOn),
      },
    );
    return OrganizationStudentSubjectLifecycleResult.fromJson(
      _mapResponse(response),
    );
  }

  @override
  Future<OrganizationStudentTeachingLifecycleResult> pauseStudentTeaching({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentId.trim().isEmpty ||
        expectedStudentVersion <= 0) {
      throw ArgumentError('Student teaching lifecycle identity is invalid.');
    }
    final response = await _call(
      'pause_organization_student_teaching',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_id': studentId,
        'p_expected_student_version': expectedStudentVersion,
      },
    );
    return OrganizationStudentTeachingLifecycleResult.fromJson(
      _mapResponse(response),
    );
  }

  @override
  Future<OrganizationStudentTeachingLifecycleResult> resumeStudentTeaching({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentId.trim().isEmpty ||
        expectedStudentVersion <= 0) {
      throw ArgumentError('Student teaching lifecycle identity is invalid.');
    }
    final response = await _call(
      'resume_organization_student_teaching',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_id': studentId,
        'p_expected_student_version': expectedStudentVersion,
      },
    );
    return OrganizationStudentTeachingLifecycleResult.fromJson(
      _mapResponse(response),
    );
  }

  @override
  Future<OrganizationStudentTeacherAssignmentTransferResult>
  transferStudentTeacherAssignment({
    required String operationId,
    required String organizationId,
    required String assignmentId,
    required int expectedAssignmentVersion,
    required String replacementMembershipId,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        assignmentId.trim().isEmpty ||
        expectedAssignmentVersion <= 0 ||
        replacementMembershipId.trim().isEmpty) {
      throw ArgumentError(
        'Student teacher assignment transfer identity is invalid.',
      );
    }
    final response = await _call(
      'transfer_organization_student_teacher_assignment',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_assignment_id': assignmentId,
        'p_expected_assignment_version': expectedAssignmentVersion,
        'p_replacement_membership_id': replacementMembershipId,
      },
    );
    return OrganizationStudentTeacherAssignmentTransferResult.fromJson(
      _mapResponse(response),
    );
  }

  @override
  Future<OrganizationTeachingHandoffPlan> previewStudentTeacherHandoff({
    required String organizationId,
    required String assignmentId,
    required String replacementMembershipId,
  }) async {
    if (organizationId.trim().isEmpty ||
        assignmentId.trim().isEmpty ||
        replacementMembershipId.trim().isEmpty) {
      throw ArgumentError('Teaching handoff preview identity is invalid.');
    }
    final response = await _call(
      'preview_organization_student_teacher_handoff',
      <String, dynamic>{
        'p_organization_id': organizationId,
        'p_assignment_id': assignmentId,
        'p_replacement_membership_id': replacementMembershipId,
      },
    );
    return OrganizationTeachingHandoffPlan.fromJson(_mapResponse(response));
  }

  @override
  Future<OrganizationStudentTeacherAssignmentTransferResult>
  commitStudentTeacherHandoff({
    required String operationId,
    required OrganizationTeachingHandoffPlan plan,
  }) async {
    if (operationId.trim().isEmpty) {
      throw ArgumentError('Teaching handoff operation identity is invalid.');
    }
    final response = await _call(
      'commit_organization_student_teacher_handoff',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': plan.organizationId,
        'p_assignment_id': plan.assignmentId,
        'p_expected_assignment_version': plan.assignmentVersion,
        'p_replacement_membership_id': plan.replacementMembershipId,
        'p_expected_cases': plan.expectedCasesPayload,
        'p_expected_actions': plan.expectedActionsPayload,
      },
    );
    return OrganizationStudentTeacherAssignmentTransferResult.fromJson(
      _mapResponse(response),
    );
  }

  @override
  Future<List<OrganizationStudentRecord>> listStudents({
    required String organizationId,
  }) async {
    final response = await _callRows(
      'list_organization_students',
      <String, dynamic>{'p_organization_id': organizationId},
    );
    return _mapList(response, OrganizationStudentRecord.fromJson);
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
  Future<OrganizationStudentUpdateResult> updateStudent({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    required String status,
  }) async {
    if (operationId.trim().isEmpty ||
        studentId.trim().isEmpty ||
        name.trim().isEmpty ||
        status.trim().isEmpty) {
      throw ArgumentError('Student update identity cannot be empty.');
    }
    final response = await _call(
      'update_organization_student',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_id': studentId,
        'p_expected_student_version': expectedStudentVersion,
        'p_name': name.trim(),
        'p_student_code': _nullableText(studentCode),
        'p_status': status.trim(),
      },
    );
    return OrganizationStudentUpdateResult.fromJson(_mapResponse(response));
  }

  @override
  Future<OrganizationStudentUpdateResult> updateStudentProfile({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    required String grade,
    String? className,
    String? campus,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentId.trim().isEmpty ||
        expectedStudentVersion <= 0 ||
        name.trim().isEmpty ||
        grade.trim().isEmpty) {
      throw ArgumentError('Student profile update identity cannot be empty.');
    }
    final response = await _call(
      'update_organization_student_profile',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_id': studentId,
        'p_expected_student_version': expectedStudentVersion,
        'p_name': name.trim(),
        'p_student_code': _nullableText(studentCode),
        'p_grade': grade.trim(),
        'p_class_name': _nullableText(className),
        'p_campus': _nullableText(campus),
      },
    );
    return OrganizationStudentUpdateResult.fromJson(_mapResponse(response));
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

  Future<List<Map<String, dynamic>>> _callRows(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    return collectPagedRows(
      loadPage: (from, to) =>
          _client.rpc(functionName, params: params).range(from, to),
      assertSession: () {
        if (_client.auth.currentUser?.id != authUser.id) {
          throw const AuthException(
            'The active session changed while running organization management.',
          );
        }
      },
      invalidResponseMessage:
          'Organization management returned an invalid list.',
    );
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
    'academic_admin' => OrganizationInvitationRole.admin,
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

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
}

int _requiredPositiveInt(Object? value, String field) {
  final parsed = _intValue(value);
  if (parsed == null || parsed <= 0) {
    throw FormatException('Missing organization management field: $field');
  }
  return parsed;
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
