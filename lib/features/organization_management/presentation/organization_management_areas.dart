part of 'organization_management_page.dart';

enum _ManagementArea { people, students, settings }

class _ManagementOverview extends StatefulWidget {
  const _ManagementOverview({
    required this.snapshot,
    required this.isOwner,
    required this.busy,
    required this.canInvite,
    required this.canEditMemberName,
    required this.onAddStudent,
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
  final VoidCallback onInviteMember;
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
  String _studentQuery = '';
  bool _showAllStudents = false;
  bool _showEndedTeacherScopes = false;
  bool _showEndedAssignments = false;

  @override
  void initState() {
    super.initState();
    _selectedArea = _initialArea(widget.snapshot);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ManagementAreaSwitcher(
          selectedArea: _selectedArea,
          onChanged: (area) {
            if (area == _selectedArea) return;
            setState(() => _selectedArea = area);
          },
        ),
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

  Widget _buildPeopleArea({
    required List<OrganizationTeacherSubjectScope> activeScopes,
    required List<OrganizationTeacherSubjectScope> endedScopes,
    required Set<String> latestEndedScopeIds,
  }) {
    return _ManagementAreaCard(
      icon: Icons.people_outline,
      title: '成员',
      description: '管理机构成员、账号状态和老师可教学科。邮箱只用于登录，日常协作优先显示姓名。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ManagementSection(
            title: '机构成员',
            count: '${widget.snapshot.members.length} 人',
            action: FilledButton.tonalIcon(
              onPressed: widget.busy || !widget.canInvite
                  ? null
                  : widget.onInviteMember,
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: const Text('邀请成员'),
            ),
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
            count: '${activeScopes.length} 条有效',
            action: TextButton.icon(
              onPressed: widget.busy ? null : widget.onAddTeacherScope,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('分配学科'),
            ),
            child: activeScopes.isEmpty
                ? const _ManagementEmptyState(
                    title: '还没有有效教学范围',
                    message: '老师加入机构后，再指定其可以负责哪些学科。',
                    icon: Icons.menu_book_outlined,
                  )
                : Column(
                    children: [
                      for (final scope in activeScopes)
                        _TeacherSubjectScopeTile(
                          scope: scope,
                          busy: widget.busy,
                          showReactivate: false,
                          onToggle: () => widget.onToggleTeacherScope(scope),
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
    final visibleActiveAssignments = normalizedQuery.isEmpty
        ? activeAssignments
        : activeAssignments
              .where(
                (assignment) =>
                    matchingStudentIds.contains(assignment.studentId),
              )
              .toList(growable: false);
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
      description: '先找学生，再处理档案或任课交接；历史任课默认收起。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.snapshot.students.length > 8) ...[
            TextField(
              key: const Key('management-student-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索姓名、编号、年级、班级、校区或学科',
                isDense: true,
              ),
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
          const SizedBox(height: AppSpacing.md),
          ExpansionTile(
            key: const PageStorageKey<String>('management-assignments'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(
              '任课老师与交接',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text('${visibleActiveAssignments.length} 条当前任课'),
            children: [
              if (visibleActiveAssignments.isEmpty)
                const _ManagementEmptyState(
                  title: '没有当前任课关系',
                  message: '添加学生时会建立首个主责任课关系，后续交接也在这里处理。',
                  icon: Icons.swap_horiz_outlined,
                )
              else
                for (final assignment in visibleActiveAssignments)
                  _StudentTeacherAssignmentTile(
                    assignment: assignment,
                    busy: widget.busy,
                    onTransfer: () =>
                        widget.onTransferStudentTeacherAssignment(assignment),
                  ),
              if (visibleEndedAssignments.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(
                      () => _showEndedAssignments = !_showEndedAssignments,
                    ),
                    icon: Icon(
                      _showEndedAssignments
                          ? Icons.expand_less
                          : Icons.history_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _showEndedAssignments
                          ? '收起历史任课'
                          : '查看历史任课（${visibleEndedAssignments.length}）',
                    ),
                  ),
                ),
                if (_showEndedAssignments)
                  for (final assignment in visibleEndedAssignments)
                    _StudentTeacherAssignmentTile(
                      assignment: assignment,
                      busy: widget.busy,
                      onTransfer: null,
                    ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsArea() {
    final noSubjects = widget.snapshot.setupOptions.subjects.isEmpty;
    return _ManagementAreaCard(
      icon: Icons.tune_outlined,
      title: '学科与设置',
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
