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
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
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
        return '首次登录设置未完成：$message';
      }
    }
    return '首次登录设置未完成。账号仍保持待设置状态，请检查网络后重试。';
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
    final displayName = widget.displayName?.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('首次登录设置')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
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
                            ? '请完成首次登录设置'
                            : '$displayName，请完成首次登录设置',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '这是第一次使用这个机构账号。设置自己的新密码后，临时密码会失效。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _OnboardingInfoLine(
                              icon: Icons.alternate_email,
                              label: '登录邮箱',
                              value: widget.email,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            _OnboardingInfoLine(
                              icon: Icons.schedule_outlined,
                              label: '临时密码有效期',
                              value: _formatExpiry(widget.expiresAt),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '设置完成后会回到登录页，邮箱会保留；直接输入新密码重新登录。',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        key: const Key('onboarding-new-password'),
                        controller: _passwordController,
                        enabled: !_busy,
                        obscureText: _obscurePassword,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: '新密码 *',
                          helperText: '至少 12 位，并包含大写字母、小写字母和数字。',
                          suffixIcon: IconButton(
                            key: const Key(
                              'onboarding-new-password-visibility',
                            ),
                            tooltip: _obscurePassword ? '显示新密码' : '隐藏新密码',
                            onPressed: _busy
                                ? null
                                : () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
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
                        key: const Key('onboarding-confirm-password'),
                        controller: _confirmationController,
                        enabled: !_busy,
                        obscureText: _obscureConfirmation,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: '再次输入新密码 *',
                          suffixIcon: IconButton(
                            key: const Key(
                              'onboarding-confirm-password-visibility',
                            ),
                            tooltip: _obscureConfirmation ? '显示确认密码' : '隐藏确认密码',
                            onPressed: _busy
                                ? null
                                : () => setState(
                                    () => _obscureConfirmation =
                                        !_obscureConfirmation,
                                  ),
                            icon: Icon(
                              _obscureConfirmation
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
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
                          key: const Key('onboarding-submit'),
                          onPressed: _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.lock_reset_outlined),
                          label: Text(_busy ? '正在完成设置…' : '设置新密码并继续'),
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

class _OnboardingInfoLine extends StatelessWidget {
  const _OnboardingInfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
