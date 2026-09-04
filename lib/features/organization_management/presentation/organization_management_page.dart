import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/layout/responsive.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../cloud/learning_repository.dart';
import '../../../cloud/organization_management_repository.dart';
import 'organization_student_edit_dialog.dart';
import 'organization_student_setup_dialog.dart';
import 'organization_subject_setup_dialog.dart';
import 'organization_teacher_subject_scope_dialog.dart';

class OrganizationManagementPage extends StatefulWidget {
  const OrganizationManagementPage({
    required this.repository,
    required this.organizationId,
    required this.organizationName,
    required this.roles,
    this.canManageCaseTypes = false,
    this.onOpenCaseTypes,
    this.onChanged,
    super.key,
  });

  final OrganizationManagementRepository repository;
  final String organizationId;
  final String organizationName;
  final List<String> roles;
  final bool canManageCaseTypes;
  final VoidCallback? onOpenCaseTypes;
  final VoidCallback? onChanged;

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
      widget.repository.listStudents(organizationId: widget.organizationId),
      widget.repository.listSetupOptions(organizationId: widget.organizationId),
      widget.repository.listSubjectCatalog(
        organizationId: widget.organizationId,
      ),
      widget.repository.listTeacherSubjectScopes(
        organizationId: widget.organizationId,
      ),
    ]);
    return _OrganizationManagementSnapshot(
      members: result[0] as List<OrganizationMember>,
      invitations: result[1] as List<OrganizationInvitation>,
      students: result[2] as List<OrganizationStudentRecord>,
      setupOptions: result[3] as OrganizationSetupOptions,
      subjectCatalog: result[4] as List<OrganizationSubjectCatalogItem>,
      teacherSubjectScopes: result[5] as List<OrganizationTeacherSubjectScope>,
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

  Future<void> _addSubject() async {
    if (_busy) {
      return;
    }
    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) {
        return;
      }
      if (snapshot.subjectCatalog.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('当前没有可添加的活跃学科。')));
        return;
      }
      setState(() {
        _busy = true;
        _errorMessage = null;
      });
      final result = await showDialog<OrganizationSubjectSetupResult>(
        context: context,
        builder: (context) => OrganizationSubjectSetupDialog(
          subjects: snapshot.subjectCatalog,
          onSubmit: (draft) => widget.repository.createSubject(
            operationId: draft.operationId,
            organizationId: widget.organizationId,
            subjectId: draft.subjectId,
          ),
        ),
      );
      if (!mounted || result == null) {
        return;
      }
      await _refresh();
      if (!mounted) {
        return;
      }
      widget.onChanged?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已添加学科：${result.subjectName}。')));
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

  Future<void> _addTeacherScope() async {
    if (_busy) {
      return;
    }
    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) {
        return;
      }
      final teachers = snapshot.setupOptions.teachers;
      final subjects = snapshot.setupOptions.subjects;
      if (teachers.isEmpty || subjects.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先配置至少一个在岗老师和一个活跃学科。')));
        return;
      }
      final activeScopeKeys = <String>{
        for (final scope in snapshot.teacherSubjectScopes)
          if (scope.isActive)
            _teacherScopeKey(scope.membershipId, scope.organizationSubjectId),
      };
      final hasAvailablePair = teachers.any(
        (teacher) => subjects.any(
          (subject) => !activeScopeKeys.contains(
            _teacherScopeKey(teacher.membershipId, subject.id),
          ),
        ),
      );
      if (!hasAvailablePair) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('目前所有老师与学科组合都已配置教学范围。')));
        return;
      }
      final draft = await showDialog<OrganizationTeacherSubjectScopeDraft>(
        context: context,
        builder: (context) => OrganizationTeacherSubjectScopeDialog(
          teachers: teachers,
          subjects: subjects,
          activeScopeKeys: activeScopeKeys,
        ),
      );
      if (!mounted || draft == null) {
        return;
      }
      await _runMutation(
        () => widget.repository.updateTeacherSubjectScope(
          operationId: draft.operationId,
          organizationId: widget.organizationId,
          membershipId: draft.membershipId,
          organizationSubjectId: draft.organizationSubjectId,
          status: 'active',
        ),
        '已为 ${draft.teacherName} 配置 ${draft.subjectName} 教学范围。',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _describeError(error));
      }
    }
  }

  Future<void> _toggleTeacherScope(
    OrganizationTeacherSubjectScope scope,
  ) async {
    if (_busy) {
      return;
    }
    final ending = scope.isActive;
    if (!ending && scope.membershipStatus != 'active') {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('成员恢复后才能重新启用教学范围。')));
      return;
    }
    final confirmed = await _confirm(
      title: ending ? '停用教学范围？' : '重新启用教学范围？',
      message: ending
          ? '停用后不会自动转交学生任课、开放案件或待办行动；如果仍有这些事项，系统会拒绝操作并保留当前范围。'
          : '重新启用会创建新的教学范围区间，不会自动恢复历史学生任课关系；请按需重新配置学生分配。',
      confirmLabel: ending ? '停用教学范围' : '重新启用',
    );
    if (!mounted || !confirmed) {
      return;
    }
    await _runMutation(
      () => widget.repository.updateTeacherSubjectScope(
        operationId: createOperationId(),
        organizationId: widget.organizationId,
        membershipId: scope.membershipId,
        organizationSubjectId: scope.organizationSubjectId,
        scopeId: ending ? scope.scopeId : null,
        expectedScopeVersion: ending ? scope.version : null,
        status: ending ? 'ended' : 'active',
      ),
      ending
          ? '已结束 ${scope.teacherName} 的 ${scope.subjectName} 教学范围。'
          : '已重新启用 ${scope.teacherName} 的 ${scope.subjectName} 教学范围。',
    );
  }

  Future<void> _addStudent() async {
    if (_busy) {
      return;
    }
    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) {
        return;
      }
      if (!snapshot.setupOptions.canCreateStudent) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('请先配置至少一个活跃学科和在岗老师。')));
        return;
      }
      final result = await showDialog<OrganizationStudentSetupResult>(
        context: context,
        builder: (context) => OrganizationStudentSetupDialog(
          options: snapshot.setupOptions,
          onSubmit: (draft) => widget.repository.createStudent(
            operationId: draft.operationId,
            organizationId: widget.organizationId,
            name: draft.name,
            studentCode: draft.studentCode,
            grade: draft.grade,
            className: draft.className,
            campus: draft.campus,
            organizationSubjectId: draft.organizationSubjectId,
            teacherMembershipId: draft.teacherMembershipId,
            positioning: draft.positioning,
            strengths: draft.strengths,
            cadenceNote: draft.cadenceNote,
          ),
        ),
      );
      if (!mounted || result == null) {
        return;
      }
      await _refresh();
      if (!mounted) {
        return;
      }
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已添加 ${result.studentName} · ${result.subjectName} · '
            '${result.teacherDisplayName}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _describeError(error));
      }
    }
  }

  Future<void> _editStudent(OrganizationStudentRecord student) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final result = await showDialog<OrganizationStudentUpdateResult>(
        context: context,
        builder: (context) => OrganizationStudentEditDialog(
          student: student,
          onSubmit: (draft) => widget.repository.updateStudent(
            operationId: draft.operationId,
            organizationId: widget.organizationId,
            studentId: draft.studentId,
            expectedStudentVersion: draft.expectedStudentVersion,
            name: draft.name,
            studentCode: draft.studentCode,
            status: draft.status,
          ),
        ),
      );
      if (!mounted || result == null) {
        return;
      }
      await _refresh();
      if (!mounted) {
        return;
      }
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已更新 ${result.studentName} · ${_studentStatusLabel(result.status)}。',
          ),
        ),
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

  Future<void> _toggleMemberStatus(OrganizationMember member) async {
    if (_busy) {
      return;
    }
    final disabling = member.status != 'disabled';
    final confirmed = await _confirm(
      title: disabling ? '停用成员？' : '恢复成员？',
      message: disabling
          ? '停用后会立即结束当前教学范围和任课关系，但历史记录会保留；以后恢复访问时不会自动恢复这些关系。'
          : '恢复后只恢复机构访问，不会自动恢复已经结束的教学范围和任课关系。',
      confirmLabel: disabling ? '停用成员' : '恢复成员',
    );
    if (!mounted || !confirmed) {
      return;
    }
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
      if (!mounted) {
        return;
      }
      widget.onChanged?.call();
      final displayName = member.displayName ?? member.email;
      final message = result.status == 'disabled'
          ? '已停用 $displayName；已结束 ${result.endedScopeCount + result.endedAssignmentCount} 条教学关系。'
          : '已恢复 $displayName 的机构访问；历史教学关系未自动恢复，请重新配置。';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
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
    final teacherScopeError = organizationTeacherSubjectScopeErrorMessage(
      error,
    );
    if (teacherScopeError != null) {
      return teacherScopeError;
    }
    final subjectSetupError = organizationSubjectSetupErrorMessage(error);
    if (subjectSetupError != null) {
      return subjectSetupError;
    }
    final setupError = organizationStudentSetupErrorMessage(error);
    if (setupError != null) {
      return setupError;
    }
    final lifecycleError = organizationStudentLifecycleErrorMessage(error);
    if (lifecycleError != null) {
      return lifecycleError;
    }
    final memberLifecycleError = organizationMemberLifecycleErrorMessage(error);
    if (memberLifecycleError != null) {
      return memberLifecycleError;
    }
    final invitationError = organizationInvitationErrorMessage(error);
    if (invitationError != null) {
      return invitationError;
    }
    if (error is AuthException && error.message.trim().isNotEmpty) {
      return '操作未完成：${error.message.trim()}';
    }
    return '操作未完成，请检查网络和账号状态后重试。';
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
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _addTeacherScope,
                    icon: const Icon(Icons.rule_outlined),
                    label: const Text('配置教学范围'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _addSubject,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('添加学科'),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _addStudent,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('添加学生'),
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
                    onEditStudent: _editStudent,
                    onToggleMemberStatus: _toggleMemberStatus,
                    onAddTeacherScope: _addTeacherScope,
                    onToggleTeacherScope: _toggleTeacherScope,
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
    required this.students,
    required this.setupOptions,
    required this.subjectCatalog,
    required this.teacherSubjectScopes,
  });

  final List<OrganizationMember> members;
  final List<OrganizationInvitation> invitations;
  final List<OrganizationStudentRecord> students;
  final OrganizationSetupOptions setupOptions;
  final List<OrganizationSubjectCatalogItem> subjectCatalog;
  final List<OrganizationTeacherSubjectScope> teacherSubjectScopes;
}

