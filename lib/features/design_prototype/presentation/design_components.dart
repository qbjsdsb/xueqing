import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../design_fixture.dart';

class DesignPreviewBanner extends StatelessWidget {
  const DesignPreviewBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '设计预览，使用虚构数据，不写入云端',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Row(
          children: [
            Icon(
              Icons.science_outlined,
              size: 17,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '设计预览 · 虚构数据',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Text(
              '不写入云端',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DesignPageHeader extends StatelessWidget {
  const DesignPageHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canFitActions = constraints.maxWidth >= 560;
          if (!canFitActions && actions.isNotEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(child: titleBlock),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: actions,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(child: titleBlock),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: actions,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class DesignSection extends StatelessWidget {
  const DesignSection({
    required this.title,
    required this.child,
    this.count,
    this.action,
    this.showTopDivider = false,
    super.key,
  });

  final String title;
  final Widget child;
  final String? count;
  final Widget? action;
  final bool showTopDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTopDivider) const Divider(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (count != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        count!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              ?action,
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class DesignStatusMarker extends StatelessWidget {
  const DesignStatusMarker({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(label, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.foreground.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppRadii.compact),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(colors.icon, size: 15, color: colors.foreground),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class DesignMetadata extends StatelessWidget {
  const DesignMetadata(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(text, style: style),
        ),
      ],
    );
  }
}

class DesignStudentRow extends StatelessWidget {
  const DesignStudentRow({
    required this.student,
    required this.onOpen,
    super.key,
  });

  final PrototypeStudent student;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _InteractiveSurface(
      label: '打开 ${student.name} 的学生详情',
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxs),
              child: Icon(Icons.person_outline, size: 21),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      DesignMetadata('${student.grade} · ${student.subject}'),
                      DesignMetadata(student.context),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    student.cases.isEmpty
                        ? '还没有 Learning Case'
                        : '${student.cases.length} 个当前 Learning Case',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class DesignCaseRow extends StatelessWidget {
  const DesignCaseRow({
    required this.student,
    required this.learningCase,
    required this.onOpen,
    this.onPrimaryAction,
    this.primaryActionLabel,
    super.key,
  });

  final PrototypeStudent student;
  final PrototypeCase learningCase;
  final VoidCallback onOpen;
  final VoidCallback? onPrimaryAction;
  final String? primaryActionLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Case 信息：${student.name} · ${learningCase.title}',
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      learningCase.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  DesignStatusMarker(label: learningCase.statusLabel),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xxs,
                children: [
                  DesignMetadata('${student.name} · ${learningCase.subject}'),
                  DesignMetadata(learningCase.priorityLabel),
                  DesignMetadata('下一步：${learningCase.nextAction}'),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  OutlinedButton(
                    onPressed: onOpen,
                    child: const Text('查看 Case'),
                  ),
                  if (onPrimaryAction != null)
                    FilledButton(
                      onPressed: onPrimaryAction,
                      child: Text(primaryActionLabel ?? '处理下一步'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DesignActionRow extends StatelessWidget {
  const DesignActionRow({
    required this.student,
    required this.learningCase,
    required this.action,
    required this.onOpenCase,
    required this.onComplete,
    this.isCompleted = false,
    super.key,
  });

  final PrototypeStudent student;
  final PrototypeCase learningCase;
  final PrototypeAction action;
  final VoidCallback onOpenCase;
  final VoidCallback onComplete;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    final effectiveTitleStyle = isCompleted
        ? titleStyle?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            decoration: TextDecoration.lineThrough,
          )
        : titleStyle;
    final dueIcon = action.dueBucket == PrototypeActionDueBucket.undated
        ? Icons.event_busy_outlined
        : Icons.event_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _actionIcon(action.kind),
                size: 21,
                color: _actionColor(action, Theme.of(context).colorScheme),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(action.title, style: effectiveTitleStyle),
                    const SizedBox(height: AppSpacing.xxs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        DesignMetadata(
                          '${student.name} · ${learningCase.subject}',
                        ),
                        DesignMetadata(
                          isCompleted ? '已完成' : action.dueLabel,
                          icon: dueIcon,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: 33),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton(
                  onPressed: onOpenCase,
                  child: const Text('查看 Case'),
                ),
                if (!isCompleted)
                  FilledButton(onPressed: onComplete, child: const Text('完成')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DesignTimelineItem extends StatelessWidget {
  const DesignTimelineItem({required this.event, super.key});

  final PrototypeTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              event.dateLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(
              Icons.circle,
              size: 8,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.typeLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(event.text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DesignStateNotice extends StatelessWidget {
  const DesignStateNotice({
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveSurface extends StatefulWidget {
  const _InteractiveSurface({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_InteractiveSurface> createState() => _InteractiveSurfaceState();
}

class _InteractiveSurfaceState extends State<_InteractiveSurface> {
  bool _hovering = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (value) {
        if (mounted) setState(() => _hovering = value);
      },
      onShowFocusHighlight: (value) {
        if (mounted) setState(() => _focused = value);
      },
      child: Semantics(
        button: true,
        explicitChildNodes: true,
        label: widget.label,
        child: InkWell(
          onTap: widget.onTap,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashColor: Theme.of(context).colorScheme.primaryContainer,
          highlightColor: Theme.of(context).colorScheme.primaryContainer
              .withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadii.small),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _focused || _hovering
                  ? Theme.of(context).colorScheme.surfaceContainerHigh
                  : Colors.transparent,
              border: _focused
                  ? Border.all(color: Theme.of(context).colorScheme.primary)
                  : Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _StatusColors {
  _StatusColors({
    required this.foreground,
    required this.background,
    required this.icon,
  });

  final Color foreground;
  final Color background;
  final IconData icon;
}

_StatusColors _statusColors(String label, ColorScheme scheme) {
  if (label.contains('逾期')) {
    return _StatusColors(
      foreground: scheme.error,
      background: scheme.errorContainer,
      icon: Icons.warning_amber_outlined,
    );
  }
  if (label.contains('验证')) {
    return _StatusColors(
      foreground: scheme.tertiary,
      background: scheme.tertiaryContainer,
      icon: Icons.fact_check_outlined,
    );
  }
  if (label.contains('稳定')) {
    return _StatusColors(
      foreground: scheme.primary,
      background: scheme.primaryContainer,
      icon: Icons.check_circle_outline,
    );
  }
  if (label.contains('关闭')) {
    return _StatusColors(
      foreground: scheme.onSurfaceVariant,
      background: scheme.surfaceContainerHigh,
      icon: Icons.archive_outlined,
    );
  }
  return _StatusColors(
    foreground: scheme.secondary,
    background: scheme.secondaryContainer,
    icon: Icons.pending_outlined,
  );
}

IconData _actionIcon(PrototypeActionKind kind) {
  return switch (kind) {
    PrototypeActionKind.evidence => Icons.search_outlined,
    PrototypeActionKind.intervention => Icons.edit_note_outlined,
    PrototypeActionKind.verification => Icons.fact_check_outlined,
    PrototypeActionKind.review => Icons.event_repeat_outlined,
  };
}

Color _actionColor(PrototypeAction action, ColorScheme scheme) {
  return switch (action.dueBucket) {
    PrototypeActionDueBucket.overdue => scheme.error,
    PrototypeActionDueBucket.undated => scheme.secondary,
    PrototypeActionDueBucket.today ||
    PrototypeActionDueBucket.future => scheme.primary,
  };
}
