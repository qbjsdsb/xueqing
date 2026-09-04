import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xueqing/cloud/organization_management_repository.dart';

void main() {
  test('parses member roles and invitation metadata', () {
    final member = OrganizationMember.fromJson({
      'app_user_id': 'app-user-1',
      'membership_id': 'membership-1',
      'email': 'teacher@example.com',
      'display_name': '示例老师',
      'status': 'active',
      'roles': ['teacher', 'org_admin'],
    });
    final invitation = OrganizationInvitation.fromJson({
      'id': 'invitation-1',
      'email': 'owner@example.com',
      'role': 'org_owner',
      'status': 'pending_owner_approval',
      'expires_at': '2026-09-11T00:00:00.000Z',
      'created_at': '2026-09-04T00:00:00.000Z',
      'invited_by_name': '示例管理员',
      'invite_code': '0123456789abcdef',
    });

    expect(member.isActive, isTrue);
    expect(member.roles, ['teacher', 'org_admin']);
    expect(member.displayName, '示例老师');
    expect(invitation.role, OrganizationInvitationRole.owner);
    expect(invitation.isAwaitingOwnerApproval, isTrue);
    expect(invitation.inviteCode, '0123456789abcdef');
    expect(invitation.expiresAt, isNotNull);
  });

  test(
    'rejects an unknown invitation role instead of silently changing it',
    () {
      expect(
        () => OrganizationInvitation.fromJson({
          'id': 'invitation-1',
          'email': 'unknown@example.com',
          'role': 'unknown_role',
          'status': 'pending',
        }),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('maps invitation authorization errors to actionable copy', () {
    expect(
      organizationInvitationErrorMessage(
        const AuthException('invitation_email_mismatch'),
      ),
      '当前登录邮箱与邀请邮箱不一致。',
    );
    expect(
      organizationInvitationErrorMessage(
        PostgrestException(
          message: 'organization_manager_required',
          code: 'P0001',
          details: '',
          hint: '',
        ),
      ),
      '当前账号没有本机构管理权限。',
    );
    expect(
      organizationInvitationErrorMessage(const FormatException('other')),
      isNull,
    );
  });

  test('parses and filters effective teacher subject setup options', () {
    final options = OrganizationSetupOptions.fromJson({
      'subjects': [
        {'id': 'subject-1', 'display_name': '数学'},
        {'id': 'subject-2', 'display_name': '英语'},
      ],
      'teachers': [
        {
          'membership_id': 'teacher-1',
          'display_name': '数学老师',
          'email': 'math@example.com',
          'organization_subject_ids': ['subject-1'],
        },
        {
          'membership_id': 'teacher-2',
          'display_name': '待配置老师',
          'email': 'pending@example.com',
          'organization_subject_ids': <String>[],
        },
      ],
    });

    expect(options.canCreateStudent, isTrue);
    expect(
      options.subjectsWithAvailableTeachers.map((subject) => subject.id),
      ['subject-1'],
    );
    expect(
      options.teachersForSubject('subject-1').single.membershipId,
      'teacher-1',
    );
    expect(options.teachersForSubject('subject-2'), isEmpty);
  });

  test('maps missing teaching scope to an actionable student setup error', () {
    expect(
      organizationStudentSetupErrorMessage(
        const AuthException('teacher_subject_scope_required'),
      ),
      '所选老师没有该学科的有效教学范围，请先配置教学范围。',
    );
  });

  test('parses teacher subject scope history and command results', () {
    final scope = OrganizationTeacherSubjectScope.fromJson({
      'scope_id': 'scope-1',
      'membership_id': 'membership-1',
      'organization_subject_id': 'organization-subject-1',
      'teacher_name': '示例老师',
      'teacher_email': 'teacher@example.com',
      'membership_status': 'active',
      'subject_name': '数学',
      'subject_code': 'math',
      'scope_kind': 'teaching',
      'status': 'ended',
      'version': 2,
      'active_from': '2026-09-01',
      'active_to': '2026-09-04',
    });
    final result = OrganizationTeacherSubjectScopeUpdateResult.fromJson({
      'operation_id': 'operation-1',
      'organization_id': 'org-1',
      'membership_id': 'membership-1',
      'organization_subject_id': 'organization-subject-1',
      'scope_id': 'scope-1',
      'status': 'ended',
      'version': 2,
      'active_from': '2026-09-01',
      'active_to': '2026-09-04',
    });

    expect(scope.isEnded, isTrue);
    expect(scope.version, 2);
    expect(scope.activeTo, isNotNull);
    expect(result.status, 'ended');
    expect(result.scopeId, 'scope-1');
  });

  test('maps teacher scope handoff and concurrency errors', () {
    expect(
      organizationTeacherSubjectScopeErrorMessage(
        PostgrestException(
          message: 'teacher_scope_handoff_required',
          code: 'P0001',
          details: '',
          hint: '',
        ),
      ),
      '仍有学生任课、开放案件或待办行动未交接，请先完成交接。',
    );
    expect(
      organizationTeacherSubjectScopeErrorMessage(
        const AuthException('teacher_subject_scope_version_conflict'),
      ),
      '这条教学范围刚刚被别人修改，请刷新后重试。',
    );
  });
}
