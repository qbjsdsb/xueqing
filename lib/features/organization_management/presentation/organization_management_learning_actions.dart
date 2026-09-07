part of 'organization_management_page.dart';

mixin _OrganizationManagementLearningActions on _OrganizationManagementCore {
  Future<void> _addSubject() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) return;
      if (snapshot.subjectCatalog.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('当前没有可添加的活跃学科。')));
        return;
      }
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
      if (!mounted || result == null) return;
      await _refresh();
      if (!mounted) return;
      widget.onChanged?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已添加学科：${result.subjectName}。')));
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addTeacherScope() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) return;
      final teachers = snapshot.setupOptions.teachers;
      final subjects = snapshot.setupOptions.subjects;
      if (teachers.isEmpty || subjects.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先准备至少一位在岗老师和一个机构学科。')));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('目前所有老师与学科组合都已配置。')));
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
      if (!mounted || draft == null) return;
      await _runMutation(
        () => widget.repository.updateTeacherSubjectScope(
          operationId: draft.operationId,
          organizationId: widget.organizationId,
          membershipId: draft.membershipId,
          organizationSubjectId: draft.organizationSubjectId,
          status: 'active',
        ),
        '已为 ${draft.teacherName} 配置 ${draft.subjectName}。',
        busyAlreadySet: true,
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleTeacherScope(
    OrganizationTeacherSubjectScope scope,
  ) async {
    if (_busy) return;
    final ending = scope.isActive;
    if (!ending && scope.membershipStatus != 'active') {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('成员恢复后才能重新启用可教学科。')));
      return;
    }
    final confirmed = await _confirm(
      title: ending ? '停用这门可教学科？' : '重新启用这门可教学科？',
      message: ending
          ? '停用前需要确保相关学生、开放问题和待办已经完成必要交接；系统不会自动改写历史记录。'
          : '重新启用只恢复新的教学授权，不会自动恢复历史学生任课关系。',
      confirmLabel: ending ? '确认停用' : '重新启用',
    );
    if (!mounted || !confirmed) return;
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
          ? '已停用 ${scope.teacherName} 的 ${scope.subjectName}。'
          : '已重新启用 ${scope.teacherName} 的 ${scope.subjectName}。',
    );
  }

  Future<void> _transferStudentTeacherAssignment(
    OrganizationStudentTeacherAssignment assignment,
  ) async {
    if (_busy) return;
    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) return;
      final activeScopeKeys = <String>{
        for (final scope in snapshot.teacherSubjectScopes)
          if (scope.isActive && scope.membershipStatus == 'active')
            _teacherScopeKey(scope.membershipId, scope.organizationSubjectId),
      };
      final candidates = <OrganizationSetupTeacher>[
        for (final teacher in snapshot.setupOptions.teachers)
          if (teacher.membershipId != assignment.membershipId &&
              activeScopeKeys.contains(
                _teacherScopeKey(
                  teacher.membershipId,
                  assignment.organizationSubjectId,
                ),
              ))
            teacher,
      ];
      if (candidates.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前没有具备该学科有效授权的在岗接收老师。')));
        return;
      }
      final draft =
          await showDialog<OrganizationStudentTeacherAssignmentTransferDraft>(
            context: context,
            builder: (context) =>
                OrganizationStudentTeacherAssignmentTransferDialog(
                  assignment: assignment,
                  candidates: candidates,
                ),
          );
      if (!mounted || draft == null) return;
      await _runMutation(
        () => widget.repository.transferStudentTeacherAssignment(
          operationId: draft.operationId,
          organizationId: widget.organizationId,
          assignmentId: assignment.assignmentId,
          expectedAssignmentVersion: assignment.version,
          replacementMembershipId: draft.replacementMembershipId,
        ),
        '已将 ${assignment.studentName} 的 ${assignment.subjectName} '
        '${_studentAssignmentRoleLabel(assignment.assignmentRole)}交接给 '
        '${draft.replacementTeacherName}。',
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    }
  }

  Future<void> _addStudent() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) return;
      if (!snapshot.setupOptions.canCreateStudent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('添加学生前，请先配置学科和负责老师的可教学科。')),
        );
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
      if (!mounted || result == null) return;
      await _refresh();
      if (!mounted) return;
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
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editStudent(OrganizationStudentRecord student) async {
    if (_busy) return;
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
      if (!mounted || result == null) return;
      await _refresh();
      if (!mounted) return;
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已更新 ${result.studentName} · ${_studentStatusLabel(result.status)}。',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
