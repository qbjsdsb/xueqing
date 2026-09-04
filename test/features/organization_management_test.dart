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
    this.setupOptions = const OrganizationSetupOptions(
      subjects: [OrganizationSetupSubject(id: 'subject-1', displayName: '数学')],
      teachers: [
        OrganizationSetupTeacher(
          membershipId: 'membership-1',
          displayName: '示例老师',
          email: 'teacher@example.com',
        ),
      ],
    ),
  });

  final List<OrganizationMember> members;
  final List<OrganizationInvitation> invitations;
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
  OrganizationStudentSetupResult? createdStudent;

  @override
  Future<List<OrganizationMember>> listMembers({
    required String organizationId,
  }) async {
    return members;
  }

  @override
  Future<List<OrganizationInvitation>> listInvitations({
    required String organizationId,
  }) async {
    return invitations;
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
      organizationSubjectId:
          'organization-subject-' + subjectCreateCount.toString(),
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
    expect(find.text('问题类型'), findsOneWidget);
  });

  testWidgets(
    'owner can approve a nomination and admin gets constrained roles',
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
      await tester.tap(find.text('邀请成员'));
      await tester.pumpAndSettle();

      expect(find.text('负责人'), findsAtLeastNWidgets(1));
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButtonFormField<OrganizationInvitationRole>,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('老师'), findsOneWidget);
      expect(find.text('管理员'), findsNothing);
    },
  );

  testWidgets('admin can add a student with atomic setup fields', (
    tester,
  ) async {
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
    );
    await _pumpManagement(tester, repository);

    await tester.tap(find.text('添加学生'));
    await tester.pumpAndSettle();

    expect(find.text('学生姓名 *'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '新学生');
    await tester.tap(find.text('保存并配置'));
    await tester.pumpAndSettle();

    expect(repository.studentCreateCount, 1);
    expect(repository.createdStudent?.studentName, '新学生');
    expect(find.text('学生姓名 *'), findsNothing);
  });

  testWidgets('admin can add an organization subject from the catalog', (
    tester,
  ) async {
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
    );
    await _pumpManagement(tester, repository);

    await tester.tap(find.text('添加学科'));
    await tester.pumpAndSettle();

    expect(find.text('从全局活跃学科目录中选择一个加入本机构。全局目录不会被修改。'), findsOneWidget);
    await tester.tap(find.text('保存学科'));
    await tester.pumpAndSettle();

    expect(repository.subjectCreateCount, 1);
    expect(find.text('从全局活跃学科目录中选择一个加入本机构。全局目录不会被修改。'), findsNothing);
    expect(find.text('已添加学科：英语。'), findsOneWidget);
  });
}
