import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/shell/app_shell.dart';
import '../../../config/app_config.dart';
import '../../../cloud/auth_repository.dart';
import '../../../cloud/cloud_client.dart';
import '../../../cloud/cloud_models.dart';
import '../../../cloud/session_request_guard.dart';
import '../../../cloud/student_repository.dart';

class CloudConnectionPage extends StatefulWidget {
  const CloudConnectionPage({
    required this.config,
    this.authRepository,
    this.studentRepository,
    super.key,
  });

  final AppConfig config;
  final AuthRepository? authRepository;
  final StudentRepository? studentRepository;

  @override
  State<CloudConnectionPage> createState() => _CloudConnectionPageState();
}

class _CloudConnectionPageState extends State<CloudConnectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contextRequestGuard = SessionRequestGuard();

  late final Future<void> _initialization;
  StreamSubscription<AuthState>? _authSubscription;

  AuthRepository? _authRepository;
  StudentRepository? _studentRepository;
  CloudUserContext? _userContext;
  String? _errorMessage;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  @override
  void dispose() {
    _contextRequestGuard.invalidate();
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final hasAuthRepository = widget.authRepository != null;
    final hasStudentRepository = widget.studentRepository != null;
    if (hasAuthRepository != hasStudentRepository) {
      throw ArgumentError(
        'authRepository and studentRepository must be supplied together.',
      );
    }

    if (hasAuthRepository && hasStudentRepository) {
      _authRepository = widget.authRepository;
      _studentRepository = widget.studentRepository;
    } else {
      widget.config.cloudConfig.validate();
      if (!widget.config.cloudConfig.isConfigured) {
        return;
      }

      await CloudClient.initialize(widget.config.cloudConfig);
      _authRepository = SupabaseAuthRepository(CloudClient.client);
      _studentRepository = SupabaseStudentRepository(CloudClient.client);
    }

    _authSubscription = _authRepository!.authStateChanges.listen((authState) {
      if (!mounted) {
        return;
      }
      if (authState.session == null) {
        _contextRequestGuard.invalidate();
        setState(() {
          _userContext = null;
          _errorMessage = null;
        });
      } else {
        unawaited(_loadUserContext());
      }
    });

    await _loadUserContext();
  }

  Future<void> _loadUserContext() async {
    final requestGeneration = _contextRequestGuard.begin();
    final authRepository = _authRepository;
    final studentRepository = _studentRepository;
    final authUser = authRepository?.currentUser;
    if (authRepository == null ||
        studentRepository == null ||
        authUser == null) {
      if (mounted &&
          requestGeneration == _contextRequestGuard.begin() - 1) {
        setState(() {
          _userContext = null;
        });
      }
      return;
    }

    final expectedUserId = authUser.id;
    try {
      final userContext = await studentRepository.loadContext();
      if (!mounted ||
          !_contextRequestGuard.isCurrent(
            requestGeneration,
            expectedUserId: expectedUserId,
            currentUserId: authRepository.currentUser?.id,
          )) {
        return;
      }

      setState(() {
        _userContext = userContext;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted ||
          !_contextRequestGuard.isCurrent(
            requestGeneration,
            expectedUserId: expectedUserId,
            currentUserId: authRepository.currentUser?.id,
          )) {
        return;
      }

      setState(() {
        _userContext = null;
        _errorMessage = _describeError(error, action: '读取账号资料');
      });
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authRepository = _authRepository;
    if (authRepository == null) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    _contextRequestGuard.invalidate();
    setState(() {
      _busy = true;
      _userContext = null;
      _errorMessage = null;
    });

    try {
      await authRepository.signIn(email: email, password: password);
      await _loadUserContext();
      _passwordController.clear();
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _describeError(error, action: '登录');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final authRepository = _authRepository;
    if (authRepository == null) {
      return;
    }

    final previousContext = _userContext;
    _contextRequestGuard.invalidate();
    setState(() {
      _busy = true;
      _userContext = null;
      _errorMessage = null;
    });

    String? signOutWarning;
    try {
      try {
        await authRepository.signOut();
      } catch (globalError) {
        try {
          // A network failure must not leave the user trapped behind a stale
          // local session. The warning below records that global revocation
          // still needs a successful online attempt.
          await authRepository.signOut(global: false);
          signOutWarning = '已退出本机登录，但云端全局退出未完成。'
              '请在网络正常时再次登录并退出一次。';
        } catch (localError) {
          if (mounted) {
            setState(() {
              _userContext = previousContext;
              _errorMessage = _describeError(localError, action: '退出登录');
            });
          }
          return;
        }
      }

      _contextRequestGuard.invalidate();
      _passwordController.clear();
      if (mounted) {
        setState(() {
          _userContext = null;
          _errorMessage = signOutWarning;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _describeError(Object error, {required String action}) {
    if (error is AuthException) {
      final detail = error.message.trim();
      if (detail.isEmpty) {
        return '$action失败，请检查网络后重试。';
      }

      final normalized = detail.toLowerCase();
      if (normalized == 'invalid login credentials') {
        return '$action失败：账号或密码不正确。';
      }
      if (normalized.contains('network') ||
          normalized.contains('socket') ||
          normalized.contains('timeout')) {
        return '$action失败：网络连接异常，请检查网络后重试。';
      }
      return '$action失败：$detail';
    }

    return '$action失败：$error';
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Cloud Spike',
      child: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessagePanel(
              title: 'Cloud 初始化失败',
              message: snapshot.error.toString(),
            );
          }
          if (_authRepository == null) {
            return _MessagePanel(
              title: 'Cloud Spike 未配置',
              message:
                  '请用 XUEQING_SUPABASE_URL 和 '
                  'XUEQING_SUPABASE_PUBLISHABLE_KEY 启动开发环境。',
            );
          }

          return _buildAuthenticatedBody();
        },
      ),
    );
  }

  Widget _buildAuthenticatedBody() {
    final user = _authRepository!.currentUser;
    if (user == null) {
      return _buildLoginForm();
    }

    return _buildSummary(user);
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cloud Connection Test',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '验证 Flutter → Auth → Database → RLS 链路。仅使用开发环境虚构账号。',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入开发环境账号';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入开发环境密码';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: const Text('登录开发环境'),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _ErrorText(message: _errorMessage!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(User user) {
    final userContext = _userContext;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cloud Connection Test',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '当前会话通过 RLS 读取到的最小上下文。',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              _SummaryPanel(
                rows: [
                  _SummaryRow(
                    label: 'User',
                    value: userContext?.userDisplayName ?? user.email ?? '—',
                  ),
                  _SummaryRow(
                    label: 'Organization',
                    value: userContext?.organizationName ?? '—',
                  ),
                  _SummaryRow(label: 'Role', value: userContext?.role ?? '—'),
                  _SummaryRow(
                    label: 'Accessible Student Count',
                    value: (userContext?.accessibleStudentCount ?? 0)
                        .toString(),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _ErrorText(message: _errorMessage!),
              ],
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _busy ? null : _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('退出并切换账号'),
              ),
              const SizedBox(height: 8),
              Text(
                '退出后可以登录另一位教师；网络异常时也会先清理本机登录状态。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(message, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.rows});

  final List<_SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[index].label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    rows[index].value,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (index < rows.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
