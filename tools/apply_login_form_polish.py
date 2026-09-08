from pathlib import Path

product = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
text = product.read_text(encoding='utf-8')

old_email = """                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: '邮箱'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '请输入邮箱'
                          : null,
                    ),
"""
new_email = """                    TextFormField(
                      key: const Key('workspace-login-email'),
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(labelText: '邮箱'),
                      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '请输入邮箱'
                          : null,
                    ),
"""
if text.count(old_email) != 1:
    raise SystemExit(f'Expected one login email field, found {text.count(old_email)}')
text = text.replace(old_email, new_email, 1)

old_password = """                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '密码'),
                      validator: (value) =>
                          value == null || value.isEmpty ? '请输入密码' : null,
                    ),
"""
new_password = """                    _WorkspacePasswordField(
                      controller: passwordController,
                      busy: busy,
                      onSubmit: onSubmit,
                    ),
"""
if text.count(old_password) != 1:
    raise SystemExit(f'Expected one login password field, found {text.count(old_password)}')
text = text.replace(old_password, new_password, 1)

marker = "class _WorkspaceLoginBody extends StatelessWidget {\n"
marker_index = text.find(marker)
if marker_index < 0:
    raise SystemExit('Workspace login body not found')
next_class_index = text.find('\nclass ', marker_index + len(marker))
if next_class_index < 0:
    raise SystemExit('Could not locate class after WorkspaceLoginBody')

helper = """

class _WorkspacePasswordField extends StatefulWidget {
  const _WorkspacePasswordField({
    required this.controller,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  State<_WorkspacePasswordField> createState() =>
      _WorkspacePasswordFieldState();
}

class _WorkspacePasswordFieldState extends State<_WorkspacePasswordField> {
  bool _passwordVisible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const Key('workspace-login-password'),
      controller: widget.controller,
      obscureText: !_passwordVisible,
      enabled: !widget.busy,
      autofillHints: const <String>[AutofillHints.password],
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: '密码',
        suffixIcon: IconButton(
          key: const Key('workspace-login-password-visibility'),
          tooltip: _passwordVisible ? '隐藏密码' : '显示密码',
          onPressed: widget.busy
              ? null
              : () => setState(() => _passwordVisible = !_passwordVisible),
          icon: Icon(
            _passwordVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
      onFieldSubmitted: widget.busy ? null : (_) => widget.onSubmit(),
      validator: (value) => value == null || value.isEmpty ? '请输入密码' : null,
    );
  }
}
"""
text = text[:next_class_index] + helper + text[next_class_index:]
product.write_text(text, encoding='utf-8')

test_path = Path('test/features/teacher_workspace_test.dart')
tests = test_path.read_text(encoding='utf-8')

imports_old = """import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/cloud/case_reopen_draft_store.dart';
"""
imports_new = """import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/cloud/auth_repository.dart';
import 'package:xueqing/cloud/case_reopen_draft_store.dart';
"""
if tests.count(imports_old) != 1:
    raise SystemExit('Teacher workspace test import anchor changed')
tests = tests.replace(imports_old, imports_new, 1)

config_anchor = "import 'package:xueqing/cloud/learning_repository.dart';\n"
config_insert = config_anchor + "import 'package:xueqing/config/app_config.dart';\n"
if tests.count(config_anchor) != 1:
    raise SystemExit('Learning repository import anchor changed')
tests = tests.replace(config_anchor, config_insert, 1)

fake_anchor = "class _FakeLearningRepository implements LearningRepository {\n"
fake_auth = """class _FakeLoginAuthRepository implements AuthRepository {
  int signInCount = 0;
  String? lastEmail;
  String? lastPassword;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCount++;
    lastEmail = email;
    lastPassword = password;
  }

  @override
  Future<void> signOut({bool global = true}) async {}

  @override
  Future<void> updatePassword({required String password}) async {}
}

bool _isLoginPasswordObscured(WidgetTester tester) {
  final editable = find.descendant(
    of: find.byKey(const Key('workspace-login-password')),
    matching: find.byType(EditableText),
  );
  return tester.widget<EditableText>(editable).obscureText;
}

"""
if tests.count(fake_anchor) != 1:
    raise SystemExit('Fake learning repository anchor changed')
tests = tests.replace(fake_anchor, fake_auth + fake_anchor, 1)

main_anchor = "void main() {\n"
login_tests = """void main() {
  testWidgets('login form supports reveal, next, and done keyboard flow', (tester) async {
    final authRepository = _FakeLoginAuthRepository();
    final learningRepository = _FakeLearningRepository(_fixtureWorkspace());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TeacherWorkspaceEntryPage(
          config: AppConfig.fromValues(
            environmentValue: 'development',
            appVersion: '0.2.0+2',
          ),
          authRepository: authRepository,
          learningRepository: learningRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final emailField = find.byKey(const Key('workspace-login-email'));
    final passwordField = find.byKey(const Key('workspace-login-password'));
    expect(emailField, findsOneWidget);
    expect(passwordField, findsOneWidget);
    expect(_isLoginPasswordObscured(tester), isTrue);

    final emailWidget = tester.widget<TextFormField>(emailField);
    expect(emailWidget.textInputAction, TextInputAction.next);
    expect(emailWidget.autofillHints, contains(AutofillHints.email));

    await tester.tap(emailField);
    await tester.enterText(emailField, 'teacher@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester.widget<EditableText>(
        find.descendant(of: passwordField, matching: find.byType(EditableText)),
      ).focusNode.hasFocus,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('workspace-login-password-visibility')));
    await tester.pump();
    expect(_isLoginPasswordObscured(tester), isFalse);

    await tester.enterText(passwordField, 'example-password');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(authRepository.signInCount, 1);
    expect(authRepository.lastEmail, 'teacher@example.com');
    expect(authRepository.lastPassword, 'example-password');
  });

"""
if tests.count(main_anchor) != 1:
    raise SystemExit(f'Expected one main anchor, found {tests.count(main_anchor)}')
tests = tests.replace(main_anchor, login_tests, 1)
test_path.write_text(tests, encoding='utf-8')
