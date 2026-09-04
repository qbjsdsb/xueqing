import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/features/organization_management/presentation/'
    'organization_invitation_acceptance_card.dart';

void main() {
  testWidgets('validates and submits a complete invitation code', (
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
    expect(find.text('请输入完整的邀请代码。'), findsOneWidget);
    expect(acceptCount, 0);

    await tester.enterText(
      find.byType(TextFormField).first,
      '0123456789abcdef01234567',
    );
    await tester.tap(find.text('接受邀请'));
    expect(acceptCount, 1);
  });
}
