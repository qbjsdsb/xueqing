import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/cloud/organization_management_repository.dart';
import 'package:xueqing/features/organization_management/presentation/'
    'organization_invitation_join_page.dart';

class _FakeInvitationAcceptanceRepository
    implements OrganizationInvitationAcceptanceRepository {
  String? inviteCode;
  String? displayName;
  Object? error;

  @override
  Future<void> acceptInvitation({
    required String inviteCode,
    String? displayName,
  }) async {
    this.inviteCode = inviteCode;
    this.displayName = displayName;
    final nextError = error;
    if (nextError != null) throw nextError;
  }
}

void main() {
  testWidgets(
    'no-membership account can accept an invite and refresh membership',
    (tester) async {
      final repository = _FakeInvitationAcceptanceRepository();
      var joined = 0;
      var signedOut = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: OrganizationInvitationJoinPage(
            repository: repository,
            email: 'teacher@example.com',
            onJoined: () async => joined++,
            onSignOut: () => signedOut++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('加入机构'), findsOneWidget);
      expect(find.textContaining('teacher@example.com'), findsOneWidget);
      expect(find.byKey(const Key('invitation-accept-code')), findsOneWidget);
      expect(find.byKey(const Key('invitation-join-sign-out')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('invitation-accept-code')),
        '0123456789abcdef01234567',
      );
      await tester.enterText(
        find.byKey(const Key('invitation-accept-display-name')),
        '王老师',
      );
      await tester.tap(find.text('接受邀请'));
      await tester.pumpAndSettle();

      expect(repository.inviteCode, '0123456789abcdef01234567');
      expect(repository.displayName, '王老师');
      expect(joined, 1);

      await tester.tap(find.byKey(const Key('invitation-join-sign-out')));
      expect(signedOut, 1);
    },
  );

  testWidgets('invite failure stays actionable and explains email mismatch', (
    tester,
  ) async {
    final repository = _FakeInvitationAcceptanceRepository()
      ..error = const AuthException('invitation_email_mismatch');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: OrganizationInvitationJoinPage(
          repository: repository,
          email: 'wrong@example.com',
          onJoined: () async {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('invitation-accept-code')),
      '0123456789abcdef01234567',
    );
    await tester.tap(find.text('接受邀请'));
    await tester.pumpAndSettle();

    expect(find.textContaining('接受邀请失败'), findsOneWidget);
    expect(find.byKey(const Key('invitation-accept-code')), findsOneWidget);
    expect(find.byKey(const Key('invitation-join-sign-out')), findsOneWidget);
  });
}
