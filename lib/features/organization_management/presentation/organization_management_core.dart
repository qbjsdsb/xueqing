part of 'organization_management_page.dart';

mixin _OrganizationManagementCore on State<OrganizationManagementPage> {
  late Future<_OrganizationManagementSnapshot> _snapshotFuture;
  bool _busy = false;
  bool _manualRefreshing = false;
  String? _errorMessage;

  bool get _isOwner => widget.roles.contains('org_owner');

  List<OrganizationInvitationRole> get _inviteRoles {
    if (_isOwner) {
      return const <OrganizationInvitationRole>[
        OrganizationInvitationRole.owner,
        OrganizationInvitationRole.admin,
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
    final snapshot = await _load();
    if (!mounted) return;
    setState(() {
      _snapshotFuture = Future<_OrganizationManagementSnapshot>.value(snapshot);
    });
  }

  Future<void> _manualRefresh() async {
    if (_manualRefreshing || _busy) return;
    setState(() {
      _manualRefreshing = true;
      _errorMessage = null;
    });
    try {
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (mounted) setState(() => _manualRefreshing = false);
    }
  }

  void _retryLoad() {
    setState(() {
      _errorMessage = null;
      _snapshotFuture = _load();
    });
  }

  Future<void> _finishCommittedMutation({String? successMessage}) async {
    var refreshFailed = false;
    try {
      await _refresh();
    } catch (_) {
      refreshFailed = true;
    }
    if (!mounted) return;

    // The server write is already authoritative at this point. A parent
    // workspace reload is best-effort only and must never turn a committed
    // teaching fact into a false "operation failed" message.
    try {
      widget.onChanged?.call();
    } catch (_) {
      refreshFailed = true;
    }
    if (!mounted) return;

    final normalizedSuccess = successMessage?.trim();
    if (refreshFailed) {
      final prefix = normalizedSuccess == null || normalizedSuccess.isEmpty
          ? '操作已经保存。'
          : normalizedSuccess;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            '$prefix\n最新列表暂时没有刷新成功。请刷新页面确认，不要重复提交。',
          ),
        ),
      );
      return;
    }

    if (normalizedSuccess != null && normalizedSuccess.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(normalizedSuccess)));
    }
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
      await _finishCommittedMutation(successMessage: successMessage);
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

  String? _memberFlowError(Object error) {
    final detail = switch (error) {
      OrganizationMemberProvisioningException(:final code) => code,
      AuthException(:final message) => message,
      PostgrestException(:final message) => message,
      _ => null,
    };
    if (detail == null) return null;
    final normalized = detail.trim().toLowerCase();
    if (normalized.contains('user_already_member_elsewhere')) {
      return '这个登录账号已经加入其他机构；当前版本一个账号只能属于一个机构，请换用尚未加入其他机构的邮箱。';
    }
    if (normalized.contains('organization_owner_required')) {
      return _isOwner
          ? '当前负责人权限状态可能刚刚发生变化，请先刷新；如果仍失败，请退出后重新登录再试。'
          : '这项成员账号操作需要负责人处理。';
    }
    return null;
  }

  String _describeError(Object error) {
    final memberFlowError = _memberFlowError(error);
    if (memberFlowError != null) return memberFlowError;
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
    final subjectLifecycleError =
        organizationStudentSubjectLifecycleErrorMessage(error);
    if (subjectLifecycleError != null) return subjectLifecycleError;
    final setupError = organizationStudentSetupErrorMessage(error);
    if (setupError != null) return setupError;
    final teachingLifecycleError =
        organizationStudentTeachingLifecycleErrorMessage(error);
    if (teachingLifecycleError != null) return teachingLifecycleError;
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