class _ManagementContent extends StatelessWidget {
  const _ManagementContent({
    required this.snapshot,
    required this.isOwner,
    required this.busy,
    required this.onApprove,
    required this.onRevoke,
    required this.onEditStudent,
    required this.onToggleMemberStatus,
    required this.onAddTeacherScope,
    required this.onToggleTeacherScope,
  });

  final _OrganizationManagementSnapshot snapshot;
  final bool isOwner;
  final bool busy;
  final Future<void> Function(OrganizationInvitation invitation) onApprove;
  final Future<void> Function(OrganizationInvitation invitation) onRevoke;
  final Future<void> Function(OrganizationStudentRecord student) onEditStudent;
  final Future<void> Function(OrganizationMember member) onToggleMemberStatus;
  final VoidCallback onAddTeacherScope;
  final Future<void> Function(OrganizationTeacherSubjectScope scope)
  onToggleTeacherScope;

  @override
  Widget build(BuildContext context) {
    final pendingApprovals = snapshot.invitations
        .where((invitation) => invitation.isAwaitingOwnerApproval)
        .length;
    final activeTeacherScopeCount = snapshot.teacherSubjectScopes
        .where((scope) => scope.isActive)
        .length;
    final latestEndedScopeIds = _latestEndedTeacherScopeIds(
      snapshot.teacherSubjectScopes,
    );
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
            _ManagementSummaryCard(
              icon: Icons.menu_book_outlined,
              label: '可用学科',
              value: snapshot.setupOptions.subjects.length.toString(),
            ),
            _ManagementSummaryCard(
              icon: Icons.add_circle_outline,
              label: '可添加学科',
              value: snapshot.subjectCatalog.length.toString(),
            ),
            _ManagementSummaryCard(
              icon: Icons.assignment_ind_outlined,
              label: '可分配老师',
              value: '${snapshot.setupOptions.teachers.length}',
            ),
            if (pendingApprovals > 0)
              _ManagementSummaryCard(
                icon: Icons.approval_outlined,
                label: '待负责人审批',
                value: '$pendingApprovals',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ManagementSetupHint(
          options: snapshot.setupOptions,
          subjectCatalog: snapshot.subjectCatalog,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ManagementSection(
          title: '教师教学范围',
          count: '$activeTeacherScopeCount 条有效',
          child: snapshot.teacherSubjectScopes.isEmpty
              ? _ManagementEmptyState(
                  title: '还没有教师教学范围',
                  message: '给在岗老师配置可教学科；停用范围前必须先完成现有关系交接。',
                  icon: Icons.rule_outlined,
                  action: TextButton.icon(
                    onPressed: busy ? null : onAddTeacherScope,
                    icon: const Icon(Icons.add),
                    label: const Text('配置第一条'),
                  ),
                )
              : Column(
                  children: [
                    for (final scope in snapshot.teacherSubjectScopes)
                      _TeacherSubjectScopeTile(
                        scope: scope,
                        busy: busy,
                        showReactivate: latestEndedScopeIds.contains(
                          scope.scopeId,
                        ),
                        onToggle: () => onToggleTeacherScope(scope),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ManagementSection(
          title: '学生',
          count: '${snapshot.students.length} 人',
          child: snapshot.students.isEmpty
              ? const _ManagementEmptyState(
                  title: '还没有学生档案',
                  message: '添加第一位学生后，管理员可以在这里维护身份和教学可见状态。',
                  icon: Icons.school_outlined,
                )
              : Column(
                  children: [
                    for (final student in snapshot.students)
                      _OrganizationStudentTile(
                        student: student,
                        busy: busy,
                        onEdit: student.isMerged
                            ? null
                            : () => onEditStudent(student),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ManagementSection(
          title: '学科',
          count: '${snapshot.setupOptions.subjects.length} 门',
          child: snapshot.setupOptions.subjects.isEmpty
              ? _ManagementEmptyState(
                  title: '还没有机构学科',
                  message: snapshot.subjectCatalog.isEmpty
                      ? '当前没有可添加的全局活跃学科。'
                      : '使用“添加学科”把全局活跃学科加入本机构。',
                  icon: Icons.menu_book_outlined,
                )
              : Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final subject in snapshot.setupOptions.subjects)
                      Chip(label: Text(subject.displayName)),
                  ],
                ),
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
                      _MemberTile(
                        member: member,
                        busy: busy,
                        onToggleStatus: () => onToggleMemberStatus(member),
                      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final action = scope.isActive
        ? TextButton.icon(
            onPressed: busy ? null : onToggle,
            icon: const Icon(Icons.pause_circle_outline, size: 18),
            label: const Text('停用教学范围'),
          )
        : showReactivate && scope.membershipStatus == 'active'
        ? TextButton.icon(
            onPressed: busy ? null : onToggle,
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('重新启用'),
          )
        : null;
    final period = scope.isActive
        ? '生效于 ${_formatDateOnly(scope.activeFrom)}'
        : '结束于 ${_formatDateOnly(scope.activeTo)}';
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
            backgroundColor: scope.isActive
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            foregroundColor: scope.isActive
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
            child: Icon(
              scope.isActive ? Icons.rule_outlined : Icons.history_outlined,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${scope.teacherName} · ${scope.subjectName}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  scope.teacherEmail.isEmpty
                      ? '学科代码：${scope.subjectCode}'
                      : '${scope.teacherEmail} · 学科代码：${scope.subjectCode}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    _ManagementStatusChip(
                      label: _teacherScopeStatusLabel(scope.status),
                      isPositive: scope.isActive,
                    ),
                    _ManagementStatusChip(
                      label: _membershipStatusLabel(scope.membershipStatus),
                      isPositive: scope.membershipStatus == 'active',
                    ),
                    _ManagementRoleChip(label: '版本 ${scope.version}'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(period, style: Theme.of(context).textTheme.bodySmall),
                if (!scope.isActive && scope.membershipStatus != 'active') ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '成员已停用；恢复成员后才能重新配置教学范围。',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(alignment: Alignment.centerLeft, child: action),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationStudentTile extends StatelessWidget {
  const _OrganizationStudentTile({
    required this.student,
    required this.busy,
    required this.onEdit,
  });

  final OrganizationStudentRecord student;
  final bool busy;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final details = <String>[
      if (student.studentCode != null) '编号 ${student.studentCode}',
      if (student.grade != null) student.grade!,
      if (student.className != null) student.className!,
      if (student.campus != null) student.campus!,
    ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: const Icon(Icons.school_outlined, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  student.studentName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('编辑'),
                ),
            ],
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
          if (student.subjectNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '学科：${student.subjectNames.join('、')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.busy,
    required this.onToggleStatus,
  });

  final OrganizationMember member;
  final bool busy;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = member.displayName ?? member.email;
    final initials = displayName.trim().isEmpty
        ? '·'
        : String.fromCharCode(displayName.trim().runes.first).toUpperCase();
    final statusAction = member.status == 'disabled' ? '恢复成员' : '停用成员';
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
                if (member.onboardingExpiresAt != null &&
                    member.status == 'onboarding') ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '接管有效期至 ${_formatDateTime(member.onboardingExpiresAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: busy ? null : onToggleStatus,
                    icon: Icon(
                      member.status == 'disabled'
                          ? Icons.restore_outlined
                          : Icons.person_off_outlined,
                      size: 18,
                    ),
                    label: Text(statusAction),
                  ),
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

class _ManagementSetupHint extends StatelessWidget {
  const _ManagementSetupHint({
    required this.options,
    required this.subjectCatalog,
  });

  final OrganizationSetupOptions options;
  final List<OrganizationSubjectCatalogItem> subjectCatalog;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ready = options.canCreateStudent;
    final message = ready
        ? '学科和负责老师已就绪；添加学生时会一次性完成最小教学关系配置。'
        : options.subjects.isEmpty && subjectCatalog.isNotEmpty
        ? '请先添加至少一个机构学科；当前有 ${subjectCatalog.length} 个全局活跃学科可选。'
        : '添加学生前，请先确保机构至少有一个活跃学科和一个在岗老师角色。';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: ready
            ? colorScheme.primaryContainer.withValues(alpha: 0.45)
            : colorScheme.surfaceContainerHigh,
        border: Border.all(
          color: ready
              ? colorScheme.primary.withValues(alpha: 0.35)
              : colorScheme.outlineVariant,
        ),
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
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
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
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

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

String _teacherScopeKey(String membershipId, String subjectId) =>
    '$membershipId|$subjectId';

Set<String> _latestEndedTeacherScopeIds(
  List<OrganizationTeacherSubjectScope> scopes,
) {
  final latestByKey = <String, OrganizationTeacherSubjectScope>{};
  for (final scope in scopes) {
    if (!scope.isEnded || scope.membershipStatus != 'active') {
      continue;
    }
    final key = _teacherScopeKey(
      scope.membershipId,
      scope.organizationSubjectId,
    );
    final current = latestByKey[key];
    if (current == null ||
        (scope.activeTo != null &&
            (current.activeTo == null ||
                !scope.activeTo!.isBefore(current.activeTo!))) ||
        (scope.activeTo == current.activeTo &&
            scope.scopeId.compareTo(current.scopeId) > 0)) {
      latestByKey[key] = scope;
    }
  }
  return latestByKey.values.map((scope) => scope.scopeId).toSet();
}

String _teacherScopeStatusLabel(String status) {
  return switch (status) {
    'active' => '有效',
    'ended' => '已结束',
    _ => '状态未知',
  };
}

String _formatDateOnly(DateTime? value) {
  if (value == null) {
    return '—';
  }
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
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

String _studentStatusLabel(String status) {
  return switch (status) {
    'active' => '正常教学',
    'inactive' => '暂不教学',
    'archived' => '已归档',
    'merged' => '已合并',
    _ => '状态未知',
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
