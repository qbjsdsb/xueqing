part of 'organization_management_page.dart';

mixin _OrganizationManagementMemberActions on _OrganizationManagementCore {
  Future<void> _toggleMemberStatus(OrganizationMember member) async {
    if (_busy) return;
    final disabling = member.status != 'disabled';
    final confirmed = await _confirm(
      title: disabling ? '停用成员？' : '恢复成员？',
      message: disabling
          ? '停用后会结束当前可教学科和任课关系，历史记录保留；如果仍负责开放问题或待办，系统会阻止停用。'
          : '恢复后只恢复机构访问，不会自动恢复已经结束的教学关系。',
      confirmLabel: disabling ? '停用成员' : '恢复成员',
    );
    if (!mounted || !confirmed) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.repository.updateMemberStatus(
        operationId: createOperationId(),
        organizationId: widget.organizationId,
        membershipId: member.membershipId,
        expectedMembershipVersion: member.version,
        status: disabling ? 'disabled' : 'active',
      );
      await _refresh();
      if (!mounted) return;
      widget.onChanged?.call();
      final displayName = member.displayName ?? member.email;
      final message = result.status == 'disabled'
          ? '已停用 $displayName；结束了 ${result.endedScopeCount + result.endedAssignmentCount} 条当前教学关系。'
          : '已恢复 $displayName 的机构访问；需要的教学关系请重新配置。';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _inviteMember() async {
    if (_busy || _inviteRoles.isEmpty) return;
    final draft = await showDialog<_InviteDraft>(
      context: context,
      builder: (context) => _InviteMemberDialog(roles: _inviteRoles),
    );
    if (!mounted || draft == null) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final provisioningRepository = widget.provisioningRepository;
      OrganizationMemberProvisioningResult? provisioningResult;
      OrganizationInvitation? invitation;
      if (provisioningRepository != null) {
        provisioningResult = await provisioningRepository.provisionMember(
          organizationId: widget.organizationId,
          email: draft.email,
          displayName: draft.displayName,
          role: draft.role,
        );
      } else {
        invitation = await widget.repository.createInvitation(
          organizationId: widget.organizationId,
          email: draft.email,
          role: draft.role,
        );
      }
      if (!mounted) return;
      if (provisioningResult != null) {
        await _showProvisioningResult(provisioningResult);
      } else if (invitation != null) {
        final copied = await _showInviteCode(invitation);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              copied ? '邀请代码已复制。' : '邀请已创建，可在邀请列表中继续处理。',
            ),
          ),
        );
      }
      if (mounted) await _refresh();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editMemberDisplayName(OrganizationMember member) async {
    final provisioningRepository = widget.provisioningRepository;
    if (_busy || provisioningRepository == null) return;
    final displayName = await showDialog<String>(
      context: context,
      builder: (context) => _MemberNameDialog(
        title: '修改成员姓名',
        description: '姓名用于成员列表、任课关系和教师协作显示；邮箱仍作为登录账号保留。',
        initialValue: member.displayName == member.email
            ? ''
            : member.displayName ?? '',
        confirmLabel: '保存姓名',
      ),
    );
    if (!mounted || displayName == null) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final result = await provisioningRepository.updateMemberDisplayName(
        organizationId: widget.organizationId,
        membershipId: member.membershipId,
        displayName: displayName,
      );
      await _refresh();
      if (!mounted) return;
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已更新成员姓名：${result.displayName}。')),
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showProvisioningResult(
    OrganizationMemberProvisioningResult result,
  ) async {
    if (result.hasTemporaryPassword) {
      await _showTemporaryPassword(result);
      return;
    }
    if (result.invitation != null && result.isInviteCode) {
      await _showInviteCode(result.invitation!);
      return;
    }
    if (result.isWaitingForOwnerApproval && mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('等待负责人审批'),
          content: Text(
            '${result.email} 的负责人身份需要现有负责人审批。审批后再点击“开通账号”。',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }

  Future<bool> _showTemporaryPassword(
    OrganizationMemberProvisioningResult result,
  ) async {
    final temporaryPassword = result.temporaryPassword;
    if (temporaryPassword == null) return false;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('账号已开通'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '请通过可信方式把临时密码交给 ${result.email}。它只显示这一次；成员首次登录后必须设置新密码。',
                ),
                const SizedBox(height: AppSpacing.md),
                SelectableText(
                  temporaryPassword,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '接管有效期至 ${_formatDateTime(result.expiresAt)}。如果没有交付成功，请使用“重新发放临时密码”。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: temporaryPassword));
              if (context.mounted) Navigator.of(context).pop(true);
            },
            child: const Text('复制临时密码'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('完成'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  Future<bool> _showInviteCode(OrganizationInvitation invitation) {
    final inviteCode = invitation.inviteCode;
    if (inviteCode == null) return Future<bool>.value(false);
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
                const Text('请把邀请代码交给对应邮箱的账号；接受邀请时必须使用匹配邮箱登录。'),
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
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: inviteCode));
              if (context.mounted) Navigator.of(context).pop(true);
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
      '负责人提名已通过，现在可以开通账号。',
    );
  }

  Future<void> _provisionExistingInvitation(
    OrganizationInvitation invitation,
  ) async {
    final provisioningRepository = widget.provisioningRepository;
    if (_busy || provisioningRepository == null) return;
    final displayName = await showDialog<String>(
      context: context,
      builder: (context) => _MemberNameDialog(
        title: '开通成员账号',
        description: '请确认成员姓名。姓名会用于后续教师、任课和协作记录显示。',
        confirmLabel: '继续开通',
      ),
    );
    if (!mounted || displayName == null) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final result = await provisioningRepository.provisionExistingInvitation(
        invitationId: invitation.id,
        displayName: displayName,
      );
      if (mounted) {
        await _showProvisioningResult(result);
        await _refresh();
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reissueMemberCredential(OrganizationMember member) async {
    final provisioningRepository = widget.provisioningRepository;
    if (_busy || provisioningRepository == null || !member.isOnboarding) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final result = await provisioningRepository.reissueMemberCredential(
        organizationId: widget.organizationId,
        membershipId: member.membershipId,
      );
      if (mounted) {
        await _showTemporaryPassword(result);
        await _refresh();
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeInvitation(OrganizationInvitation invitation) async {
    final confirmed = await _confirm(
      title: '撤销邀请？',
      message: '撤销后这条邀请立即失效，之后仍可重新邀请同一个邮箱。',
      confirmLabel: '撤销邀请',
    );
    if (!mounted || !confirmed) return;
    await _runMutation(
      () => widget.repository.revokeInvitation(invitationId: invitation.id),
      '邀请已撤销。',
    );
  }
}
