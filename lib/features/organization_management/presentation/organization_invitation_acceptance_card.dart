import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';

class OrganizationInvitationAcceptanceCard extends StatelessWidget {
  const OrganizationInvitationAcceptanceCard({
    required this.formKey,
    required this.inviteCodeController,
    required this.displayNameController,
    required this.busy,
    required this.initiallyExpanded,
    required this.onAccept,
    this.errorMessage,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController inviteCodeController;
  final TextEditingController displayNameController;
  final bool busy;
  final bool initiallyExpanded;
  final VoidCallback onAccept;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: const Icon(Icons.mark_email_unread_outlined),
        title: const Text('接受机构邀请'),
        subtitle: const Text('如果你收到了负责人或管理员发来的邀请代码'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '请使用被邀请的邮箱登录后，再粘贴邀请代码。代码只显示一次，接受后即加入对应机构。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: inviteCodeController,
                    enabled: !busy,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: '邀请代码',
                      hintText: '粘贴 24 位代码',
                    ),
                    validator: (value) {
                      final code = value?.trim() ?? '';
                      if (code.length < 16) {
                        return '请输入完整的邀请代码。';
                      }
                      if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(code)) {
                        return '邀请代码只能包含数字和英文字母。';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: displayNameController,
                    enabled: !busy,
                    textInputAction: TextInputAction.done,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: '显示名称（可选）',
                      hintText: '首次加入时使用的名称',
                    ),
                    onFieldSubmitted: (_) {
                      if (!busy) {
                        onAccept();
                      }
                    },
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy ? null : onAccept,
                      icon: const Icon(Icons.how_to_reg_outlined),
                      label: Text(busy ? '正在接受…' : '接受邀请'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
