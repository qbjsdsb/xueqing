import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/responsibility_read_repository.dart';

void main() {
  group('WorkspaceResponsibilityContext', () {
    test('parses personal assignments and responsibility maps', () {
      final context = WorkspaceResponsibilityContext.fromJson({
        'organization_id': 'org-a',
        'current_membership_id': 'member-a',
        'personal_assignments': [
          {
            'assignment_id': 'assignment-a',
            'profile_id': 'profile-a',
            'membership_id': 'member-a',
            'assignment_role': 'collaborator',
            'business_date': '2026-09-12',
          },
        ],
        'case_owners': [
          {'case_id': 'case-a', 'membership_id': 'member-lead'},
        ],
        'action_assignees': [
          {'action_id': 'action-mine', 'membership_id': 'member-a'},
          {'action_id': 'action-other', 'membership_id': 'member-lead'},
        ],
        'event_actors': [
          {'event_id': 'event-admin', 'membership_id': 'member-admin'},
        ],
        'profile_responsibilities': [
          {'profile_id': 'profile-a', 'lead_membership_id': 'member-lead'},
          {'profile_id': 'profile-no-lead', 'lead_membership_id': null},
        ],
        'member_display_names': [
          {'membership_id': 'member-a', 'display_name': '协作老师'},
          {'membership_id': 'member-lead', 'display_name': '主责老师'},
          {'membership_id': 'member-admin', 'display_name': '管理员'},
        ],
      });

      expect(context.organizationId, 'org-a');
      expect(context.currentMembershipId, 'member-a');
      expect(context.hasPersonalTeachingResponsibility, isTrue);
      expect(context.personalProfileIds, {'profile-a'});
      expect(context.isPersonalProfile('profile-a'), isTrue);
      expect(context.isPersonalProfile('profile-other'), isFalse);
      expect(context.personalAssignments.single.assignmentRole, 'collaborator');
      expect(
        context.personalAssignments.single.businessDate,
        DateTime(2026, 9, 12),
      );
      expect(context.caseOwnerMembershipIds['case-a'], 'member-lead');
      expect(context.isPersonalAction('action-mine'), isTrue);
      expect(context.isPersonalAction('action-other'), isFalse);
      expect(context.eventActorMembershipIds['event-admin'], 'member-admin');
      expect(context.leadMembershipIdForProfile('profile-a'), 'member-lead');
      expect(context.leadDisplayNameForProfile('profile-a'), '主责老师');
      expect(
        context.profileLeadMembershipIds.containsKey('profile-no-lead'),
        isTrue,
      );
      expect(context.leadMembershipIdForProfile('profile-no-lead'), isNull);
      expect(context.displayNameForMembership('member-lead'), '主责老师');
      expect(context.displayNameForMembership('missing'), isNull);
      expect(context.displayNameForMembership(null), isNull);
    });

    test('manager with zero assignments has no personal responsibility', () {
      final context = WorkspaceResponsibilityContext.fromJson({
        'organization_id': 'org-a',
        'current_membership_id': 'manager-a',
        'personal_assignments': <Object>[],
        'case_owners': [
          {'case_id': 'case-a', 'membership_id': 'teacher-a'},
        ],
        'action_assignees': [
          {'action_id': 'action-a', 'membership_id': 'teacher-a'},
        ],
        'event_actors': [
          {'event_id': 'event-a', 'membership_id': 'manager-a'},
        ],
        'member_display_names': [
          {'membership_id': 'manager-a', 'display_name': '管理员'},
          {'membership_id': 'teacher-a', 'display_name': '任课老师'},
        ],
      });

      expect(context.hasPersonalTeachingResponsibility, isFalse);
      expect(context.personalProfileIds, isEmpty);
      expect(context.profileLeadMembershipIds, isEmpty);
      expect(context.isPersonalAction('action-a'), isFalse);
      expect(context.caseOwnerMembershipIds['case-a'], 'teacher-a');
      expect(context.eventActorMembershipIds['event-a'], 'manager-a');
    });

    test('rejects duplicate responsibility keys', () {
      expect(
        () => WorkspaceResponsibilityContext.fromJson({
          'organization_id': 'org-a',
          'current_membership_id': 'member-a',
          'personal_assignments': <Object>[],
          'case_owners': [
            {'case_id': 'case-a', 'membership_id': 'member-a'},
            {'case_id': 'case-a', 'membership_id': 'member-b'},
          ],
          'action_assignees': <Object>[],
          'event_actors': <Object>[],
          'member_display_names': <Object>[],
        }),
        throwsFormatException,
      );
    });

    test('rejects duplicate Profile responsibility keys', () {
      expect(
        () => WorkspaceResponsibilityContext.fromJson({
          'organization_id': 'org-a',
          'current_membership_id': 'member-a',
          'personal_assignments': <Object>[],
          'case_owners': <Object>[],
          'action_assignees': <Object>[],
          'event_actors': <Object>[],
          'profile_responsibilities': [
            {'profile_id': 'profile-a', 'lead_membership_id': 'member-a'},
            {'profile_id': 'profile-a', 'lead_membership_id': null},
          ],
          'member_display_names': <Object>[],
        }),
        throwsFormatException,
      );
    });

    test('rejects malformed personal assignments', () {
      expect(
        () => WorkspaceResponsibilityContext.fromJson({
          'organization_id': 'org-a',
          'current_membership_id': 'member-a',
          'personal_assignments': [
            {
              'assignment_id': 'assignment-a',
              'profile_id': '',
              'membership_id': 'member-a',
              'assignment_role': 'lead',
              'business_date': '2026-09-12',
            },
          ],
          'case_owners': <Object>[],
          'action_assignees': <Object>[],
          'event_actors': <Object>[],
          'member_display_names': <Object>[],
        }),
        throwsFormatException,
      );
    });
  });
}
