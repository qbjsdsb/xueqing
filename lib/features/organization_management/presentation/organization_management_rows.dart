part of 'organization_management_page.dart';

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.busy,
    required this.lifecycleBusy,
    required this.canEditName,
    required this.onToggleStatus,
    this.onEditName,
    this.onReissueCredential,
  });

  final OrganizationMember member;
  final bool busy;
  final bool lifecycleBusy;
  final bool canEditName;
  final VoidCallback onToggleStatus;
  final VoidCallback? onEditName;
  final VoidCallback? onReissueCredential;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rawName = member.displayName?.trim() ?? '';
    final hasDisplayName =
        rawName.isNotEmpty &&
        rawName.toLowerCase() != member.email.trim().toLowerCase();
    final displayName = hasDisplayName ? rawName : '未填写姓名';
    final initials = hasDisplayName
        ? String.fromCharCode(rawName.runes.first).toUpperCase()
        : '?';
    return _ManagementRowShell(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        child: Text(initials),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(displayName, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            member.email,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
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
          if (member.isOnboarding && member.onboardingExpiresAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '首次接管有效期至 ${_formatDateTime(member.onboardingExpiresAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (canEditName && onEditName != null)
                TextButton.icon(
                  onPressed: busy ? null : onEditName,
                  icon: const Icon(Icons.badge_outlined, size: 18),
                  label: Text(hasDisplayName ? '修改姓名' : '补充姓名'),
                ),
              if (member.isOnboarding && onReissueCredential != null)
                TextButton.icon(
                  onPressed: busy ? null : onReissueCredential,
                  icon: const Icon(Icons.key_outlined, size: 18),
                  label: const Text('重新发放临时密码'),
                )
              else if (!member.isOnboarding)
                TextButton.icon(
                  onPressed: lifecycleBusy ? null : onToggleStatus,
                  icon: Icon(
                    member.status == 'disabled'
                        ? Icons.restore_outlined
                        : Icons.person_off_outlined,
                    size: 18,
                  ),
                  label: Text(member.status == 'disabled' ? '恢复成员' : '停用成员'),
                ),
            ],
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
    this.onProvision,
  });

  final OrganizationInvitation invitation;
  final bool isOwner;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onRevoke;
  final VoidCallback? onProvision;

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
    if (invitation.isPending && onProvision != null) {
      actions.add(
        FilledButton.tonal(
          onPressed: busy ? null : onProvision,
          child: const Text('开通账号'),
        ),
      );
    }
    if (isOwner &&
        (invitation.isPending || invitation.isAwaitingOwnerApproval)) {
      actions.add(
        TextButton(onPressed: busy ? null : onRevoke, child: const Text('撤销')),
      );
    }
    return _ManagementRowShell(
      leading: Icon(
        invitation.isAwaitingOwnerApproval
            ? Icons.pending_actions_outlined
            : Icons.outgoing_mail,
        color: Theme.of(context).colorScheme.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(invitation.email, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
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
    );
  }
}

class _TeacherSubjectScopeTile extends StatelessWidget {
  const _TeacherSubjectScopeTile({
    required this.scope,
    required this.busy,
    required this.showReactivate,
    required this.onToggle,
  });

  final OrganizationTeacherSubjectScope scope;
  final bool busy;
  final bool showReactivate;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final action = scope.isActive
        ? TextButton.icon(
            onPressed: busy ? null : onToggle,
            icon: const Icon(Icons.pause_circle_outline, size: 18),
            label: const Text('停用该学科'),
          )
        : showReactivate && scope.membershipStatus == 'active'
        ? TextButton.icon(
            onPressed: busy ? null : onToggle,
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('重新启用'),
          )
        : null;
    return _ManagementRowShell(
      leading: Icon(
        scope.isActive ? Icons.menu_book_outlined : Icons.history_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${scope.teacherName} · ${scope.subjectName}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (scope.teacherEmail.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              scope.teacherEmail,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              _ManagementStatusChip(
                label: scope.isActive ? '可教学' : '已结束',
                isPositive: scope.isActive,
              ),
              if (scope.membershipStatus != 'active')
                _ManagementStatusChip(
                  label: _membershipStatusLabel(scope.membershipStatus),
                  isPositive: false,
                ),
            ],
          ),
          if (!scope.isActive) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '结束于 ${_formatDateOnly(scope.activeTo)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(alignment: Alignment.centerLeft, child: action),
          ],
        ],
      ),
    );
  }
}

