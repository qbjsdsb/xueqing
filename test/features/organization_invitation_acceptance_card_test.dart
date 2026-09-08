import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/features/organization_management/presentation/'
    'organization_invitation_acceptance_card.dart';

void main() {
  testWidgets('accepts only a complete 24-character hex invitation code', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final inviteCodeController = TextEditingController();
    final displayNameController = TextEditingController();
    var acceptCount = 0;

    addTearDown(inviteCodeController.dispose);
    addTearDown(displayNameController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrganizationInvitationAcceptanceCard(
              formKey: formKey,
              inviteCodeController: inviteCodeController,
              displayNameController: displayNameController,
              busy: false,
              initiallyExpanded: true,
              onAccept: () => acceptCount++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('接受邀请'));
    await tester.pump();
    expect(find.text('邀请代码应为完整的 24 位。'), findsOneWidget);
    expect(acceptCount, 0);

    await tester.enterText(
      find.byKey(const Key('invitation-accept-code')),
      '0123456789abcdef',
    );
    await tester.tap(find.text('接受邀请'));
    await tester.pump();
    expect(find.text('邀请代码应为完整的 24 位。'), findsOneWidget);
    expect(acceptCount, 0);

    await tester.enterText(
      find.byKey(const Key('invitation-accept-code')),
      '0123456789abcdef0123456g',
    );
    await tester.tap(find.text('接受邀请'));
    await tester.pump();
    expect(find.text('邀请代码格式不正确，请重新粘贴。'), findsOneWidget);
    expect(acceptCount, 0);

    await tester.enterText(
      find.byKey(const Key('invitation-accept-code')),
      '0123456789abcdef01234567',
    );
    await tester.tap(find.text('接受邀请'));
    expect(acceptCount, 1);
  });
}
