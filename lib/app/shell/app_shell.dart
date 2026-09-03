import 'package:flutter/material.dart';

import '../layout/responsive.dart';
import '../theme/app_spacing.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      builder: (context, sizeClass) {
        if (sizeClass == WindowSizeClass.expanded) {
          return Scaffold(
            body: Row(
              children: [
                const _DesktopRail(),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _ShellContent(title: title, child: child),
                ),
              ],
            ),
          );
        }

        if (sizeClass == WindowSizeClass.medium) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  const _CompactRail(),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _ShellContent(title: title, child: child),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(child: child),
        );
      },
    );
  }
}

class _CompactRail extends StatelessWidget {
  const _CompactRail();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            Tooltip(
              message: '开发验证状态',
              child: Icon(
                Icons.build_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Spacer(),
            Text(
              '开发验证',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellContent extends StatelessWidget {
  const _ShellContent({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 224,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('学情闭环', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text('教师工作台', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.build_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('开发验证状态'),
                ],
              ),
              const Spacer(),
              Text('开发验证', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
