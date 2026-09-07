import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/cloud/organization_management_repository.dart';
import 'package:xueqing/features/organization_management/presentation/'
    'organization_management_page.dart';

class _FakeOrganizationManagementRepository
    implements OrganizationManagementRepository {
  _FakeOrganizationManagementRepository({
    required this.members,
    required this.invitations,
    this.students = const [],
    this.teacherSubjectScopes = const [],
    this.studentTeacherAssignments = const [],
    this.setupOptions = const OrganizationSetupOptions(
      subjects: [OrganizationSetupSubject(id: 'subject-1', displayName: '数学')],
      teachers: [
        OrganizationSetupTeacher(
          membershipId: 'membership-1',
          displayName: '示例老师',
          email: 'teacher@example.com',
          organizationSubjectIds: ['subject-1'],
        ),
      ],
    ),
  });

  final List<OrganizationMember> members;
  final List<OrganizationInvitation> invitations;
  final List<OrganizationStudentRecord> students;
  final List<OrganizationTeacherSubjectScope> teacherSubjectScopes;
  final List<OrganizationStudentTeacherAssignment> studentTeacherAssignments;
  final OrganizationSetupOptions setupOptions;
  final List<OrganizationSubjectCatalogItem> subjectCatalog = const [
    OrganizationSubjectCatalogItem(
      id: 'subject-2',
      code: 'english',
      displayName: '英语',
    ),
  ];
  int approveCount = 0;
  int subjectCreateCount = 0;
  int revokeCount = 0;
  int createCount = 0;
  int studentCreateCount = 0;
  int memberStatusUpdateCount = 0;
  int studentUpdateCount = 0;
  int teacherScopeUpdateCount = 0;
  int assignmentTransferCount = 0;
  int studentSubjectAddCount = 0;
  int studentSubjectEndCount = 0;
  int studentSubjectRestoreCount = 0;
  int studentTeachingPauseCount = 0;
  int studentTeachingResumeCount = 0;
  OrganizationStudentSetupResult? createdStudent;
  OrganizationStudentSetupResult? addedStudentSubject;
  OrganizationStudentUpdateResult? updatedStudent;
  OrganizationStudentTeachingLifecycleResult? updatedStudentTeaching;
  OrganizationMemberStatusUpdateResult? updatedMember;
  OrganizationTeacherSubjectScopeUpdateResult? updatedTeacherScope;
  OrganizationStudentTeacherAssignmentTransferResult? updatedTeacherAssignment;

  @override
  Future<List<OrganizationMember>> listMembers({
    required String organizationId,
  }) async {
    return members;
  }

  @override
  Future<OrganizationMemberStatusUpdateResult> updateMemberStatus({
    required String operationId,
    required String organizationId,
    required String membershipId,
    required int expectedMembershipVersion,
    required String status,
  }) async {
    memberStatusUpdateCount++;
    final index = members.indexWhere(
      (member) => member.membershipId == membershipId,
    );
    if (index < 0) {
      throw StateError('Member was not found in the fake repository.');
    }
    final member = members[index];
    members[index] = OrganizationMember(
      appUserId: member.appUserId,
      membershipId: member.membershipId,
      email: member.email,
      displayName: member.displayName,
      status: status,
      roles: member.roles,
      version: expectedMembershipVersion + 1,
      onboardingExpiresAt: status == 'active'
          ? null
          : member.onboardingExpiresAt,
    );
    updatedMember = OrganizationMemberStatusUpdateResult(
      operationId: operationId,
      membershipId: membershipId,
      appUserId: members[index].appUserId,
      status: status,
      version: expectedMembershipVersion + 1,
      endedScopeCount: 0,
      endedAssignmentCount: 0,
    );
    return updatedMember!;
  }

  @override
  Future<List<OrganizationInvitation>> listInvitations({
    required String organizationId,
  }) async {
    return invitations;
  }

  @override
  Future<List<OrganizationTeacherSubjectScope>> listTeacherSubjectScopes({
    required String organizationId,
  }) async {
    return teacherSubjectScopes;
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
    teacherScopeUpdateCount++;
    if (status == 'ended') {
      final index = teacherSubjectScopes.indexWhere(
        (scope) => scope.scopeId == scopeId,
      );
      if (index < 0) {
        throw StateError('Teacher scope was not found in the fake repository.');
      }
      final previous = teacherSubjectScopes[index];
      final updated = OrganizationTeacherSubjectScope(
        scopeId: previous.scopeId,
        membershipId: previous.membershipId,
        organizationSubjectId: previous.organizationSubjectId,
        teacherName: previous.teacherName,
        teacherEmail: previous.teacherEmail,
        membershipStatus: previous.membershipStatus,
        subjectName: previous.subjectName,
        subjectCode: previous.subjectCode,
        scopeKind: previous.scopeKind,
        status: 'ended',
        version: previous.version + 1,
        activeFrom: previous.activeFrom,
        activeTo: DateTime(2026, 9, 4),
      );
      teacherSubjectScopes[index] = updated;
      updatedTeacherScope = OrganizationTeacherSubjectScopeUpdateResult(
        operationId: operationId,
        organizationId: organizationId,
        membershipId: membershipId,
        organizationSubjectId: organizationSubjectId,
        scopeId: updated.scopeId,
        status: updated.status,
        version: updated.version,
        activeFrom: updated.activeFrom,
        activeTo: updated.activeTo,
      );
      return updatedTeacherScope!;
    }
    final teacher = setupOptions.teachers.firstWhere(
      (item) => item.membershipId == membershipId,
    );
    final subject = setupOptions.subjects.firstWhere(
      (item) => item.id == organizationSubjectId,
    );
    final scope = OrganizationTeacherSubjectScope(
      scopeId: 'scope-$teacherScopeUpdateCount',
      membershipId: membershipId,
      organizationSubjectId: organizationSubjectId,
      teacherName: teacher.displayName,
      teacherEmail: teacher.email,
      membershipStatus: 'active',
      subjectName: subject.displayName,
      subjectCode: subject.displayName.toLowerCase(),
      scopeKind: 'teaching',
      status: 'active',
      version: 1,
      activeFrom: DateTime(2026, 9, 4),
      activeTo: null,
    );
    teacherSubjectScopes.add(scope);
    updatedTeacherScope = OrganizationTeacherSubjectScopeUpdateResult(
      operationId: operationId,
      organizationId: organizationId,
      membershipId: membershipId,
      organizationSubjectId: organizationSubjectId,
      scopeId: scope.scopeId,
      status: scope.status,
      version: scope.version,
      activeFrom: scope.activeFrom,
      activeTo: scope.activeTo,
    );
    return updatedTeacherScope!;
  }

  @override
  Future<List<OrganizationStudentTeacherAssignment>>
  listStudentTeacherAssignments({required String organizationId}) async {
    return studentTeacherAssignments;
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
    studentSubjectAddCount++;
    final subject = setupOptions.subjects.firstWhere(
      (item) => item.id == organizationSubjectId,
    );
    final teacher = setupOptions.teachers.firstWhere(
      (item) => item.membershipId == teacherMembershipId,
    );
    addedStudentSubject = OrganizationStudentSetupResult(
      operationId: operationId,
      studentId: studentId,
      studentName: students
          .firstWhere((item) => item.studentId == studentId)
          .studentName,
      studentSubjectProfileId: 'profile-added-$studentSubjectAddCount',
      organizationSubjectId: organizationSubjectId,
      subjectName: subject.displayName,
      teacherMembershipId: teacherMembershipId,
      teacherDisplayName: teacher.displayName,
      startsOn: startsOn ?? DateTime(2026, 9, 4),
    );
    studentTeacherAssignments.add(
      OrganizationStudentTeacherAssignment(
        assignmentId: 'assignment-added-$studentSubjectAddCount',
        organizationId: organizationId,
        studentSubjectProfileId: addedStudentSubject!.studentSubjectProfileId,
        studentId: studentId,
        studentName: addedStudentSubject!.studentName,
        organizationSubjectId: organizationSubjectId,
        subjectName: subject.displayName,
        subjectCode: subject.displayName.toLowerCase(),
        membershipId: teacherMembershipId,
        teacherName: teacher.displayName,
        teacherEmail: teacher.email,
        assignmentRole: 'lead',
        status: 'active',
        version: 1,
        activeFrom: addedStudentSubject!.startsOn,
        activeTo: null,
        endedAt: null,
      ),
    );
    final studentIndex = students.indexWhere(
      (item) => item.studentId == studentId,
    );
    if (studentIndex >= 0) {
      final previous = students[studentIndex];
      students[studentIndex] = OrganizationStudentRecord(
        studentId: previous.studentId,
        studentName: previous.studentName,
        studentCode: previous.studentCode,
        status: previous.status,
        version: previous.version,
        grade: previous.grade,
        className: previous.className,
        campus: previous.campus,
        startsOn: previous.startsOn,
        endsOn: previous.endsOn,
        subjectNames: <String>[
          ...previous.subjectNames,
          if (!previous.subjectNames.contains(subject.displayName))
            subject.displayName,
        ],
        subjectServices: <OrganizationStudentSubjectService>[
          ...previous.subjectServices,
          OrganizationStudentSubjectService(
            profileId: addedStudentSubject!.studentSubjectProfileId,
            organizationSubjectId: organizationSubjectId,
            subjectName: subject.displayName,
            status: 'active',
            version: 1,
          ),
        ],
      );
    }
    return addedStudentSubject!;
  }

  @override
  Future<OrganizationStudentSubjectLifecycleResult> endStudentSubjectService({
    required String operationId,
    required String organizationId,
    required String studentSubjectProfileId,
    required int expectedProfileVersion,
  }) async {
    studentSubjectEndCount++;
    final studentIndex = students.indexWhere(
      (student) => student.subjectServices.any(
        (service) => service.profileId == studentSubjectProfileId,
      ),
    );
    if (studentIndex < 0) throw StateError('Subject service not found.');
    final previous = students[studentIndex];
    final services = <OrganizationStudentSubjectService>[
      for (final service in previous.subjectServices)
        if (service.profileId == studentSubjectProfileId)
          OrganizationStudentSubjectService(
            profileId: service.profileId,
            organizationSubjectId: service.organizationSubjectId,
            subjectName: service.subjectName,
            status: 'inactive',
            version: expectedProfileVersion + 1,
          )
        else
          service,
    ];
    final target = services.firstWhere(
      (service) => service.profileId == studentSubjectProfileId,
    );
    students[studentIndex] = OrganizationStudentRecord(
      studentId: previous.studentId,
      studentName: previous.studentName,
      studentCode: previous.studentCode,
      status: previous.status,
      version: previous.version,
      grade: previous.grade,
      className: previous.className,
      campus: previous.campus,
      startsOn: previous.startsOn,
      endsOn: previous.endsOn,
      subjectNames: [
        for (final service in services)
          if (service.isActive) service.subjectName,
      ],
      subjectServices: services,
    );
    return OrganizationStudentSubjectLifecycleResult(
      operationId: operationId,
      organizationId: organizationId,
      studentId: previous.studentId,
      studentName: previous.studentName,
      studentSubjectProfileId: target.profileId,
      organizationSubjectId: target.organizationSubjectId,
      subjectName: target.subjectName,
      status: target.status,
      profileVersion: target.version,
      endedAssignmentCount: 1,
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
    studentSubjectRestoreCount++;
    final studentIndex = students.indexWhere(
      (student) => student.subjectServices.any(
        (service) => service.profileId == studentSubjectProfileId,
      ),
    );
    if (studentIndex < 0) throw StateError('Subject service not found.');
    final previous = students[studentIndex];
    final services = <OrganizationStudentSubjectService>[
      for (final service in previous.subjectServices)
        if (service.profileId == studentSubjectProfileId)
          OrganizationStudentSubjectService(
            profileId: service.profileId,
            organizationSubjectId: service.organizationSubjectId,
            subjectName: service.subjectName,
            status: 'active',
            version: expectedProfileVersion + 1,
          )
        else
          service,
    ];
    final target = services.firstWhere(
      (service) => service.profileId == studentSubjectProfileId,
    );
    final eligibleTeachers = setupOptions.teachersForSubject(
      target.organizationSubjectId,
    );
    if (eligibleTeachers.isEmpty) {
      throw StateError('No eligible teacher for restored subject service.');
    }
    final teacher = eligibleTeachers.firstWhere(
      (item) => item.membershipId == teacherMembershipId,
      orElse: () => eligibleTeachers.first,
    );
    students[studentIndex] = OrganizationStudentRecord(
      studentId: previous.studentId,
      studentName: previous.studentName,
      studentCode: previous.studentCode,
      status: previous.status,
      version: previous.version,
      grade: previous.grade,
      className: previous.className,
      campus: previous.campus,
      startsOn: previous.startsOn,
      endsOn: previous.endsOn,
      subjectNames: [
        for (final service in services)
          if (service.isActive) service.subjectName,
      ],
      subjectServices: services,
    );
    studentTeacherAssignments.add(
      OrganizationStudentTeacherAssignment(
        assignmentId: 'assignment-restored-$studentSubjectRestoreCount',
        organizationId: organizationId,
        studentSubjectProfileId: target.profileId,
        studentId: previous.studentId,
        studentName: previous.studentName,
        organizationSubjectId: target.organizationSubjectId,
        subjectName: target.subjectName,
        subjectCode: target.subjectName.toLowerCase(),
        membershipId: teacher.membershipId,
        teacherName: teacher.displayName,
        teacherEmail: teacher.email,
        assignmentRole: 'lead',
        status: 'active',
        version: 1,
        activeFrom: startsOn ?? DateTime(2026, 9, 8),
        activeTo: null,
        endedAt: null,
      ),
    );
    return OrganizationStudentSubjectLifecycleResult(
      operationId: operationId,
      organizationId: organizationId,
      studentId: previous.studentId,
      studentName: previous.studentName,
      studentSubjectProfileId: target.profileId,
      organizationSubjectId: target.organizationSubjectId,
      subjectName: target.subjectName,
      status: target.status,
      profileVersion: target.version,
      endedAssignmentCount: 0,
      assignmentId: 'assignment-restored-$studentSubjectRestoreCount',
      teacherMembershipId: teacher.membershipId,
      teacherDisplayName: teacher.displayName,
      startsOn: startsOn ?? DateTime(2026, 9, 8),
    );
  }

  @override
  Future<OrganizationStudentTeachingLifecycleResult> pauseStudentTeaching({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
  }) async {
    studentTeachingPauseCount++;
    return _setStudentTeachingStatus(
      operationId: operationId,
      organizationId: organizationId,
      studentId: studentId,
      expectedStudentVersion: expectedStudentVersion,
      status: 'inactive',
    );
  }

  @override
  Future<OrganizationStudentTeachingLifecycleResult> resumeStudentTeaching({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
  }) async {
    studentTeachingResumeCount++;
    return _setStudentTeachingStatus(
      operationId: operationId,
      organizationId: organizationId,
      studentId: studentId,
      expectedStudentVersion: expectedStudentVersion,
      status: 'active',
    );
  }

  OrganizationStudentTeachingLifecycleResult _setStudentTeachingStatus({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String status,
  }) {
    final index = students.indexWhere(
      (student) => student.studentId == studentId,
    );
    if (index < 0) throw StateError('Student not found.');
    final previous = students[index];
    final next = OrganizationStudentRecord(
      studentId: previous.studentId,
      studentName: previous.studentName,
      studentCode: previous.studentCode,
      status: status,
      version: expectedStudentVersion + 1,
      grade: previous.grade,
      className: previous.className,
      campus: previous.campus,
      startsOn: previous.startsOn,
      endsOn: previous.endsOn,
      subjectNames: previous.subjectNames,
      subjectServices: previous.subjectServices,
    );
    students[index] = next;
    updatedStudentTeaching = OrganizationStudentTeachingLifecycleResult(
      operationId: operationId,
      organizationId: organizationId,
      studentId: studentId,
      studentName: next.studentName,
      studentCode: next.studentCode,
      status: status,
      version: next.version,
    );
    return updatedStudentTeaching!;
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
    assignmentTransferCount++;
    final index = studentTeacherAssignments.indexWhere(
      (assignment) => assignment.assignmentId == assignmentId,
    );
    if (index < 0) {
      throw StateError('Student teacher assignment was not found in the fake.');
    }
    final previous = studentTeacherAssignments[index];
    final replacement = setupOptions.teachers.firstWhere(
      (teacher) => teacher.membershipId == replacementMembershipId,
    );
    final ended = OrganizationStudentTeacherAssignment(
      assignmentId: previous.assignmentId,
      organizationId: previous.organizationId,
      studentSubjectProfileId: previous.studentSubjectProfileId,
      studentId: previous.studentId,
      studentName: previous.studentName,
      organizationSubjectId: previous.organizationSubjectId,
      subjectName: previous.subjectName,
      subjectCode: previous.subjectCode,
      membershipId: previous.membershipId,
      teacherName: previous.teacherName,
      teacherEmail: previous.teacherEmail,
      assignmentRole: previous.assignmentRole,
      status: 'ended',
      version: expectedAssignmentVersion + 1,
      activeFrom: previous.activeFrom,
      activeTo: DateTime(2026, 9, 4),
      endedAt: DateTime(2026, 9, 4),
    );
    final active = OrganizationStudentTeacherAssignment(
      assignmentId: 'assignment-transfer-$assignmentTransferCount',
      organizationId: previous.organizationId,
      studentSubjectProfileId: previous.studentSubjectProfileId,
      studentId: previous.studentId,
      studentName: previous.studentName,
      organizationSubjectId: previous.organizationSubjectId,
      subjectName: previous.subjectName,
      subjectCode: previous.subjectCode,
      membershipId: replacement.membershipId,
      teacherName: replacement.displayName,
      teacherEmail: replacement.email,
      assignmentRole: previous.assignmentRole,
      status: 'active',
      version: 1,
      activeFrom: DateTime(2026, 9, 4),
      activeTo: null,
      endedAt: null,
    );
    studentTeacherAssignments[index] = ended;
    studentTeacherAssignments.add(active);
    updatedTeacherAssignment =
        OrganizationStudentTeacherAssignmentTransferResult(
          operationId: operationId,
          organizationId: organizationId,
          studentSubjectProfileId: previous.studentSubjectProfileId,
          studentId: previous.studentId,
          studentName: previous.studentName,
          organizationSubjectId: previous.organizationSubjectId,
          subjectName: previous.subjectName,
          subjectCode: previous.subjectCode,
          assignmentRole: previous.assignmentRole,
          previousAssignmentId: previous.assignmentId,
          previousMembershipId: previous.membershipId,
          previousTeacherName: previous.teacherName,
          previousTeacherEmail: previous.teacherEmail,
          previousAssignmentVersion: expectedAssignmentVersion + 1,
          replacementAssignmentId: active.assignmentId,
          replacementMembershipId: active.membershipId,
          replacementTeacherName: active.teacherName,
          replacementTeacherEmail: active.teacherEmail,
          replacementScopeId: 'scope-transfer-$assignmentTransferCount',
          replacementAssignmentVersion: active.version,
          status: 'transferred',
          activeFrom: active.activeFrom,
        );
    return updatedTeacherAssignment!;
  }

  @override
  Future<List<OrganizationStudentRecord>> listStudents({
    required String organizationId,
  }) async {
    return students;
  }

  @override
  Future<OrganizationSetupOptions> listSetupOptions({
    required String organizationId,
  }) async {
    return setupOptions;
  }

  @override
  Future<List<OrganizationSubjectCatalogItem>> listSubjectCatalog({
    required String organizationId,
  }) async {
    return subjectCatalog;
  }

  @override
  Future<OrganizationSubjectSetupResult> createSubject({
    required String operationId,
    required String organizationId,
    required String subjectId,
  }) async {
    subjectCreateCount++;
    return OrganizationSubjectSetupResult(
      operationId: operationId,
      organizationSubjectId: 'organization-subject-$subjectCreateCount',
      subjectId: subjectId,
      subjectCode: 'english',
      subjectName: '英语',
    );
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
    studentCreateCount++;
    createdStudent = OrganizationStudentSetupResult(
      operationId: operationId,
      studentId: 'student-$studentCreateCount',
      studentName: name,
      studentSubjectProfileId: 'profile-$studentCreateCount',
      organizationSubjectId: organizationSubjectId,
      subjectName: '数学',
      teacherMembershipId: teacherMembershipId,
      teacherDisplayName: '示例老师',
      startsOn: startsOn ?? DateTime(2026, 9, 4),
    );
    return createdStudent!;
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
    studentUpdateCount++;
    updatedStudent = OrganizationStudentUpdateResult(
      operationId: operationId,
      studentId: studentId,
      studentName: name,
      studentCode: studentCode,
      status: status,
      version: expectedStudentVersion + 1,
    );
    return updatedStudent!;
  }

  @override
  Future<OrganizationInvitation> createInvitation({
    required String organizationId,
    required String email,
    required OrganizationInvitationRole role,
  }) async {
    createCount++;
    return OrganizationInvitation(
      id: 'created',
      email: email,
      role: role,
      status: 'pending',
      expiresAt: DateTime(2026, 9, 11),
      createdAt: DateTime(2026, 9, 4),
      invitedByName: '负责人',
      inviteCode: '0123456789abcdef',
    );
  }

  @override
  Future<OrganizationInvitation> approveInvitation({
    required String invitationId,
  }) async {
    approveCount++;
    return OrganizationInvitation(
      id: invitationId,
      email: 'owner@example.com',
      role: OrganizationInvitationRole.owner,
      status: 'pending',
      expiresAt: DateTime(2026, 9, 11),
      createdAt: DateTime(2026, 9, 4),
      invitedByName: '管理员',
    );
  }

  @override
  Future<OrganizationInvitation> revokeInvitation({
    required String invitationId,
  }) async {
    revokeCount++;
    return OrganizationInvitation(
      id: invitationId,
      email: 'owner@example.com',
      role: OrganizationInvitationRole.owner,
      status: 'revoked',
      expiresAt: DateTime(2026, 9, 11),
      createdAt: DateTime(2026, 9, 4),
      invitedByName: '管理员',
    );
  }
}

OrganizationMember _member({
  required String name,
  required String email,
  required List<String> roles,
}) {
  return OrganizationMember(
    appUserId: email,
    membershipId: '$email-membership',
    email: email,
    displayName: name,
    status: 'active',
    roles: roles,
  );
}

OrganizationInvitation _ownerNomination() {
  return OrganizationInvitation(
    id: 'invitation-owner',
    email: 'owner@example.com',
    role: OrganizationInvitationRole.owner,
    status: 'pending_owner_approval',
    expiresAt: DateTime(2026, 9, 11),
    createdAt: DateTime(2026, 9, 4),
    invitedByName: '示例管理员',
  );
}

OrganizationStudentRecord _studentRecord({
  String id = 'student-1',
  String name = '原学生',
  String code = 'S-001',
  String status = 'active',
  int version = 3,
}) {
  return OrganizationStudentRecord(
    studentId: id,
    studentName: name,
    studentCode: code,
    status: status,
    version: version,
    grade: '初二',
    className: '一班',
    campus: '本部',
    startsOn: DateTime(2026, 9, 1),
    endsOn: null,
    subjectNames: ['数学'],
    subjectServices: const [
      OrganizationStudentSubjectService(
        profileId: 'profile-1',
        organizationSubjectId: 'subject-1',
        subjectName: '数学',
        status: 'active',
        version: 1,
      ),
    ],
  );
}

OrganizationStudentTeacherAssignment _studentTeacherAssignment() {
  return OrganizationStudentTeacherAssignment(
    assignmentId: 'assignment-1',
    organizationId: 'org-1',
    studentSubjectProfileId: 'profile-1',
    studentId: 'student-1',
    studentName: '原学生',
    organizationSubjectId: 'subject-1',
    subjectName: '数学',
    subjectCode: 'math',
    membershipId: 'membership-1',
    teacherName: '原老师',
    teacherEmail: 'old-teacher@example.com',
    assignmentRole: 'lead',
    status: 'active',
    version: 1,
    activeFrom: DateTime(2026, 9, 1),
    activeTo: null,
    endedAt: null,
  );
}

Future<void> _pumpManagement(
  WidgetTester tester,
  _FakeOrganizationManagementRepository repository, {
  List<String> roles = const ['org_owner'],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: OrganizationManagementPage(
            repository: repository,
            organizationId: 'org-1',
            organizationName: '示例机构',
            roles: roles,
            canManageCaseTypes: true,
            onOpenCaseTypes: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectManagementArea(WidgetTester tester, String label) async {
  final key = switch (label) {
    '成员' => const Key('management-area-people'),
    '学生' => const Key('management-area-students'),
    '设置' => const Key('management-area-settings'),
    _ => throw ArgumentError.value(label, 'label', 'Unknown management area'),
  };
  final target = find.byKey(key);
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows organization members and pending owner approval', (
    tester,
  ) async {
    final repository = _FakeOrganizationManagementRepository(
      members: [
        _member(
          name: '示例负责人',
          email: 'owner@example.com',
          roles: ['org_owner'],
        ),
        _member(name: '示例老师', email: 'teacher@example.com', roles: ['teacher']),
      ],
      invitations: [_ownerNomination()],
      setupOptions: const OrganizationSetupOptions(
        subjects: [
          OrganizationSetupSubject(id: 'subject-1', displayName: '数学'),
        ],
        teachers: [
          OrganizationSetupTeacher(
            membershipId: 'membership-1',
            displayName: '示例老师',
            email: 'teacher@example.com',
            organizationSubjectIds: ['subject-1'],
          ),
        ],
      ),
    );
    await _pumpManagement(tester, repository);

    expect(find.text('机构管理'), findsOneWidget);
    expect(find.text('示例负责人'), findsOneWidget);
    expect(find.text('示例老师'), findsOneWidget);
    expect(find.text('待负责人审批'), findsAtLeastNWidgets(1));
    expect(find.text('通过负责人提名'), findsOneWidget);
    expect(find.text('问题类型'), findsNothing);

    await _selectManagementArea(tester, '设置');
    expect(find.text('问题类型'), findsOneWidget);
    expect(find.text('示例负责人'), findsNothing);
  });

  testWidgets(
    'owner can approve a nomination and admin cannot invite members',
    (tester) async {
      final repository = _FakeOrganizationManagementRepository(
        members: const [],
        invitations: [_ownerNomination()],
      );
      await _pumpManagement(tester, repository);

      final approveFinder = find.text('通过负责人提名');
      await tester.ensureVisible(approveFinder);
      await tester.tap(approveFinder);
      await tester.pumpAndSettle();
      expect(repository.approveCount, 1);

      final adminRepository = _FakeOrganizationManagementRepository(
        members: const [],
        invitations: const [],
      );
      await _pumpManagement(
        tester,
        adminRepository,
        roles: const ['org_admin'],
      );
      await _selectManagementArea(tester, '成员');

      expect(find.widgetWithText(FilledButton, '邀请成员'), findsNothing);
    },
  );

  testWidgets('admin can view members but cannot disable them', (tester) async {
    final repository = _FakeOrganizationManagementRepository(
      members: [
        _member(name: '示例老师', email: 'teacher@example.com', roles: ['teacher']),
      ],
      invitations: const [],
    );
    await _pumpManagement(tester, repository, roles: const ['org_admin']);
    await _selectManagementArea(tester, '成员');

    expect(find.text('示例老师'), findsOneWidget);
    final disableFinder = find.widgetWithText(TextButton, '停用成员');
    expect(disableFinder, findsOneWidget);
    expect(tester.widget<TextButton>(disableFinder).onPressed, isNull);
    expect(repository.memberStatusUpdateCount, 0);
  });

  testWidgets('admin can add a student with atomic setup fields', (
    tester,
  ) async {
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
    );
    await _pumpManagement(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, '添加学生'));
    await tester.pumpAndSettle();

    expect(find.text('学生姓名 *'), findsOneWidget);
    expect(find.text('服务学科 *'), findsOneWidget);
    expect(find.text('负责老师 *'), findsOneWidget);
    expect(find.text('学生编号'), findsNothing);
    expect(find.text('年级'), findsNothing);
    expect(find.text('学情背景（可选）'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, '新学生');
    await tester.tap(find.byKey(const Key('student-setup-submit')));
    await tester.pumpAndSettle();

    expect(repository.studentCreateCount, 1);
    expect(repository.createdStudent?.studentName, '新学生');
    expect(find.text('学生姓名 *'), findsNothing);
  });

  testWidgets(
    'adds a second subject without replacing the existing teacher relation',
    (tester) async {
      final repository = _FakeOrganizationManagementRepository(
        members: const [],
        invitations: const [],
        students: [_studentRecord()],
        studentTeacherAssignments: [_studentTeacherAssignment()],
        setupOptions: const OrganizationSetupOptions(
          subjects: [
            OrganizationSetupSubject(id: 'subject-1', displayName: '数学'),
            OrganizationSetupSubject(id: 'subject-2', displayName: '英语'),
          ],
          teachers: [
            OrganizationSetupTeacher(
              membershipId: 'membership-1',
              displayName: '原老师',
              email: 'old-teacher@example.com',
              organizationSubjectIds: ['subject-1', 'subject-2'],
            ),
          ],
        ),
      );
      await _pumpManagement(tester, repository);
      await _selectManagementArea(tester, '学生');

      final addSubject = find.widgetWithText(TextButton, '添加学科');
      await tester.ensureVisible(addSubject);
      await tester.tap(addSubject);
      await tester.pumpAndSettle();

      expect(find.text('为 原学生 添加学科'), findsOneWidget);
      expect(find.text('同一位老师可以负责同一学生的多门学科，只要该老师已配置相应可教学科。'), findsOneWidget);
      await tester.tap(find.byKey(const Key('student-subject-setup-submit')));
      await tester.pumpAndSettle();

      expect(repository.studentSubjectAddCount, 1);
      expect(
        repository.addedStudentSubject?.organizationSubjectId,
        'subject-2',
      );
      expect(
        repository.addedStudentSubject?.teacherMembershipId,
        'membership-1',
      );
      expect(
        repository.studentTeacherAssignments
            .where((item) => item.isActive)
            .length,
        2,
      );
      expect(
        repository.students.single.subjectNames,
        containsAll(['数学', '英语']),
      );
    },
  );

  testWidgets('ends one subject service without removing the student root', (
    tester,
  ) async {
    final student = _studentRecord();
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
      students: [student],
      studentTeacherAssignments: [_studentTeacherAssignment()],
    );
    await _pumpManagement(tester, repository);
    await _selectManagementArea(tester, '学生');

    final endButton = find.byKey(
      const ValueKey<String>('student-subject-end-profile-1'),
    );
    await tester.ensureVisible(endButton);
    await tester.tap(endButton);
    await tester.pumpAndSettle();

    expect(find.text('结束 原学生 · 数学？'), findsOneWidget);
    await tester.tap(find.text('确认结束'));
    await tester.pumpAndSettle();

    expect(repository.studentSubjectEndCount, 1);
    expect(repository.students.single.studentId, student.studentId);
    expect(
      repository.students.single.subjectServices.single.status,
      'inactive',
    );
    expect(find.text('已结束'), findsOneWidget);
  });

  testWidgets(
    'restores an ended subject by choosing a current eligible teacher',
    (tester) async {
      final student = OrganizationStudentRecord(
        studentId: 'student-1',
        studentName: '原学生',
        studentCode: 'S-001',
        status: 'active',
        version: 3,
        grade: '初二',
        className: '一班',
        campus: '本部',
        startsOn: DateTime(2026, 9, 1),
        endsOn: null,
        subjectNames: const [],
        subjectServices: const [
          OrganizationStudentSubjectService(
            profileId: 'profile-1',
            organizationSubjectId: 'subject-1',
            subjectName: '数学',
            status: 'inactive',
            version: 2,
          ),
        ],
      );
      final repository = _FakeOrganizationManagementRepository(
        members: const [],
        invitations: const [],
        students: [student],
        studentTeacherAssignments: <OrganizationStudentTeacherAssignment>[],
      );
      await _pumpManagement(tester, repository);
      await _selectManagementArea(tester, '学生');

      final restoreButton = find.byKey(
        const ValueKey<String>('student-subject-restore-profile-1'),
      );
      await tester.ensureVisible(restoreButton);
      await tester.tap(restoreButton);
      await tester.pumpAndSettle();

      expect(find.text('恢复 原学生 · 数学'), findsOneWidget);
      expect(find.text('主负责老师 *'), findsOneWidget);
      await tester.tap(find.byKey(const Key('student-subject-restore-submit')));
      await tester.pumpAndSettle();

      expect(repository.studentSubjectRestoreCount, 1);
      expect(
        repository.students.single.subjectServices.single.status,
        'active',
      );
      expect(repository.studentTeacherAssignments.single.isActive, isTrue);
      expect(find.text('进行中'), findsOneWidget);
    },
  );

  testWidgets('keeps optional student details behind one disclosure', (
    tester,
  ) async {
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
    );
    await _pumpManagement(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, '添加学生'));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('student-setup-optional-toggle'));
    expect(toggle, findsOneWidget);
    expect(find.text('学生编号'), findsNothing);
    expect(find.text('年级'), findsNothing);
    expect(find.text('班级'), findsNothing);
    expect(find.text('校区'), findsNothing);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text('学生编号'), findsOneWidget);
    expect(find.text('年级'), findsOneWidget);
    expect(find.text('班级'), findsOneWidget);
    expect(find.text('校区'), findsOneWidget);
    expect(find.text('学情背景（可选）'), findsOneWidget);
    final codeField = find.byKey(const Key('student-setup-code-field'));
    await tester.enterText(codeField, 'S-001');

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(codeField, findsNothing);
    expect(find.text('补充信息（可选）'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(codeField).controller?.text, 'S-001');
  });

  testWidgets('rapid taps open only one add flow at a time', (tester) async {
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
    );
    await _pumpManagement(tester, repository);

    final addStudent = find.widgetWithText(FilledButton, '添加学生');
    await tester.ensureVisible(addStudent);
    await tester.tap(addStudent);
    await tester.tap(addStudent);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('学生姓名 *'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await _selectManagementArea(tester, '设置');
    final addSubject = find.widgetWithText(TextButton, '添加学科');
    await tester.ensureVisible(addSubject);
    await tester.tap(addSubject);
    await tester.tap(addSubject);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('添加学科'), findsWidgets);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await _selectManagementArea(tester, '成员');
    final configureTeacherSubjects = find.widgetWithText(TextButton, '配置');
    await tester.ensureVisible(configureTeacherSubjects);
    await tester.tap(configureTeacherSubjects);
    await tester.tap(configureTeacherSubjects);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('保存配置'), findsOneWidget);
  });

  testWidgets(
    'manager pauses and resumes teaching without rewriting subject context',
    (tester) async {
      final repository = _FakeOrganizationManagementRepository(
        members: const [],
        invitations: const [],
        students: [_studentRecord()],
        studentTeacherAssignments: [_studentTeacherAssignment()],
      );
      await _pumpManagement(tester, repository);
      await _selectManagementArea(tester, '学生');

      final pause = find.byKey(
        const ValueKey<String>('student-teaching-toggle-student-1'),
      );
      await tester.ensureVisible(pause);
      expect(find.text('暂停教学'), findsOneWidget);
      await tester.tap(pause);
      await tester.pumpAndSettle();
      expect(find.text('暂停 原学生 的教学？'), findsOneWidget);
      expect(
        find.text(
          '暂停后，这位学生会暂时从老师工作台和今日事项中隐藏；学科档案、当前任课、Case、证据和待办都会原样保留，恢复后继续原来的教学上下文。',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, '确认暂停'));
      await tester.pumpAndSettle();

      expect(repository.studentTeachingPauseCount, 1);
      expect(repository.students.single.status, 'inactive');
      expect(repository.students.single.version, 4);
      expect(
        repository.students.single.subjectServices.single.status,
        'active',
      );
      expect(repository.studentTeacherAssignments.single.status, 'active');
      expect(find.text('暂不教学'), findsOneWidget);

      final resume = find.byKey(
        const ValueKey<String>('student-teaching-toggle-student-1'),
      );
      await tester.ensureVisible(resume);
      expect(find.text('恢复教学'), findsOneWidget);
      await tester.tap(resume);
      await tester.pumpAndSettle();
      expect(find.text('恢复 原学生 的教学？'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '确认恢复'));
      await tester.pumpAndSettle();

      expect(repository.studentTeachingResumeCount, 1);
      expect(repository.students.single.status, 'active');
      expect(repository.students.single.version, 5);
      expect(
        repository.students.single.subjectServices.single.status,
        'active',
      );
      expect(repository.studentTeacherAssignments.single.status, 'active');
      expect(find.text('正常教学'), findsOneWidget);
    },
  );

  testWidgets('admin edits student identity without changing lifecycle', (
    tester,
  ) async {
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
      students: [_studentRecord()],
    );
    await _pumpManagement(tester, repository);

    expect(find.text('原学生'), findsOneWidget);
    final editButton = find.text('编辑');
    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(find.text('编辑学生'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('教学可见状态 *'),
      ),
      findsNothing,
    );
    expect(
      find.text('这里只修改姓名和编号。暂停教学、恢复教学与归档属于独立操作，不会在普通编辑中顺带改变。'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField).first, '更新学生');
    await tester.tap(find.text('保存学生'));
    await tester.pumpAndSettle();

    expect(repository.studentUpdateCount, 1);
    expect(repository.updatedStudent?.studentName, '更新学生');
    expect(repository.updatedStudent?.status, 'active');
    expect(repository.updatedStudent?.version, 4);
    expect(find.text('编辑学生'), findsNothing);
  });

  testWidgets('admin can add an organization subject from the catalog', (
    tester,
  ) async {
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
    );
    await _pumpManagement(tester, repository);
    await _selectManagementArea(tester, '设置');

    final addSubject = find.widgetWithText(TextButton, '添加学科');
    await tester.ensureVisible(addSubject);
    await tester.tap(addSubject);
    await tester.pumpAndSettle();

    expect(
      find.text('选择机构要使用的学科。添加后，就可以为老师配置可教学科，并为学生安排对应老师。'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('subject-setup-submit')));
    await tester.pumpAndSettle();

    expect(repository.subjectCreateCount, 1);
    expect(find.text('从全局活跃学科目录中选择一个加入本机构。全局目录不会被修改。'), findsNothing);
  });

  testWidgets(
    'admin can configure, end, and re-enable a teacher subject scope',
    (tester) async {
      final repository = _FakeOrganizationManagementRepository(
        members: const [],
        invitations: const [],
        teacherSubjectScopes: <OrganizationTeacherSubjectScope>[],
      );
      await _pumpManagement(tester, repository);
      await _selectManagementArea(tester, '成员');

      final configureTeacherSubjects = find.widgetWithText(TextButton, '配置');
      await tester.ensureVisible(configureTeacherSubjects);
      await tester.tap(configureTeacherSubjects);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('配置老师可教学科'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('保存配置'));
      await tester.pumpAndSettle();

      expect(repository.teacherScopeUpdateCount, 1);
      expect(find.text('示例老师 · 数学'), findsOneWidget);
      final stop = find.text('停用该学科');
      await tester.ensureVisible(stop);
      await tester.tap(stop);
      await tester.pumpAndSettle();
      expect(find.text('停用这门可教学科？'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '确认停用'));
      await tester.pumpAndSettle();

      expect(repository.teacherScopeUpdateCount, 2);
      expect(repository.updatedTeacherScope?.status, 'ended');
      expect(find.text('重新启用'), findsNothing);
      await tester.tap(find.text('查看历史教学范围（1）'));
      await tester.pumpAndSettle();
      final restart = find.text('重新启用');
      await tester.ensureVisible(restart);
      await tester.tap(restart);
      await tester.pumpAndSettle();
      expect(find.text('重新启用这门可教学科？'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '重新启用'));
      await tester.pumpAndSettle();

      expect(repository.teacherScopeUpdateCount, 3);
      expect(repository.updatedTeacherScope?.status, 'active');
    },
  );

  testWidgets('admin can hand off a student teacher assignment', (
    tester,
  ) async {
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
      students: [_studentRecord()],
      studentTeacherAssignments: [_studentTeacherAssignment()],
      setupOptions: const OrganizationSetupOptions(
        subjects: [
          OrganizationSetupSubject(id: 'subject-1', displayName: '数学'),
        ],
        teachers: [
          OrganizationSetupTeacher(
            membershipId: 'membership-1',
            displayName: '原老师',
            email: 'old-teacher@example.com',
            organizationSubjectIds: ['subject-1'],
          ),
          OrganizationSetupTeacher(
            membershipId: 'membership-2',
            displayName: '新老师',
            email: 'new-teacher@example.com',
            organizationSubjectIds: ['subject-1'],
          ),
        ],
      ),
      teacherSubjectScopes: [
        OrganizationTeacherSubjectScope(
          scopeId: 'scope-1',
          membershipId: 'membership-1',
          organizationSubjectId: 'subject-1',
          teacherName: '原老师',
          teacherEmail: 'old-teacher@example.com',
          membershipStatus: 'active',
          subjectName: '数学',
          subjectCode: 'math',
          scopeKind: 'teaching',
          status: 'active',
          version: 1,
          activeFrom: DateTime(2026, 9, 1),
          activeTo: null,
        ),
        OrganizationTeacherSubjectScope(
          scopeId: 'scope-2',
          membershipId: 'membership-2',
          organizationSubjectId: 'subject-1',
          teacherName: '新老师',
          teacherEmail: 'new-teacher@example.com',
          membershipStatus: 'active',
          subjectName: '数学',
          subjectCode: 'math',
          scopeKind: 'teaching',
          status: 'active',
          version: 1,
          activeFrom: DateTime(2026, 9, 1),
          activeTo: null,
        ),
      ],
    );
    await _pumpManagement(tester, repository);

    expect(find.text('任课老师与交接'), findsOneWidget);
    expect(find.text('交接老师'), findsNothing);
    final assignmentSection = find.text('任课老师与交接');
    await tester.ensureVisible(assignmentSection);
    await tester.tap(assignmentSection);
    await tester.pumpAndSettle();

    final transferButton = find.text('交接老师');
    await tester.ensureVisible(transferButton);
    await tester.tap(transferButton);
    await tester.pumpAndSettle();

    expect(find.text('交接学生任课老师'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('原学生 · 数学'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('确认交接'));
    await tester.pumpAndSettle();

    expect(repository.assignmentTransferCount, 1);
    expect(repository.updatedTeacherAssignment?.status, 'transferred');
    expect(repository.updatedTeacherAssignment?.replacementTeacherName, '新老师');
    expect(find.text('主责老师：新老师 · new-teacher@example.com'), findsOneWidget);
  });

  testWidgets('missing subjects opens settings first', (tester) async {
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
      setupOptions: const OrganizationSetupOptions(subjects: [], teachers: []),
    );
    await _pumpManagement(tester, repository);

    expect(find.text('基础设置'), findsOneWidget);
    expect(find.text('添加学科'), findsOneWidget);
    expect(find.text('机构成员'), findsNothing);
  });

  testWidgets('missing teacher scope opens members first', (tester) async {
    final repository = _FakeOrganizationManagementRepository(
      members: [
        _member(name: '示例老师', email: 'teacher@example.com', roles: ['teacher']),
      ],
      invitations: const [],
      setupOptions: const OrganizationSetupOptions(
        subjects: [
          OrganizationSetupSubject(id: 'subject-1', displayName: '数学'),
        ],
        teachers: [
          OrganizationSetupTeacher(
            membershipId: 'membership-1',
            displayName: '示例老师',
            email: 'teacher@example.com',
            organizationSubjectIds: [],
          ),
        ],
      ),
    );
    await _pumpManagement(tester, repository);

    expect(find.text('机构成员'), findsOneWidget);
    expect(find.text('老师可教学科'), findsOneWidget);
    expect(find.text('基础设置'), findsNothing);
  });

  testWidgets('student list is bounded and searchable', (tester) async {
    final students = List<OrganizationStudentRecord>.generate(
      25,
      (index) => _studentRecord(
        id: 'student-${index + 1}',
        name: '学生${(index + 1).toString().padLeft(2, '0')}',
        code: 'S-${(index + 1).toString().padLeft(3, '0')}',
      ),
    );
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
      students: students,
    );
    await _pumpManagement(tester, repository);

    expect(find.byKey(const Key('management-student-search')), findsOneWidget);
    expect(find.text('学生20'), findsOneWidget);
    expect(find.text('学生21'), findsNothing);
    expect(find.text('查看全部 25 位学生'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('management-student-search')),
      '学生25',
    );
    await tester.pumpAndSettle();

    expect(find.text('学生25'), findsNWidgets(2));
    expect(find.text('学生01'), findsNothing);
    expect(find.text('1 个结果'), findsOneWidget);
  });
}