class _OrganizationStudentTile extends StatelessWidget {
  const _OrganizationStudentTile({
    required this.student,
    required this.busy,
    required this.onAddSubject,
    required this.onToggleSubjectService,
    required this.onToggleTeaching,
    required this.onEdit,
  });

  final OrganizationStudentRecord student;
  final bool busy;
  final VoidCallback? onAddSubject;
  final Future<void> Function(OrganizationStudentSubjectService service)?
  onToggleSubjectService;
  final VoidCallback? onToggleTeaching;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (student.studentCode != null) '编号 ${student.studentCode}',
      if (student.grade != null) student.grade!,
      if (student.className != null) student.className!,
      if (student.campus != null) student.campus!,
    ];
    return _ManagementRowShell(
      leading: Icon(
        Icons.school_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            student.studentName,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            children: [
              _ManagementStatusChip(
                label: _studentStatusLabel(student.status),
                isPositive: student.isActive,
              ),
              for (final detail in details) _ManagementRoleChip(label: detail),
            ],
          ),
          if (student.subjectServices.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Column(
              children: [
                for (final service in student.subjectServices)
                  _StudentSubjectServiceRow(
                    service: service,
                    busy: busy,
                    onToggle:
                        onToggleSubjectService == null ||
                            service.isArchived ||
                            service.isInactive && !student.isActive
                        ? null
                        : () => onToggleSubjectService!(service),
                  ),
              ],
            ),
          ] else if (student.subjectNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '学科：${student.subjectNames.join('、')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (onAddSubject != null ||
              onToggleTeaching != null ||
              onEdit != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (onAddSubject != null)
                  TextButton.icon(
                    onPressed: busy ? null : onAddSubject,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('添加学科'),
                  ),
                if (onToggleTeaching != null)
                  TextButton.icon(
                    key: ValueKey<String>(
                      'student-teaching-toggle-${student.studentId}',
                    ),
                    onPressed: busy ? null : onToggleTeaching,
                    icon: Icon(
                      student.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 18,
                    ),
                    label: Text(student.isActive ? '暂停教学' : '恢复教学'),
                  ),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('编辑'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentSubjectServiceRow extends StatelessWidget {
  const _StudentSubjectServiceRow({
    required this.service,
    required this.busy,
    required this.onToggle,
  });

  final OrganizationStudentSubjectService service;
  final bool busy;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              service.subjectName,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _ManagementStatusChip(
            label: _studentSubjectStatusLabel(service.status),
            isPositive: service.isActive,
          ),
          if (onToggle != null) ...[
            const SizedBox(width: AppSpacing.xxs),
            TextButton(
              key: ValueKey<String>(
                service.isActive
                    ? 'student-subject-end-${service.profileId}'
                    : 'student-subject-restore-${service.profileId}',
              ),
              onPressed: busy ? null : onToggle,
              child: Text(service.isActive ? '结束' : '恢复'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentTeacherAssignmentTile extends StatelessWidget {
  const _StudentTeacherAssignmentTile({
    required this.assignment,
    required this.busy,
    required this.onTransfer,
  });

  final OrganizationStudentTeacherAssignment assignment;
  final bool busy;
  final VoidCallback? onTransfer;

  @override
  Widget build(BuildContext context) {
    return _ManagementRowShell(
      leading: Icon(
        assignment.isActive
            ? Icons.person_pin_outlined
            : Icons.history_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${assignment.studentName} · ${assignment.subjectName}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${_studentAssignmentRoleLabel(assignment.assignmentRole)}：'
            '${assignment.teacherName}'
            '${assignment.teacherEmail.isEmpty ? '' : ' · ${assignment.teacherEmail}'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ManagementStatusChip(
            label: assignment.isActive ? '当前任课' : '历史任课',
            isPositive: assignment.isActive,
          ),
          if (onTransfer != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy ? null : onTransfer,
                icon: const Icon(Icons.swap_horiz_outlined, size: 18),
                label: const Text('交接老师'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManagementRowShell extends StatelessWidget {
  const _ManagementRowShell({required this.leading, required this.child});

  final Widget leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 40, child: Center(child: leading)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: child),
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
