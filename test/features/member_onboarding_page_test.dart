import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/cloud/auth_repository.dart';
import 'package:xueqing/cloud/organization_member_provisioning_repository.dart';
import 'package:xueqing/features/teacher_workspace/presentation/'
    'member_onboarding_page.dart';

class _FakeAuthRepository implements AuthRepository {
  int updatePasswordCount = 0;
  int signInCount = 0;
  String? updatedPassword;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCount++;
  }

  @override
  Future<void> signOut({bool global = true}) async {}

  @override
  Future<void> updatePassword({required String password}) async {
    updatePasswordCount++;
    updatedPassword = password;
  }
}

class _FakeLifecycleRepository
    implements OrganizationMemberLifecycleRepository {
  int completeCount = 0;

  @override
  Future<OrganizationMembershipState> completeOnboarding() async {
    completeCount++;
    return const OrganizationMembershipState(
      status: 'active',
      appUserId: 'user-1',
    );
  }

  @override
  Future<OrganizationMembershipState> loadCurrentMembershipState() async {
    return const OrganizationMembershipState(
      status: 'onboarding',
      appUserId: 'user-1',
    );
  }
}

bool _isObscured(WidgetTester tester, Finder field) {
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  return tester.widget<EditableText>(editable).obscureText;
}

void main() {
  testWidgets('lets the member reveal each password field independently', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    final lifecycleRepository = _FakeLifecycleRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MemberOnboardingPage(
          authRepository: authRepository,
          lifecycleRepository: lifecycleRepository,
          email: 'teacher@example.com',
          displayName: '王老师',
          expiresAt: DateTime(2026, 9, 9, 12),
          onTransitionChanged: (_) {},
          onCompleted: () {},
        ),
      ),
    );

    final passwordField = find.byKey(const Key('onboarding-new-password'));
    final confirmationField = find.byKey(
      const Key('onboarding-confirm-password'),
    );

    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(
      tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
    expect(_isObscured(tester, passwordField), isTrue);
    expect(_isObscured(tester, confirmationField), isTrue);

    await tester.tap(
      find.byKey(const Key('onboarding-new-password-visibility')),
    );
    await tester.pump();
    expect(_isObscured(tester, passwordField), isFalse);
    expect(_isObscured(tester, confirmationField), isTrue);

    await tester.tap(
      find.byKey(const Key('onboarding-confirm-password-visibility')),
    );
    await tester.pump();
    expect(_isObscured(tester, confirmationField), isFalse);
  });

  testWidgets(
    'blocks weak passwords and completes onboarding with a valid one',
    (tester) async {
      final authRepository = _FakeAuthRepository();
      final lifecycleRepository = _FakeLifecycleRepository();
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MemberOnboardingPage(
            authRepository: authRepository,
            lifecycleRepository: lifecycleRepository,
            email: 'teacher@example.com',
            onTransitionChanged: (_) {},
            onCompleted: () => completed = true,
          ),
        ),
      );

      final submit = find.byKey(const Key('onboarding-submit'));
      await tester.enterText(
        find.byKey(const Key('onboarding-new-password')),
        'short',
      );
      await tester.enterText(
        find.byKey(const Key('onboarding-confirm-password')),
        'short',
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      expect(find.text('新密码至少需要 12 位。'), findsOneWidget);
      expect(authRepository.updatePasswordCount, 0);
      expect(lifecycleRepository.completeCount, 0);

      const strongPassword = 'StrongPassword1';
      await tester.enterText(
        find.byKey(const Key('onboarding-new-password')),
        strongPassword,
      );
      await tester.enterText(
        find.byKey(const Key('onboarding-confirm-password')),
        strongPassword,
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(authRepository.updatePasswordCount, 1);
      expect(authRepository.updatedPassword, strongPassword);
      expect(authRepository.signInCount, 1);
      expect(lifecycleRepository.completeCount, 1);
      expect(completed, isTrue);
    },
  );
}
