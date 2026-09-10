part of 'organization_management_page.dart';

enum _ManagementArea { people, students, settings }

enum _ManagementExportMode { students, teacher }

class _ManagementOverview extends StatefulWidget {
  const _ManagementOverview({
    required this.snapshot,
    required this.isOwner,
    required this.busy,
    required this.canInvite,
    required this.canEditMemberName,
    required this.onAddStudent,
    required this.onAddStudentSubject,
    required this.onToggleStudentSubjectService,
    required this.onToggleStudentTeaching,
    required this.onToggleStudentArchive,
    required this.onInviteMember,
    required this.onApprove,
    required this.onRevoke,
    required this.onEditStudent,
    required this.onToggleMemberStatus,
    required this.onAddSubject,
    required this.onAddTeacherScope,
    required this.onToggleTeacherScope,
    required this.onTransferStudentTeacherAssignment,
    required this.canManageCaseTypes,
    this.onProvisionInvitation,
    this.onExportTeacherRecords,
    this.onExportStudentRecords,
    this.onEditMemberName,
    this.onReissueMemberCredential,
    this.onOpenCaseTypes,
  });

  final _OrganizationManagementSnapshot snapshot;
  final bool isOwner;
  final bool busy;
  final bool canInvite;
  final bool canEditMemberName;
  final VoidCallback onAddStudent;
  final Future<void> Function(OrganizationStudentRecord student)
  onAddStudentSubject;
  final Future<void> Function(
    OrganizationStudentRecord student,
    OrganizationStudentSubjectService service,
  )
  onToggleStudentSubjectService;
  final Future<void> Function(OrganizationStudentRecord student)
  onToggleStudentTeaching;
  final Future<void> Function(OrganizationStudentRecord student)
  onToggleStudentArchive;
  final VoidCallback onInviteMember;
  final Future<void> Function()? onExportTeacherRecords;
  final Future<void> Function()? onExportStudentRecords;
  final Future<void> Function(OrganizationInvitation invitation) onApprove;
  final Future<void> Function(OrganizationInvitation invitation) onRevoke;
  final Future<void> Function(OrganizationInvitation invitation)?
  onProvisionInvitation;
  final Future<void> Function(OrganizationMember member)? onEditMemberName;
  final Future<void> Function(OrganizationStudentRecord student) onEditStudent;
  final Future<void> Function(OrganizationMember member) onToggleMemberStatus;
  final Future<void> Function(OrganizationMember member)?
  onReissueMemberCredential;
  final VoidCallback onAddSubject;
  final VoidCallback onAddTeacherScope;
  final Future<void> Function(OrganizationTeacherSubjectScope scope)
  onToggleTeacherScope;
  final Future<void> Function(OrganizationStudentTeacherAssignment assignment)
  onTransferStudentTeacherAssignment;
  final bool canManageCaseTypes;
  final VoidCallback? onOpenCaseTypes;

  @override
  State<_ManagementOverview> createState() => _ManagementOverviewState();
}

class _ManagementOverviewState extends State<_ManagementOverview> {
  static const int _initialStudentLimit = 20;

  late _ManagementArea _selectedArea;
  final TextEditingController _studentSearchController =
      TextEditingController();
  String _studentQuery = '';
  bool _showAllStudents = false;
  bool _showEndedTeacherScopes = false;

  @override
  void initState() {
    super.initState();
    _selectedArea = _initialArea(widget.snapshot);
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }

  void _clearStudentSearch() {
    if (_studentQuery.isEmpty && _studentSearchController.text.isEmpty) {
      return;
    }
    _studentSearchController.clear();
    setState(() {
      _studentQuery = '';
      _showAllStudents = false;
    });
  }

