part of 'organization_management_page.dart';

class _InviteDraft {
  const _InviteDraft({
    required this.displayName,
    required this.email,
    required this.role,
  });

  final String displayName;
  final String email;
  final OrganizationInvitationRole role;
}

class _InviteMemberDialog extends StatefulWidget {
  const _InviteMemberDialog({required this.roles});

  final List<OrganizationInvitationRole> roles;

  @override
  State<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<_InviteMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  late OrganizationInvitationRole _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.roles.first;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _InviteDraft(
        displayName: _displayNameController.text.trim(),
        email: _emailController.text.trim(),
        role: _selectedRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('邀请成员'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('填写姓名、登录邮箱和身份。姓名会显示在机构内，邮箱用于登录；系统会根据账号状态完成开通或邀请。'),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _displayNameController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: '姓名 *',
                      hintText: '例如：王老师',
                    ),
                    validator: _validateDisplayName,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const <String>[AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: '登录邮箱 *',
                      hintText: 'name@example.com',
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return '请输入邮箱。';
                      if (email.length > 320 ||
                          !email.contains('@') ||
                          email.startsWith('@') ||
                          email.endsWith('@')) {
                        return '请输入有效邮箱。';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<OrganizationInvitationRole>(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(labelText: '身份 *'),
                    items: [
                      for (final role in widget.roles)
                        DropdownMenuItem<OrganizationInvitationRole>(
                          value: role,
                          child: Text(role.label),
                        ),
                    ],
                    onChanged: (role) {
                      if (role != null) setState(() => _selectedRole = role);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(switch (_selectedRole) {
                    OrganizationInvitationRole.owner =>
                      '负责人拥有成员账号和机构设置权限，请只授予确实需要承担机构责任的人。',
                    OrganizationInvitationRole.admin =>
                      '管理员可以管理机构教学与学生信息，但不能邀请、停用或恢复成员账号。',
                    OrganizationInvitationRole.teacher =>
                      '老师只处理教学工作；能看到哪些学生仍由可教学科和任课关系决定。',
                  }, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('invite-member-submit'),
          onPressed: _submit,
          child: const Text('继续'),
        ),
      ],
    );
  }
}

class _MemberNameDialog extends StatefulWidget {
  const _MemberNameDialog({
    required this.title,
    required this.description,
    required this.confirmLabel,
    this.initialValue = '',
  });

  final String title;
  final String description;
  final String confirmLabel;
  final String initialValue;

  @override
  State<_MemberNameDialog> createState() => _MemberNameDialogState();
}

class _MemberNameDialogState extends State<_MemberNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.description),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.name],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: '姓名 *',
                    hintText: '例如：王老师',
                  ),
                  validator: _validateDisplayName,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

String? _validateDisplayName(String? value) {
  final displayName = value?.trim() ?? '';
  if (displayName.isEmpty) return '请输入姓名。';
  if (displayName.length > 120) return '姓名不能超过 120 个字符。';
  return null;
}
