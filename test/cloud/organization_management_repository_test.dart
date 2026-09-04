import 'package:flutter_test/flutter_test.dart';
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
}
