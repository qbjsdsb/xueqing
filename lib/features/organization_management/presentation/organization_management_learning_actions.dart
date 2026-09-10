part of 'organization_management_page.dart';

mixin _OrganizationManagementLearningActions on _OrganizationManagementCore {
  Future<void> _exportStudentRecords() async {
    if (_busy) return;
    final repository = widget.studentLearningRecordRepository;
    if (repository == null) return;

    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) return;
      final hasExportableProfile = snapshot.students.any(
        (student) =>
            student.isActive &&
            !student.isMerged &&
            student.subjectServices.any((service) => service.isActive),
      );
      if (!hasExportableProfile) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('当前没有可导出的学生学科记录。')));
        return;
      }

      final selection =
          await showDialog<OrganizationStudentRecordExportSelection>(
            context: context,
            builder: (context) => OrganizationStudentRecordExportDialog(
              students: snapshot.students,
            ),
          );
      if (!mounted || selection == null || selection.profiles.isEmpty) return;

      setState(() {
        _busy = true;
        _errorMessage = null;
      });

      final records = <StudentLearningRecord>[];
      const requestBatchSize = 4;
      for (
        var start = 0;
        start < selection.profiles.length;
        start += requestBatchSize
      ) {
        final end = (start + requestBatchSize).clamp(
          0,
          selection.profiles.length,
        );
        final batch = selection.profiles.sublist(start, end);
        final batchRecords = await Future.wait([
          for (final profile in batch)
            repository.listStudentSubjectRecords(profileId: profile.profileId),
        ]);
        for (final profileRecords in batchRecords) {
          records.addAll(profileRecords);
        }
      }
      if (!mounted) return;
      if (records.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('所选学生和学科还没有可导出的学情记录。')));
        return;
      }

      final rows = LearningRecordExport.rowsForStudentRecords(records);
      final preparedRows =
          await LearningRecordExport.prepareRowsWithAttachmentImages(
            rows: rows,
            repository: widget.evidenceAttachmentRepository,
          );
      final savedPath = await LearningRecordExport.saveAsXlsx(
        fileNameWithoutExtension: LearningRecordExport.studentBatchFileName(
          studentCount: selection.studentCount,
          profileCount: selection.profiles.length,
        ),
        rows: preparedRows,
      );
      if (!mounted) return;
      if (savedPath == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已取消导出。')));
      } else {
        showLearningRecordExportSuccess(
          context,
          savedPath: savedPath,
          summary:
              '已导出 ${selection.studentCount} 名学生、${selection.profiles.length} 个学科的学情记录',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            learningRecordImageExportErrorMessage(error) ??
            studentLearningRecordExportErrorMessage(error) ??
            '导出失败，请检查网络和账号状态后重试。';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportTeacherRecords() async {
    if (_busy) return;
    final repository = widget.teacherLearningRecordRepository;
    if (repository == null) return;

    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) return;
      final teachers =
          snapshot.members
              .where((member) => member.roles.contains('teacher'))
              .toList(growable: false)
            ..sort(
              (left, right) =>
                  _teacherExportName(left).compareTo(_teacherExportName(right)),
            );
      if (teachers.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('当前没有可导出的老师记录。')));
        return;
      }

      final teacher = await showDialog<OrganizationMember>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('选择要导出的老师'),
          children: [
            for (final member in teachers)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(member),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _teacherExportName(member),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        member.email,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
      if (!mounted || teacher == null) return;

      setState(() {
        _busy = true;
        _errorMessage = null;
      });
      final records = await repository.listTeacherRecords(
        organizationId: widget.organizationId,
        membershipId: teacher.membershipId,
      );
      if (!mounted) return;
      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_teacherExportName(teacher)} 还没有可导出的教学记录。'),
          ),
        );
        return;
      }

      final teacherName = _teacherExportName(teacher);
      final rows = LearningRecordExport.rowsForTeacherRecords(
        records,
        teacherName: teacherName,
      );
      final preparedRows =
          await LearningRecordExport.prepareRowsWithAttachmentImages(
            rows: rows,
            repository: widget.evidenceAttachmentRepository,
          );
      final savedPath = await LearningRecordExport.saveAsXlsx(
        fileNameWithoutExtension: LearningRecordExport.teacherFileName(
          teacherName,
        ),
        rows: preparedRows,
      );
      if (!mounted) return;
      if (savedPath == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已取消导出。')));
      } else {
        showLearningRecordExportSuccess(
          context,
          savedPath: savedPath,
          summary: '$teacherName 的教学记录已导出',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            learningRecordImageExportErrorMessage(error) ??
            teacherLearningRecordExportErrorMessage(error) ??
            '导出失败，请检查网络和账号状态后重试。';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _teacherExportName(OrganizationMember member) {
    final displayName = member.displayName?.trim() ?? '';
    if (displayName.isNotEmpty &&
        displayName.toLowerCase() != member.email.trim().toLowerCase()) {
      return displayName;
    }
    return member.email.trim().isEmpty ? '未命名老师' : member.email.trim();
  }

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

  Future<void> _addStudentSubject(OrganizationStudentRecord student) async {
    if (_busy || !student.isActive) return;
    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) return;

      final existingSubjectIds = <String>{
        for (final assignment in snapshot.studentTeacherAssignments)
          if (assignment.studentId == student.studentId)
            assignment.organizationSubjectId,
      };
      final availableSubjects = <OrganizationSetupSubject>[
        for (final subject
            in snapshot.setupOptions.subjectsWithAvailableTeachers)
          if (!existingSubjectIds.contains(subject.id)) subject,
      ];
      if (availableSubjects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('这个学生暂时没有可新增的学科；已有或历史学科不会重复建档。')),
        );
        return;
      }

      final draft = await showDialog<OrganizationStudentSubjectSetupDraft>(
        context: context,
        builder: (context) => OrganizationStudentSubjectSetupDialog(
          student: student,
          subjects: availableSubjects,
          teachers: snapshot.setupOptions.teachers,
        ),
      );
      if (!mounted || draft == null) return;

      await _runMutation(
        () => widget.repository.addStudentSubject(
          operationId: draft.operationId,
          organizationId: widget.organizationId,
          studentId: draft.studentId,
          organizationSubjectId: draft.organizationSubjectId,
          teacherMembershipId: draft.teacherMembershipId,
        ),
        '已为 ${student.studentName} 增加 ${draft.subjectName} · ${draft.teacherName} 负责。',
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    }
  }

  Future<void> _toggleStudentSubjectService(
    OrganizationStudentRecord student,
    OrganizationStudentSubjectService service,
  ) async {
    if (_busy || service.isArchived) return;

    if (service.isActive) {
      final confirmed = await _confirm(
        title: '结束 ${student.studentName} · ${service.subjectName}？',
        message: '历史学情、证据和已结束记录都会保留。系统不会自动关闭问题或行动；如果仍有未关闭 Case 或待执行行动，本次结束会被拒绝并提示先完成闭环。',
        confirmLabel: '确认结束',
      );
      if (!mounted || !confirmed) return;
      await _runMutation(
        () => widget.repository.endStudentSubjectService(
          operationId: createOperationId(),
          organizationId: widget.organizationId,
          studentSubjectProfileId: service.profileId,
          expectedProfileVersion: service.version,
        ),
        '已结束 ${student.studentName} 的 ${service.subjectName} 学科服务。',
      );
      return;
    }

    if (!service.isInactive) return;
    if (!student.isActive) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('先把学生恢复为正常教学状态，再恢复具体学科。')));
      return;
    }

    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) return;
      final teachers = snapshot.setupOptions.teachersForSubject(
        service.organizationSubjectId,
      );
      if (teachers.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前没有在岗且具备该学科有效教学范围的老师。')));
        return;
      }
      final teacher = await showDialog<OrganizationSetupTeacher>(
        context: context,
        builder: (context) => OrganizationStudentSubjectRestoreDialog(
          student: student,
          service: service,
          teachers: teachers,
        ),
      );
      if (!mounted || teacher == null) return;
      await _runMutation(
        () => widget.repository.restoreStudentSubjectService(
          operationId: createOperationId(),
          organizationId: widget.organizationId,
          studentSubjectProfileId: service.profileId,
          expectedProfileVersion: service.version,
          teacherMembershipId: teacher.membershipId,
        ),
        '已恢复 ${student.studentName} 的 ${service.subjectName} · ${teacher.displayName} 负责。',
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    }
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

  Future<void> _toggleStudentTeaching(OrganizationStudentRecord student) async {
    if (_busy || student.isMerged) return;
    final pausing = student.isActive;
    if (!pausing && student.status != 'inactive') return;

    final confirmed = await _confirm(
      title: pausing
          ? '暂停 ${student.studentName} 的教学？'
          : '恢复 ${student.studentName} 的教学？',
      message: pausing
          ? '暂停后，这位学生会暂时从老师工作台和今日事项中隐藏；学科档案、当前任课、跟进问题、证据和待办都会原样保留，恢复后继续原来的教学上下文。'
          : '恢复后，这位学生会重新出现在有当前任课关系的老师工作台中；原学科、跟进问题、证据和待办继续有效，不会重新建档。',
      confirmLabel: pausing ? '确认暂停' : '确认恢复',
    );
    if (!mounted || !confirmed) return;

    await _runMutation(
      () => pausing
          ? widget.repository.pauseStudentTeaching(
              operationId: createOperationId(),
              organizationId: widget.organizationId,
              studentId: student.studentId,
              expectedStudentVersion: student.version,
            )
          : widget.repository.resumeStudentTeaching(
              operationId: createOperationId(),
              organizationId: widget.organizationId,
              studentId: student.studentId,
              expectedStudentVersion: student.version,
            ),
      pausing
          ? '已暂停 ${student.studentName} 的教学；历史和待跟进内容均已保留。'
          : '已恢复 ${student.studentName} 的教学。',
    );
  }

  Future<void> _toggleStudentArchive(OrganizationStudentRecord student) async {
    if (_busy || student.isMerged) return;
    final archiving = student.status == 'inactive';
    final unarchiving = student.status == 'archived';
    if (!archiving && !unarchiving) return;

    if (archiving &&
        student.subjectServices.any((service) => service.isActive)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '这位学生仍有进行中的学科服务；如果只是暂时停课，请保持“暂不教学”。长期离开机构时，请先逐科完成结束再归档。',
          ),
        ),
      );
      return;
    }

    final confirmed = await _confirm(
      title: archiving
          ? '归档 ${student.studentName}？'
          : '取消归档 ${student.studentName}？',
      message: archiving
          ? '归档用于学生长期结束服务或离开机构后的历史保留。已有学科、跟进问题、证据和历史记录不会删除；若只是暂时停课，请不要归档。'
          : '取消归档只把学生恢复为“暂不教学”，不会自动恢复老师工作台，也不会自动恢复已经结束的学科。需要继续教学时，再明确执行恢复教学和相应学科恢复。',
      confirmLabel: archiving ? '确认归档' : '确认取消归档',
    );
    if (!mounted || !confirmed) return;

    await _runMutation(
      () => widget.repository.updateStudent(
        operationId: createOperationId(),
        organizationId: widget.organizationId,
        studentId: student.studentId,
        expectedStudentVersion: student.version,
        name: student.studentName,
        studentCode: student.studentCode,
        status: archiving ? 'archived' : 'inactive',
      ),
      archiving
          ? '已归档 ${student.studentName}；历史记录已保留。'
          : '已取消归档 ${student.studentName}；当前为暂不教学。',
    );
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
            status: student.status,
          ),
        ),
      );
      if (!mounted || result == null) return;
      await _refresh();
      if (!mounted) return;
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已更新 ${result.studentName} 的基本信息。')),
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
