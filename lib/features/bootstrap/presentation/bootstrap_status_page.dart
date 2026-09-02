import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/error/app_failure.dart';

enum BootstrapStatus {
  loading,
  failure,
}

class BootstrapStatusApp extends StatelessWidget {
  const BootstrapStatusApp({
    required this.state,
    this.failure,
    this.onRetry,
    super.key,
  });

  final BootstrapStatus state;
  final AppFailure? failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学情闭环',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: BootstrapStatusPage(
        state: state,
        failure: failure,
        onRetry: onRetry,
      ),
    );
  }
}

class BootstrapStatusPage extends StatelessWidget {
  const BootstrapStatusPage({
    required this.state,
    this.failure,
    this.onRetry,
    super.key,
  });

  final BootstrapStatus state;
  final AppFailure? failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isLoading = state == BootstrapStatus.loading;
    final currentFailure = failure ?? const AppFailure.bootstrap();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const CircularProgressIndicator()
                  else
                    const Icon(Icons.error_outline, size: 32),
                  const SizedBox(height: 16),
                  Text(
                    isLoading ? '正在加载工程配置' : currentFailure.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLoading ? '请稍候。' : currentFailure.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (!isLoading && onRetry != null) ...[
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('重试'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
