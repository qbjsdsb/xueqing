import 'package:flutter/material.dart';

import '../../../app/layout/responsive.dart';
import '../../../app/router/app_router.dart';
import '../../../app/shell/app_shell.dart';
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
                      '教师工作台',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '从学生当前重点开始，把问题、证据和下一步放在同一条工作线上。',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _StatusPanel(config: config),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.teacherWorkspace);
                      },
                      icon: const Icon(Icons.people_alt_outlined),
                      label: const Text('进入教师工作台'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.designPreview);
                      },
                      icon: const Icon(Icons.design_services_outlined),
                      label: const Text('打开虚构数据预览'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.cloudSpike);
                      },
                      icon: const Icon(Icons.cloud_outlined),
                      label: const Text('打开云端连接测试'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.routeCheck);
                      },
                      icon: const Icon(Icons.route_outlined),
                      label: const Text('路由自检'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '当前只连接开发环境虚构资料；正式 provider、真实学生数据和生产配置尚未启用。',
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
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Column(
        children: [
          const _StatusRow(label: '当前状态', value: '开发验证'),
          const Divider(height: 1),
          _StatusRow(label: '运行环境', value: config.environmentLabel),
          const Divider(height: 1),
          const _StatusRow(label: '目标平台', value: 'Android / Windows'),
          const Divider(height: 1),
          const _StatusRow(label: '工作范围', value: '0B.0-D 数据接入验证'),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
