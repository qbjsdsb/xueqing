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

  void _submit() {
    if (formKey.currentState?.validate() ?? false) {
      onAccept();
    }
  }

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
                    '请先使用被邀请的邮箱登录，再粘贴完整的 24 位邀请代码。代码只显示一次，接受后会立即按你的机构身份进入对应工作范围。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('invitation-accept-code'),
                    controller: inviteCodeController,
                    enabled: !busy,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: '邀请代码 *',
                      hintText: '粘贴 24 位代码',
                    ),
                    validator: (value) {
                      final code = value?.trim() ?? '';
                      if (code.length != 24) {
                        return '邀请代码应为完整的 24 位。';
                      }
                      if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(code)) {
                        return '邀请代码格式不正确，请重新粘贴。';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    key: const Key('invitation-accept-display-name'),
                    controller: displayNameController,
                    enabled: !busy,
                    textInputAction: TextInputAction.done,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: '姓名（已有姓名可不填）',
                      hintText: '例如：王老师',
                      helperText: '首次加入时填写，会用于机构成员列表和老师显示名称。',
                    ),
                    onFieldSubmitted: (_) {
                      if (!busy) {
                        _submit();
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
                      onPressed: busy ? null : _submit,
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
