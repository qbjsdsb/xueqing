part of 'organization_management_page.dart';

mixin _OrganizationManagementCore on State<OrganizationManagementPage> {
  late Future<_OrganizationManagementSnapshot> _snapshotFuture;
  bool _busy = false;
  String? _errorMessage;

  bool get _isOwner => widget.roles.contains('org_owner');
  bool get _isAdmin => widget.roles.contains('org_admin');

  List<OrganizationInvitationRole> get _inviteRoles {
    if (_isOwner) {
      return const <OrganizationInvitationRole>[
        OrganizationInvitationRole.owner,
        OrganizationInvitationRole.admin,
        OrganizationInvitationRole.teacher,
      ];
    }
    if (_isAdmin) {
      return const <OrganizationInvitationRole>[
        OrganizationInvitationRole.owner,
        OrganizationInvitationRole.teacher,
      ];
    }
    return const <OrganizationInvitationRole>[];
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
      widget.repository.listStudentTeacherAssignments(
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
      studentTeacherAssignments:
          result[6] as List<OrganizationStudentTeacherAssignment>,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    if (!mounted) return;
    setState(() => _snapshotFuture = next);
    await next;
  }

  void _retryLoad() {
    setState(() {
      _errorMessage = null;
      _snapshotFuture = _load();
    });
  }

  Future<void> _runMutation(
    Future<Object?> Function() mutation,
    String successMessage, {
    bool busyAlreadySet = false,
  }) async {
    if (_busy && !busyAlreadySet) return;
    if (!busyAlreadySet) {
      setState(() {
        _busy = true;
        _errorMessage = null;
      });
    }
    try {
      await mutation();
      await _refresh();
      if (mounted) {
        widget.onChanged?.call();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (!busyAlreadySet && mounted) setState(() => _busy = false);
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

  String? _memberAccountBoundaryMessage(Object error) {
    final detail = switch (error) {
      OrganizationMemberProvisioningException(:final code) => code,
      PostgrestException(:final message) => message.trim(),
      AuthException(:final message) => message.trim(),
      _ => null,
    };
    if (detail == null) return null;
    return switch (detail.toLowerCase()) {
      'organization_owner_required' =>
        '这项成员账号操作需要负责人处理；管理员可以处理老师账号，但不能直接管理负责人或管理员账号。',
      'user_already_member_elsewhere' =>
        '这个登录账号已经加入其他机构。当前版本一个账号只能属于一个机构，请换一个邮箱邀请。',
      _ => null,
    };
  }

  String _describeError(Object error) {
    final memberBoundaryError = _memberAccountBoundaryMessage(error);
    if (memberBoundaryError != null) return memberBoundaryError;
    final assignmentError = organizationStudentTeacherAssignmentErrorMessage(
      error,
    );
    if (assignmentError != null) return assignmentError;
    final teacherScopeError = organizationTeacherSubjectScopeErrorMessage(
      error,
    );
    if (teacherScopeError != null) return teacherScopeError;
    final subjectSetupError = organizationSubjectSetupErrorMessage(error);
    if (subjectSetupError != null) return subjectSetupError;
    final setupError = organizationStudentSetupErrorMessage(error);
    if (setupError != null) return setupError;
    final lifecycleError = organizationStudentLifecycleErrorMessage(error);
    if (lifecycleError != null) return lifecycleError;
    final memberLifecycleError = organizationMemberLifecycleErrorMessage(error);
    if (memberLifecycleError != null) return memberLifecycleError;
    final provisioningError = organizationMemberProvisioningErrorMessage(error);
    if (provisioningError != null) return provisioningError;
    final invitationError = organizationInvitationErrorMessage(error);
    if (invitationError != null) return invitationError;
    if (error is AuthException && error.message.trim().isNotEmpty) {
      return '操作未完成：${error.message.trim()}';
    }
    return '操作未完成，请检查网络和账号状态后重试。';
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
    required this.studentTeacherAssignments,
  });

  final List<OrganizationMember> members;
  final List<OrganizationInvitation> invitations;
  final List<OrganizationStudentRecord> students;
  final OrganizationSetupOptions setupOptions;
  final List<OrganizationSubjectCatalogItem> subjectCatalog;
  final List<OrganizationTeacherSubjectScope> teacherSubjectScopes;
  final List<OrganizationStudentTeacherAssignment> studentTeacherAssignments;
}
