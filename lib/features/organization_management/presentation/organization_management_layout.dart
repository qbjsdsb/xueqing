part of 'organization_management_page.dart';

class _ManagementHeader extends StatelessWidget {
  const _ManagementHeader({
    required this.organizationName,
    required this.roleLabel,
    required this.busy,
    required this.canInvite,
    required this.canManageCaseTypes,
    required this.onAddStudent,
    required this.onInviteMember,
    required this.onAddSubject,
    required this.onAddTeacherScope,
    this.onOpenCaseTypes,
  });

  final String organizationName;
  final String roleLabel;
  final bool busy;
  final bool canInvite;
  final bool canManageCaseTypes;
  final VoidCallback onAddStudent;
  final VoidCallback onInviteMember;
  final VoidCallback onAddSubject;
  final VoidCallback onAddTeacherScope;
  final VoidCallback? onOpenCaseTypes;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('机构管理', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$organizationName · $roleLabel',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
    final actions = Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        FilledButton.icon(
          onPressed: busy ? null : onAddStudent,
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('添加学生'),
        ),
        FilledButton.tonalIcon(
          onPressed: busy || !canInvite ? null : onInviteMember,
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('邀请成员'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onAddSubject,
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('添加学科'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onAddTeacherScope,
          icon: const Icon(Icons.rule_outlined),
          label: const Text('配置老师可教学科'),
        ),
        if (canManageCaseTypes && onOpenCaseTypes != null)
          OutlinedButton.icon(
            onPressed: busy ? null : onOpenCaseTypes,
            icon: const Icon(Icons.category_outlined),
            label: const Text('问题类型'),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: AppSpacing.md),
                actions,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              const SizedBox(width: AppSpacing.lg),
              Flexible(child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _ManagementBoundaryBanner extends StatelessWidget {
  const _ManagementBoundaryBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '管理身份只负责机构配置；老师实际能看到哪些学生，仍由可教学科和任课关系决定。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
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
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _ManagementSection extends StatelessWidget {
  const _ManagementSection({
    required this.title,
    required this.count,
    required this.child,
  });

  final String title;
  final String count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: AppSpacing.sm),
            Text(
              count,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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
        ? '学生建档条件已就绪：机构已有可用学科，并且至少一位老师具备对应可教学科。'
        : options.subjects.isEmpty && subjectCatalog.isNotEmpty
        ? '还缺机构学科。点击页面顶部“添加学科”即可选择。'
        : '还缺可用老师教学配置。先确认老师已加入，再配置其可教学科。';
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
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
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
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(alignment: Alignment.centerLeft, child: action!),
                ],
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
            Text('机构管理暂时无法加载', style: Theme.of(context).textTheme.titleMedium),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}