  Future<void> _showExportRecords() async {
    if (widget.busy) return;
    final canExportStudents = widget.onExportStudentRecords != null;
    final canExportTeachers = widget.onExportTeacherRecords != null;
    if (!canExportStudents && !canExportTeachers) return;

    final selection = await showDialog<_ManagementExportMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('导出记录'),
        children: [
          if (canExportStudents)
            SimpleDialogOption(
              key: const Key('management-export-students-option'),
              onPressed: () =>
                  Navigator.of(context).pop(_ManagementExportMode.students),
              child: const ListTile(
                leading: Icon(Icons.school_outlined),
                title: Text('按学生和学科导出'),
                subtitle: Text('可选择多名学生和多个学科，导出完整学情记录'),
              ),
            ),
          if (canExportTeachers)
            SimpleDialogOption(
              key: const Key('management-export-teacher-option'),
              onPressed: () =>
                  Navigator.of(context).pop(_ManagementExportMode.teacher),
              child: const ListTile(
                leading: Icon(Icons.person_outline),
                title: Text('按老师导出'),
                subtitle: Text('选择一位老师，导出其真实记录归属下的全部记录'),
              ),
            ),
        ],
      ),
    );
    if (!mounted || selection == null) return;
    switch (selection) {
      case _ManagementExportMode.students:
        await widget.onExportStudentRecords?.call();
      case _ManagementExportMode.teacher:
        await widget.onExportTeacherRecords?.call();
    }
  }

  Widget? _buildSetupNextStep() {
    final options = widget.snapshot.setupOptions;
    late final String title;
    late final String message;
    late final String actionLabel;
    VoidCallback? action;

    if (options.subjects.isEmpty) {
      title = '先添加机构学科';
      message = '只添加机构实际教授的学科。添加后，再给老师配置可以负责的学科。';
      actionLabel = '添加学科';
      action = widget.onAddSubject;
    } else if (options.teachers.isEmpty) {
      title = '下一步：加入一位老师';
      message = widget.canInvite
          ? '有了老师后，才能配置可教学科并为学生建立负责关系。'
          : '当前还没有可承担教学的老师，请让机构负责人先邀请老师加入。';
      actionLabel = '邀请老师';
      action = widget.canInvite ? widget.onInviteMember : null;
    } else if (!options.canCreateStudent) {
      title = '下一步：配置老师可教学科';
      message = '指定老师可以负责哪些学科后，就可以直接添加学生并安排负责老师。';
      actionLabel = '配置老师学科';
      action = widget.onAddTeacherScope;
    } else if (widget.snapshot.students.isEmpty) {
      title = '准备完成，可以添加第一位学生';
      message = '添加学生时只需要先确定姓名、学科和负责老师，其他资料可以以后补充。';
      actionLabel = '添加第一位学生';
      action = widget.onAddStudent;
    } else {
      return null;
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (action != null)
            FilledButton.tonal(
              key: const Key('management-next-step-action'),
              onPressed: widget.busy ? null : action,
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }

  _ManagementArea _initialArea(_OrganizationManagementSnapshot snapshot) {
    if (snapshot.setupOptions.subjects.isEmpty) {
      return _ManagementArea.settings;
    }
    if (snapshot.invitations.isNotEmpty ||
        !snapshot.setupOptions.canCreateStudent) {
      return _ManagementArea.people;
    }
    return _ManagementArea.students;
  }

  @override
  Widget build(BuildContext context) {
    final activeScopes = widget.snapshot.teacherSubjectScopes
        .where((scope) => scope.isActive)
        .toList(growable: false);
    final endedScopes = widget.snapshot.teacherSubjectScopes
        .where((scope) => !scope.isActive)
        .toList(growable: false);
    final latestEndedScopeIds = _latestEndedTeacherScopeIds(
      widget.snapshot.teacherSubjectScopes,
    );
    final activeAssignments = widget.snapshot.studentTeacherAssignments
        .where((assignment) => assignment.isActive)
        .toList(growable: false);
    final endedAssignments = widget.snapshot.studentTeacherAssignments
        .where((assignment) => !assignment.isActive)
        .toList(growable: false);
    final setupNextStep = _buildSetupNextStep();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (setupNextStep != null) ...[
          setupNextStep,
          const SizedBox(height: AppSpacing.md),
        ],
        _ManagementAreaSwitcher(
          selectedArea: _selectedArea,
          onChanged: (area) {
            if (area == _selectedArea) return;
            setState(() => _selectedArea = area);
          },
        ),
        if (widget.onExportStudentRecords != null ||
            widget.onExportTeacherRecords != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: const Key('management-export-records'),
              onPressed: widget.busy ? null : _showExportRecords,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('导出记录'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        switch (_selectedArea) {
          _ManagementArea.people => _buildPeopleArea(
            activeScopes: activeScopes,
            endedScopes: endedScopes,
            latestEndedScopeIds: latestEndedScopeIds,
          ),
          _ManagementArea.students => _buildStudentsArea(
            activeAssignments: activeAssignments,
            endedAssignments: endedAssignments,
          ),
          _ManagementArea.settings => _buildSettingsArea(),
        },
      ],
    );
  }

  List<List<OrganizationTeacherSubjectScope>> _groupTeacherSubjectScopes(
    List<OrganizationTeacherSubjectScope> scopes,
  ) {
    final grouped = <String, List<OrganizationTeacherSubjectScope>>{};
    for (final scope in scopes) {
      grouped.putIfAbsent(scope.membershipId, () => []).add(scope);
    }
    final groups = grouped.values.toList(growable: false);
    for (final group in groups) {
      group.sort((a, b) => a.subjectName.compareTo(b.subjectName));
    }
    groups.sort((a, b) => a.first.teacherName.compareTo(b.first.teacherName));
    return groups;
  }

  Widget _buildPeopleArea({
    required List<OrganizationTeacherSubjectScope> activeScopes,
    required List<OrganizationTeacherSubjectScope> endedScopes,
    required Set<String> latestEndedScopeIds,
  }) {
    final activeScopeGroups = _groupTeacherSubjectScopes(activeScopes);
    return _ManagementAreaCard(
      icon: Icons.people_outline,
      title: '成员',
      description: widget.isOwner
          ? '管理机构成员、账号状态和老师可教学科。邮箱只用于登录，日常协作优先显示姓名。'
          : '查看机构成员并管理老师可教学科；邀请、停用和账号凭据由负责人处理。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ManagementSection(
            title: '机构成员',
            count: '${widget.snapshot.members.length} 人',
            action: widget.canInvite
                ? FilledButton.tonalIcon(
                    onPressed: widget.busy ? null : widget.onInviteMember,
                    icon: const Icon(Icons.group_add_outlined, size: 18),
                    label: const Text('邀请成员'),
                  )
                : null,
            child: widget.snapshot.members.isEmpty
                ? const _ManagementEmptyState(
                    title: '还没有机构成员',
                    message: '邀请负责人、管理员或老师加入机构。',
                    icon: Icons.people_outline,
                  )
                : Column(
                    children: [
                      for (final member in widget.snapshot.members)
                        _MemberTile(
                          member: member,
                          busy: widget.busy,
                          lifecycleBusy: widget.busy || !widget.isOwner,
                          canEditName: widget.canEditMemberName,
                          onEditName: widget.onEditMemberName == null
                              ? null
                              : () => widget.onEditMemberName!(member),
                          onToggleStatus: () =>
                              widget.onToggleMemberStatus(member),
                          onReissueCredential:
                              widget.onReissueMemberCredential == null
                              ? null
                              : () => widget.onReissueMemberCredential!(member),
                        ),
                    ],
                  ),
          ),
          if (widget.snapshot.invitations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _ManagementSection(
              title: '待处理邀请',
              count: '${widget.snapshot.invitations.length} 条',
              child: Column(
                children: [
                  for (final invitation in widget.snapshot.invitations)
                    _InvitationTile(
                      invitation: invitation,
                      isOwner: widget.isOwner,
                      busy: widget.busy,
                      onApprove: () => widget.onApprove(invitation),
                      onRevoke: () => widget.onRevoke(invitation),
                      onProvision:
                          invitation.isPending &&
                              widget.onProvisionInvitation != null
                          ? () => widget.onProvisionInvitation!(invitation)
                          : null,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _ManagementSection(
            title: '老师可教学科',
            count: '${activeScopeGroups.length} 位老师 · ${activeScopes.length} 科',
            action: TextButton.icon(
              onPressed: widget.busy ? null : widget.onAddTeacherScope,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('配置'),
            ),
            child: activeScopes.isEmpty
                ? const _ManagementEmptyState(
                    title: '还没有有效教学范围',
                    message: '老师加入机构后，再指定其可以负责哪些学科。',
                    icon: Icons.menu_book_outlined,
                  )
                : Column(
                    children: [
                      for (final scopes in activeScopeGroups)
                        _TeacherSubjectScopeGroupTile(
                          scopes: scopes,
                          busy: widget.busy,
                          onToggle: widget.onToggleTeacherScope,
                        ),
                    ],
                  ),
          ),
          if (endedScopes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: () => setState(
                () => _showEndedTeacherScopes = !_showEndedTeacherScopes,
              ),
              icon: Icon(
                _showEndedTeacherScopes
                    ? Icons.expand_less
                    : Icons.history_outlined,
                size: 18,
              ),
              label: Text(
                _showEndedTeacherScopes
                    ? '收起历史教学范围'
                    : '查看历史教学范围（${endedScopes.length}）',
              ),
            ),
            if (_showEndedTeacherScopes)
              Column(
                children: [
                  for (final scope in endedScopes)
                    _TeacherSubjectScopeTile(
                      scope: scope,
                      busy: widget.busy,
                      showReactivate: latestEndedScopeIds.contains(
                        scope.scopeId,
                      ),
                      onToggle: () => widget.onToggleTeacherScope(scope),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentsArea({
    required List<OrganizationStudentTeacherAssignment> activeAssignments,
    required List<OrganizationStudentTeacherAssignment> endedAssignments,
  }) {
    final normalizedQuery = _studentQuery.trim().toLowerCase();
    final filteredStudents = normalizedQuery.isEmpty
        ? widget.snapshot.students
        : widget.snapshot.students
              .where((student) {
                final searchable = <String?>[
                  student.studentName,
                  student.studentCode,
                  student.grade,
                  student.className,
                  student.campus,
                  ...student.subjectNames,
                  ...student.subjectServices.map(
                    (service) => service.subjectName,
                  ),
                  ...activeAssignments
                      .where(
                        (assignment) =>
                            assignment.studentId == student.studentId,
                      )
                      .map((assignment) => assignment.teacherName),
                ].whereType<String>().join(' ').toLowerCase();
                return searchable.contains(normalizedQuery);
              })
              .toList(growable: false);
    final limitStudents =
        normalizedQuery.isEmpty &&
        !_showAllStudents &&
        filteredStudents.length > _initialStudentLimit;
    final visibleStudents = limitStudents
        ? filteredStudents.take(_initialStudentLimit).toList(growable: false)
        : filteredStudents;
    final matchingStudentIds = filteredStudents
        .map((student) => student.studentId)
        .toSet();
    final visibleEndedAssignments = normalizedQuery.isEmpty
        ? endedAssignments
        : endedAssignments
              .where(
                (assignment) =>
                    matchingStudentIds.contains(assignment.studentId),
              )
              .toList(growable: false);

    return _ManagementAreaCard(
      icon: Icons.school_outlined,
      title: '学生',
      description: '学生、学科和当前负责老师都在这里处理；历史任课按需查看。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.snapshot.students.length > 8) ...[
            TextField(
              key: const Key('management-student-search'),
              controller: _studentSearchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜索姓名、编号、年级、班级、校区、学科或老师',
                isDense: true,
                suffixIcon: _studentQuery.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('management-student-search-clear'),
                        tooltip: '清空搜索',
                        onPressed: _clearStudentSearch,
                        icon: const Icon(Icons.close),
                      ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              onChanged: (value) {
                setState(() {
                  _studentQuery = value;
                  _showAllStudents = false;
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _ManagementSection(
            title: '学生档案',
            count: normalizedQuery.isEmpty
                ? '${widget.snapshot.students.length} 人'
                : '${filteredStudents.length} 个结果',
            action: FilledButton.icon(
              onPressed: widget.busy ? null : widget.onAddStudent,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('添加学生'),
            ),
            child: visibleStudents.isEmpty
                ? _ManagementEmptyState(
                    title: normalizedQuery.isEmpty ? '还没有学生档案' : '没有匹配的学生',
                    message: normalizedQuery.isEmpty
                        ? '添加第一位学生后，再围绕具体学科建立教学关系。'
                        : '换一个姓名、编号、年级或学科关键词试试。',
                    icon: Icons.school_outlined,
                  )
                : Column(
                    children: [
                      for (final student in visibleStudents)
                        _OrganizationStudentTile(
                          student: student,
                          busy: widget.busy,
                          activeAssignments: activeAssignments
                              .where(
                                (assignment) =>
                                    assignment.studentId == student.studentId,
                              )
                              .toList(growable: false),
                          onTransferAssignment: (assignment) => widget
                              .onTransferStudentTeacherAssignment(assignment),
                          onAddSubject: student.isActive && !student.isMerged
                              ? () => widget.onAddStudentSubject(student)
                              : null,
                          onToggleSubjectService: student.isMerged
                              ? null
                              : (service) =>
                                    widget.onToggleStudentSubjectService(
                                      student,
                                      service,
                                    ),
                          onToggleTeaching:
                              student.isMerged ||
                                  student.status != 'active' &&
                                      student.status != 'inactive'
                              ? null
                              : () => widget.onToggleStudentTeaching(student),
                          onToggleArchive: student.isMerged
                              ? null
                              : student.status == 'archived' ||
                                    student.status == 'inactive' &&
                                        !student.subjectServices.any(
                                          (service) => service.isActive,
                                        )
                              ? () => widget.onToggleStudentArchive(student)
                              : null,
                          onEdit: student.isMerged
                              ? null
                              : () => widget.onEditStudent(student),
                        ),
                      if (limitStudents)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => _showAllStudents = true),
                            icon: const Icon(Icons.expand_more, size: 18),
                            label: Text('查看全部 ${filteredStudents.length} 位学生'),
                          ),
                        ),
                    ],
                  ),
          ),
          if (visibleEndedAssignments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ExpansionTile(
              key: const PageStorageKey<String>(
                'management-assignment-history',
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_outlined),
              title: Text(
                '历史任课记录',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text('${visibleEndedAssignments.length} 条历史任课'),
              children: [
                for (final assignment in visibleEndedAssignments)
                  _StudentTeacherAssignmentTile(
                    assignment: assignment,
                    busy: widget.busy,
                    onTransfer: null,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsArea() {
    final noSubjects = widget.snapshot.setupOptions.subjects.isEmpty;
    return _ManagementAreaCard(
      icon: Icons.tune_outlined,
      title: '基础设置',
      description: '新增机构学科、维护问题类型和其他必要配置都在这里处理。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ManagementSetupHint(
            options: widget.snapshot.setupOptions,
            subjectCatalog: widget.snapshot.subjectCatalog,
          ),
          const SizedBox(height: AppSpacing.lg),
          _ManagementSection(
            title: '机构学科',
            count: '${widget.snapshot.setupOptions.subjects.length} 门',
            action: noSubjects
                ? FilledButton.tonalIcon(
                    onPressed: widget.busy ? null : widget.onAddSubject,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加学科'),
                  )
                : TextButton.icon(
                    onPressed: widget.busy ? null : widget.onAddSubject,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加学科'),
                  ),
            child: noSubjects
                ? const _ManagementEmptyState(
                    title: '还没有机构学科',
                    message: '只添加本机构实际教授的学科，后续再分配给对应老师。',
                    icon: Icons.menu_book_outlined,
                  )
                : Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final subject
                          in widget.snapshot.setupOptions.subjects)
                        Chip(label: Text(subject.displayName)),
                    ],
                  ),
          ),
          if (widget.canManageCaseTypes && widget.onOpenCaseTypes != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _ManagementSection(
              title: '问题类型',
              count: '学习问题分类',
              action: TextButton.icon(
                onPressed: widget.busy ? null : widget.onOpenCaseTypes,
                icon: const Icon(Icons.category_outlined, size: 18),
                label: const Text('管理'),
              ),
              child: Text(
                '统一常用问题分类，方便老师记录和回看长期变化；不用于给学生贴标签。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
