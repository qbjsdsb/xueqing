part of 'organization_management_page.dart';

class _ManagementHeader extends StatelessWidget {
  const _ManagementHeader({
    required this.organizationName,
    required this.roleLabel,
    required this.refreshing,
    required this.onRefresh,
    required this.showTitle,
  });

  final String organizationName;
  final String roleLabel;
  final bool refreshing;
  final VoidCallback? onRefresh;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final identity = Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          organizationName,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            roleLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
    final refreshButton = IconButton(
      key: const Key('management-refresh'),
      tooltip: refreshing ? '正在刷新' : '刷新机构数据',
      onPressed: refreshing ? null : onRefresh,
      icon: refreshing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_outlined),
    );

    if (!showTitle) {
      return Row(
        children: [
          Expanded(child: identity),
          const SizedBox(width: AppSpacing.xs),
          refreshButton,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '机构管理',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            refreshButton,
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        identity,
      ],
    );
  }
}

class _ManagementAreaSwitcher extends StatelessWidget {
  const _ManagementAreaSwitcher({
    required this.selectedArea,
    required this.onChanged,
  });

  final _ManagementArea selectedArea;
  final ValueChanged<_ManagementArea> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _ManagementAreaChoiceChip(
                area: _ManagementArea.people,
                icon: Icons.people_outline,
                label: '成员',
                labelKey: const Key('management-area-people'),
                selectedArea: selectedArea,
                onChanged: onChanged,
              ),
              _ManagementAreaChoiceChip(
                area: _ManagementArea.students,
                icon: Icons.school_outlined,
                label: '学生',
                labelKey: const Key('management-area-students'),
                selectedArea: selectedArea,
                onChanged: onChanged,
              ),
              _ManagementAreaChoiceChip(
                area: _ManagementArea.settings,
                icon: Icons.tune_outlined,
                label: '设置',
                labelKey: const Key('management-area-settings'),
                selectedArea: selectedArea,
                onChanged: onChanged,
              ),
            ],
          );
        }
        return SegmentedButton<_ManagementArea>(
          segments: const <ButtonSegment<_ManagementArea>>[
            ButtonSegment<_ManagementArea>(
              value: _ManagementArea.people,
              icon: Icon(Icons.people_outline),
              label: Text('成员', key: Key('management-area-people')),
            ),
            ButtonSegment<_ManagementArea>(
              value: _ManagementArea.students,
              icon: Icon(Icons.school_outlined),
              label: Text('学生', key: Key('management-area-students')),
            ),
            ButtonSegment<_ManagementArea>(
              value: _ManagementArea.settings,
              icon: Icon(Icons.tune_outlined),
              label: Text('设置', key: Key('management-area-settings')),
            ),
          ],
          selected: <_ManagementArea>{selectedArea},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) onChanged(selection.first);
          },
        );
      },
    );
  }
}

class _ManagementAreaChoiceChip extends StatelessWidget {
  const _ManagementAreaChoiceChip({
    required this.area,
    required this.icon,
    required this.label,
    required this.labelKey,
    required this.selectedArea,
    required this.onChanged,
  });

  final _ManagementArea area;
  final IconData icon;
  final String label;
  final Key labelKey;
  final _ManagementArea selectedArea;
  final ValueChanged<_ManagementArea> onChanged;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selectedArea == area,
      avatar: Icon(icon, size: 18),
      label: Text(label, key: labelKey),
      onSelected: (selected) {
        if (selected && selectedArea != area) {
          onChanged(area);
        }
      },
    );
  }
}

class _ManagementAreaCard extends StatelessWidget {
  const _ManagementAreaCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Material(
          color: colorScheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.55,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
                child,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ManagementSection extends StatelessWidget {
  const _ManagementSection({
    required this.title,
    required this.count,
    required this.child,
    this.action,
  });

  final String title;
  final String count;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    count,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: AppSpacing.sm),
              action!,
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _ManagementSetupHint extends StatelessWidget {
  const _ManagementSetupHint({
    required this.options,
    required this.subjectCatalog,
  });

  final OrganizationSetupOptions options;
  final List<OrganizationSubjectCatalogItem> subjectCatalog;

  @override
  Widget build(BuildContext context) {
    final ready = options.canCreateStudent;
    final message = ready
        ? '建档条件已就绪：已有机构学科，也有老师具备对应可教学科。'
        : options.subjects.isEmpty && subjectCatalog.isNotEmpty
        ? '先添加本机构实际教授的学科，再配置老师可教学科。'
        : '还缺老师的可教学科配置。先确认老师已加入，再配置其负责学科。';
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ready
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ready ? Icons.check_circle_outline : Icons.info_outline,
            size: 20,
            color: ready ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _ManagementEmptyState extends StatelessWidget {
  const _ManagementEmptyState({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementErrorState extends StatelessWidget {
  const _ManagementErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(
              '机构管理暂时无法加载',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text('请检查网络和账号状态后重试。'),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _ManagementErrorText extends StatelessWidget {
  const _ManagementErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
