import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../cloud/auth_repository.dart';
import '../../../cloud/organization_member_provisioning_repository.dart';

class MemberOnboardingPage extends StatefulWidget {
  const MemberOnboardingPage({
    required this.authRepository,
    required this.lifecycleRepository,
    required this.email,
    required this.onTransitionChanged,
    required this.onCompleted,
    this.displayName,
    this.expiresAt,
    super.key,
  });

  final AuthRepository authRepository;
  final OrganizationMemberLifecycleRepository lifecycleRepository;
  final String email;
  final String? displayName;
  final DateTime? expiresAt;
  final ValueChanged<bool> onTransitionChanged;
  final VoidCallback onCompleted;

  @override
  State<MemberOnboardingPage> createState() => _MemberOnboardingPageState();
}

class _MemberOnboardingPageState extends State<MemberOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _busy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    widget.onTransitionChanged(true);
    var completed = false;
    try {
      final password = _passwordController.text;
      await widget.authRepository.updatePassword(password: password);

      // Password changes can invalidate the current session. The explicit
      // global sign-out also closes any session created with the temporary
      // credential before the member signs in again.
      if (widget.authRepository.currentUser != null) {
        await widget.authRepository.signOut(global: true);
      }
      if (widget.authRepository.currentUser != null) {
        await widget.authRepository.signOut(global: false);
      }
      await widget.authRepository.signIn(
        email: widget.email,
        password: password,
      );
      await widget.lifecycleRepository.completeOnboarding();

      if (widget.authRepository.currentUser != null) {
        await widget.authRepository.signOut(global: true);
      }
      if (widget.authRepository.currentUser != null) {
        await widget.authRepository.signOut(global: false);
      }
      completed = true;
      widget.onCompleted();
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _describeError(error));
      }
    } finally {
      if (!completed) {
        widget.onTransitionChanged(false);
      }
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _describeError(Object error) {
    final provisioningError = organizationMemberProvisioningErrorMessage(error);
    if (provisioningError != null) {
      return provisioningError;
    }
    if (error is AuthException) {
      final message = error.message.trim();
      if (message.toLowerCase() == 'invalid login credentials') {
        return '重新登录失败，请确认新密码符合要求后重试。';
      }
      if (message.isNotEmpty) {
        return '接管未完成：$message';
      }
    }
    return '接管未完成。账号仍保持待接管状态，请检查网络后重试。';
  }

  String _formatExpiry(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    String pad(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${pad(local.month)}-${pad(local.day)} '
        '${pad(local.hour)}:${pad(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = widget.displayName;
    return Scaffold(
      appBar: AppBar(title: const Text('首次接管账号')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        displayName == null || displayName.isEmpty
                            ? '请完成账号接管'
                            : '$displayName，请完成账号接管',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '登录邮箱：${widget.email}\n接管有效期至：${_formatExpiry(widget.expiresAt)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '设置新密码后，系统会退出临时会话并要求你用新密码重新登录。完成前不能进入学生业务工作台。',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_busy,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '新密码',
                          helperText: '至少 12 位，建议包含大小写字母、数字和符号。',
                        ),
                        validator: (value) {
                          final password = value ?? '';
                          if (password.length < 12) {
                            return '新密码至少需要 12 位。';
                          }
                          if (!password.contains(RegExp(r'[A-Z]')) ||
                              !password.contains(RegExp(r'[a-z]')) ||
                              !password.contains(RegExp(r'[0-9]'))) {
                            return '请至少包含大写字母、小写字母和数字。';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _confirmationController,
                        enabled: !_busy,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(labelText: '确认新密码'),
                        validator: (value) => value != _passwordController.text
                            ? '两次输入的密码不一致。'
                            : null,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.lock_reset_outlined),
                          label: Text(_busy ? '正在完成接管…' : '设置新密码并完成接管'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
