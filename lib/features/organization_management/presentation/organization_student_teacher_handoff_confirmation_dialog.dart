import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../cloud/organization_management_repository.dart';

class OrganizationStudentTeacherHandoffConfirmationDialog
    extends StatelessWidget {
  const OrganizationStudentTeacherHandoffConfirmationDialog({
    required this.plan,
    super.key,
  });

  final OrganizationTeachingHandoffPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('确认教学责任交接'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plan.studentName} · ${plan.subjectName}',
                key: const ValueKey('handoff-confirm-student-subject'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${plan.sourceTeacherName} → ${plan.replacementTeacherName}',
                key: const ValueKey('handoff-confirm-teacher-change'),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('将同时迁移', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              _HandoffCountRow(
                label: '进行中问题',
                count: plan.affectedCases.length,
                key: const ValueKey('handoff-confirm-case-count'),
              ),
              if (plan.affectedCases.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                for (final learningCase in plan.affectedCases)
                  _HandoffItem(text: learningCase.title),
              ],
              const SizedBox(height: AppSpacing.md),
              _HandoffCountRow(
                label: '待完成行动',
                count: plan.affectedActions.length,
                key: const ValueKey('handoff-confirm-action-count'),
              ),
              if (plan.affectedActions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                for (final action in plan.affectedActions)
                  _HandoffItem(text: action.title),
              ],
              const SizedBox(height: AppSpacing.lg),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              Text(
                '历史证据、教学处理、检查结果和历史记录不会修改。交接只改变从现在开始由谁继续负责。',
                key: const ValueKey('handoff-confirm-history-note'),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('handoff-confirm-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('handoff-confirm-submit'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确认交接'),
        ),
      ],
    );
  }
}

class _HandoffCountRow extends StatelessWidget {
  const _HandoffCountRow({required this.label, required this.count, super.key});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text('$count 个', style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _HandoffItem extends StatelessWidget {
  const _HandoffItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
