import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/layout/responsive.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../cloud/organization_management_repository.dart';

class OrganizationManagementPage extends StatefulWidget {
  const OrganizationManagementPage({
    required this.repository,
    required this.organizationId,
    required this.organizationName,
    required this.roles,
    this.canManageCaseTypes = false,
    this.onOpenCaseTypes,
    super.key,
  });

  final OrganizationManagementRepository repository;
  final String organizationId;
  final String organizationName;
  final List<String> roles;
  final bool canManageCaseTypes;
  final VoidCallback? onOpenCaseTypes;

  @override
  State<OrganizationManagementPage> createState() =>
      _OrganizationManagementPageState();
}

class _OrganizationManagementPageState
    extends State<OrganizationManagementPage> {
  late Future<_OrganizationManagementSnapshot> _snapshotFuture;
  bool _busy = false;
  String? _errorMessage;

  bool get _isOwner => widget.roles.contains('org_owner');

  List<OrganizationInvitationRole> get _inviteRoles {
    if (_isOwner) {
      return const <OrganizationInvitationRole>[
        OrganizationInvitationRole.admin,
        OrganizationInvitationRole.teacher,
        OrganizationInvitationRole.academicAdmin,
      ];
    }
    return const <OrganizationInvitationRole>[
      OrganizationInvitationRole.owner,
      OrganizationInvitationRole.teacher,
    ];
  }

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _load();
  }

  Future<_OrganizationManagementSnapshot> _load() async {
    final result = await Future.wait<dynamic>([
      widget.repository.listMembers(organizationId: widget.organizationId),
      widget.repository.listInvitations(organizationId: widget.organizationId),
    ]);
    return _OrganizationManagementSnapshot(
      members: result[0] as List<OrganizationMember>,
      invitations: result[1] as List<OrganizationInvitation>,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    if (!mounted) {
      return;
    }
    setState(() {
      _snapshotFuture = next;
    });
    await next;
  }

  Future<void> _inviteMember() async {
    if (_busy) {
      return;
    }
    final draft = await showDialog<_InviteDraft>(
      context: context,
      builder: (context) => _InviteMemberDialog(roles: _inviteRoles),
    );
    if (!mounted || draft == null) {
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final invitation = await widget.repository.createInvitation(
        organizationId: widget.organizationId,
        email: draft.email,
        role: draft.role,
      );
      await _refresh();
      if (!mounted) {
        return;
      }
      final copied = await _showInviteCode(invitation);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copied ? '邀请代码已复制。' : '邀请已创建，可在邀请列表中继续处理。')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _describeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _showInviteCode(OrganizationInvitation invitation) {
    final inviteCode = invitation.inviteCode;
    if (inviteCode == null) {
      return Future<bool>.value(false);
    }
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('邀请已创建'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '请把下面的邀请代码交给对应邮箱的账号。代码只在创建时显示一次，接受邀请时必须使用匹配的邮箱登录。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                SelectableText(
                  inviteCode,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '角色：${invitation.role.label} · 有效期：${_formatDateTime(invitation.expiresAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '当前为开发环境代码邀请；正式环境接入邮件邀请后，不需要手工转发代码。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: inviteCode));
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('复制代码'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('完成'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  Future<void> _approveInvitation(OrganizationInvitation invitation) async {
    await _runMutation(
      () => widget.repository.approveInvitation(invitationId: invitation.id),
      '负责人提名已通过，现在可以由对应邮箱接受邀请。',
    );
  }

  Future<void> _revokeInvitation(OrganizationInvitation invitation) async {
    final confirmed = await _confirm(
      title: '撤销邀请？',
      message: '撤销后这条邀请代码立即失效，之后仍可重新邀请同一个邮箱。',
      confirmLabel: '撤销邀请',
    );
    if (!mounted || !confirmed) {
      return;
    }
    await _runMutation(
      () => widget.repository.revokeInvitation(invitationId: invitation.id),
      '邀请已撤销。',
    );
  }

  Future<void> _runMutation(
    Future<Object> Function() mutation,
    String successMessage,
  ) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await mutation();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _describeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _describeError(Object error) {
    if (error is AuthException) {
      return switch (error.message) {
        'organization_owner_required' => '这项操作需要负责人确认。',
        'organization_manager_required' => '当前账号没有本机构管理权限。',
        'invitation_already_exists' => '这个邮箱已有相同角色的待处理邀请。',
        'invitation_not_awaiting_approval' => '这条邀请已经变化，请刷新后再试。',
        _ => '操作未完成，请检查网络和账号状态后重试。',
      };
    }
    return '操作未完成，请检查网络后重试。';
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      builder: (context, sizeClass) {
        final horizontalPadding = switch (sizeClass) {
          WindowSizeClass.compact => AppSpacing.md,
          WindowSizeClass.medium => AppSpacing.lg,
          WindowSizeClass.expanded => AppSpacing.xl,
        };
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.md,
            horizontalPadding,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ManagementBoundaryBanner(),
              const SizedBox(height: AppSpacing.lg),
              _ManagementHeader(
                organizationName: widget.organizationName,
                roleLabel: _roleSummary(widget.roles),
                actions: [
                  if (widget.canManageCaseTypes &&
                      widget.onOpenCaseTypes != null)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : widget.onOpenCaseTypes,
                      icon: const Icon(Icons.category_outlined),
                      label: const Text('问题类型'),
                    ),
                  FilledButton.icon(
                    onPressed: _busy || _inviteRoles.isEmpty
                        ? null
                        : _inviteMember,
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('邀请成员'),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                _ManagementErrorText(message: _errorMessage!),
                const SizedBox(height: AppSpacing.md),
              ],
              FutureBuilder<_OrganizationManagementSnapshot>(
                future: _snapshotFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return _ManagementErrorState(
                      onRetry: () {
                        setState(() {
                          _errorMessage = null;
                          _snapshotFuture = _load();
                        });
                      },
                    );
                  }
                  return _ManagementContent(
                    snapshot: snapshot.data!,
                    isOwner: _isOwner,
                    busy: _busy,
                    onApprove: _approveInvitation,
                    onRevoke: _revokeInvitation,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrganizationManagementSnapshot {
  const _OrganizationManagementSnapshot({
    required this.members,
    required this.invitations,
  });

  final List<OrganizationMember> members;
  final List<OrganizationInvitation> invitations;
}

class _ManagementContent extends StatelessWidget {
  const _ManagementContent({
    required this.snapshot,
    required this.isOwner,
    required this.busy,
    required this.onApprove,
    required this.onRevoke,
  });

  final _OrganizationManagementSnapshot snapshot;
  final bool isOwner;
  final bool busy;
  final Future<void> Function(OrganizationInvitation invitation) onApprove;
  final Future<void> Function(OrganizationInvitation invitation) onRevoke;

  @override
  Widget build(BuildContext context) {
    final pendingApprovals = snapshot.invitations
        .where((invitation) => invitation.isAwaitingOwnerApproval)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _ManagementSummaryCard(
              icon: Icons.people_outline,
              label: '机构成员',
              value: '${snapshot.members.length}',
            ),
            _ManagementSummaryCard(
              icon: Icons.mail_outline,
              label: '待处理邀请',
              value: '${snapshot.invitations.length}',
            ),
            if (pendingApprovals > 0)
              _ManagementSummaryCard(
                icon: Icons.approval_outlined,
                label: '待负责人审批',
                value: '$pendingApprovals',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _ManagementSection(
          title: '成员',
          count: '${snapshot.members.length} 人',
          child: snapshot.members.isEmpty
              ? const _ManagementEmptyState(
                  title: '还没有机构成员',
                  message: '邀请第一位老师或管理员后，成员会显示在这里。',
                  icon: Icons.people_outline,
                )
              : Column(
                  children: [
                    for (final member in snapshot.members)
                      _MemberTile(member: member),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ManagementSection(
          title: '邀请',
          count: '${snapshot.invitations.length} 条',
          child: snapshot.invitations.isEmpty
              ? const _ManagementEmptyState(
                  title: '没有待处理邀请',
                  message: '新邀请会在这里显示；已接受或已撤销的代码不会继续出现在待处理列表。',
                  icon: Icons.mark_email_read_outlined,
                )
              : Column(
                  children: [
                    for (final invitation in snapshot.invitations)
                      _InvitationTile(
                        invitation: invitation,
                        isOwner: isOwner,
                        busy: busy,
                        onApprove: () => onApprove(invitation),
                        onRevoke: () => onRevoke(invitation),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final OrganizationMember member;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = member.displayName ?? member.email;
    final initials = displayName.trim().isEmpty
        ? '·'
        : String.fromCharCode(displayName.trim().runes.first).toUpperCase();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: Text(initials),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  member.email,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    for (final role in member.roles)
                      _ManagementRoleChip(label: _roleLabel(role)),
                    _ManagementStatusChip(
                      label: _membershipStatusLabel(member.status),
                      isPositive: member.isActive,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationTile extends StatelessWidget {
  const _InvitationTile({
    required this.invitation,
    required this.isOwner,
    required this.busy,
    required this.onApprove,
    required this.onRevoke,
  });

  final OrganizationInvitation invitation;
  final bool isOwner;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    if (isOwner && invitation.isAwaitingOwnerApproval) {
      actions.add(
        FilledButton.tonal(
          onPressed: busy ? null : onApprove,
          child: const Text('通过负责人提名'),
        ),
      );
    }
    if (invitation.isPending || invitation.isAwaitingOwnerApproval) {
      actions.add(
        TextButton(onPressed: busy ? null : onRevoke, child: const Text('撤销')),
      );
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            invitation.isAwaitingOwnerApproval
                ? Icons.pending_actions_outlined
                : Icons.outgoing_mail,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.email,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    _ManagementRoleChip(label: invitation.role.label),
                    _ManagementStatusChip(
                      label: _invitationStatusLabel(invitation.status),
                      isPositive: invitation.isPending,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '有效期至 ${_formatDateTime(invitation.expiresAt)}'
                  '${invitation.invitedByName == null ? '' : ' · 发起人 ${invitation.invitedByName}'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: actions,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteDraft {
  const _InviteDraft({required this.email, required this.role});

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
  final _emailController = TextEditingController();
  late OrganizationInvitationRole _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.roles.first;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _InviteDraft(email: _emailController.text.trim(), role: _selectedRole),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('邀请成员'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '邀请发送后，成员需要使用匹配的邮箱登录并接受邀请。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '邮箱',
                    hintText: 'name@example.com',
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return '请输入邮箱。';
                    }
                    if (email.length > 320 || !email.contains('@')) {
                      return '请输入有效邮箱。';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<OrganizationInvitationRole>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(labelText: '角色'),
                  items: [
                    for (final role in widget.roles)
                      DropdownMenuItem<OrganizationInvitationRole>(
                        value: role,
                        child: Text(role.label),
                      ),
                  ],
                  onChanged: (role) {
                    if (role != null) {
                      setState(() => _selectedRole = role);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _selectedRole == OrganizationInvitationRole.owner
                        ? '管理员提名负责人后，需要现有负责人审批才能接受。'
                        : '角色只决定机构内的管理/教学身份，具体学生范围仍由学科和分配关系决定。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
        FilledButton(onPressed: _submit, child: const Text('创建邀请')),
      ],
    );
  }
}

class _ManagementHeader extends StatelessWidget {
  const _ManagementHeader({
    required this.organizationName,
    required this.roleLabel,
    required this.actions,
  });

  final String organizationName;
  final String roleLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('机构管理', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$organizationName · $roleLabel',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
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
              Expanded(child: title),
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
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
              '仅显示本机构的成员和邀请；管理员权限不会自动扩大教师的学生教学范围。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
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
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: AppSpacing.sm),
            Text(count, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _ManagementSummaryCard extends StatelessWidget {
  const _ManagementSummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 144),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManagementRoleChip extends StatelessWidget {
  const _ManagementRoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
    );
  }
}

class _ManagementStatusChip extends StatelessWidget {
  const _ManagementStatusChip({required this.label, required this.isPositive});

  final String label;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isPositive
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '机构管理暂时无法加载',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '请检查网络和开发环境同步状态后重试。',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
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

String _roleSummary(List<String> roles) {
  final labels = <String>[
    for (final role in roles)
      if (_roleLabel(role) != role) _roleLabel(role),
  ];
  return labels.isEmpty ? '机构成员' : labels.join('、');
}

String _roleLabel(String role) {
  return switch (role) {
    'org_owner' => '负责人',
    'org_admin' => '管理员',
    'academic_admin' => '教务管理员',
    'subject_lead' => '学科负责人',
    'teacher' => '老师',
    'student_advisor' => '学生导师',
    _ => role,
  };
}

String _membershipStatusLabel(String status) {
  return switch (status) {
    'active' => '正常',
    'onboarding' => '待完成',
    'disabled' => '已停用',
    _ => '状态未知',
  };
}

String _invitationStatusLabel(String status) {
  return switch (status) {
    'pending_owner_approval' => '待负责人审批',
    'pending' => '待接受',
    'expired' => '已过期',
    'revoked' => '已撤销',
    'accepted' => '已接受',
    _ => '状态未知',
  };
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return '—';
  }
  final local = value.toLocal();
  String pad(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${pad(local.month)}-${pad(local.day)} '
      '${pad(local.hour)}:${pad(local.minute)}';
}
