import 'package:flutter/material.dart';

import '../../../app/layout/responsive.dart';
import '../../../app/router/app_router.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../config/app_config.dart';

class BootstrapPage extends StatelessWidget {
  const BootstrapPage({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '学情闭环',
      child: ResponsiveLayout(
        builder: (context, sizeClass) {
          final horizontalPadding = sizeClass == WindowSizeClass.compact
              ? AppSpacing.md
              : AppSpacing.xl;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.md,
              horizontalPadding,
              AppSpacing.xl,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '工程初始化完成',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '启动链路、平台目标与基础 UI 能力已经就绪。',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _StatusPanel(config: config),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.routeCheck);
                      },
                      icon: const Icon(Icons.route_outlined),
                      label: const Text('路由自检'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context)
                            .pushNamed(AppRoutes.designPreview);
                      },
                      icon: const Icon(Icons.design_services_outlined),
                      label: const Text('打开 UX/UI 设计预览'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '当前页面仅验证工程启动状态，不代表业务功能已经接入。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          const _StatusRow(label: '工程状态', value: 'Bootstrap ready'),
          const Divider(height: 1),
          _StatusRow(label: 'Environment', value: config.environmentLabel),
          const Divider(height: 1),
          const _StatusRow(label: '目标平台', value: 'Android / Windows'),
          const Divider(height: 1),
          const _StatusRow(label: '阶段', value: 'Phase 0A'),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
