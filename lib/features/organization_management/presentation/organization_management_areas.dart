part of 'organization_management_page.dart';

class _ManagementOverview extends StatelessWidget {
  const _ManagementOverview({
    required this.snapshot,
    required this.isOwner,
    required this.busy,
    required this.canEditMemberName,
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
  final bool canEditMemberName;
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
  Widget build(BuildContext context) {
    final activeScopes = snapshot.teacherSubjectScopes
        .where((scope) => scope.isActive)
        .length;
    final activeAssignments = snapshot.studentTeacherAssignments
        .where((assignment) => assignment.isActive)
        .length;
    final latestEndedScopeIds = _latestEndedTeacherScopeIds(
      snapshot.teacherSubjectScopes,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ManagementAreaCard(
          icon: Icons.people_outline,
          title: '成员与权限',
          description: '先确认谁在机构里、叫什么、是什么身份，再配置老师可以教什么。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManagementSection(
                title: '成员',
                count: '${snapshot.members.length} 人',
                child: snapshot.members.isEmpty
                    ? const _ManagementEmptyState(
                        title: '还没有机构成员',
                        message: '使用页面顶部“邀请成员”添加负责人、管理员或老师。',
                        icon: Icons.people_outline,
                      )
                    : Column(
                        children: [
                          for (final member in snapshot.members)
                            _MemberTile(
                              member: member,
                              busy: busy,
                              canEditName: canEditMemberName,
                              onEditName: onEditMemberName == null
                                  ? null
                                  : () => onEditMemberName!(member),
                              onToggleStatus: () =>
                                  onToggleMemberStatus(member),
                              onReissueCredential:
                                  onReissueMemberCredential == null
                                  ? null
                                  : () => onReissueMemberCredential!(member),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ManagementSection(
                title: '邀请',
                count: '${snapshot.invitations.length} 条待处理',
                child: snapshot.invitations.isEmpty
                    ? const _ManagementEmptyState(
                        title: '没有待处理邀请',
                        message: '新邀请、负责人审批和继续开通都会集中显示在这里。',
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
                              onProvision:
                                  invitation.isPending &&
                                      onProvisionInvitation != null
                                  ? () => onProvisionInvitation!(invitation)
                                  : null,
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ManagementSection(
                title: '老师可教学科',
                count: '$activeScopes 条有效',
                action: TextButton.icon(
                  onPressed: busy ? null : onAddTeacherScope,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('配置老师可教学科'),
                ),
                child: snapshot.teacherSubjectScopes.isEmpty
                    ? const _ManagementEmptyState(
                        title: '还没有配置老师可教学科',
                        message: '老师加入机构后，再指定其可以负责哪些学科。',
                        icon: Icons.menu_book_outlined,
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
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ManagementAreaCard(
          icon: Icons.school_outlined,
          title: '学生与任课',
          description: '学生档案和任课老师放在一起，交接时可以直接看清“谁负责谁”。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManagementSection(
                title: '学生',
                count: '${snapshot.students.length} 人',
                child: snapshot.students.isEmpty
                    ? const _ManagementEmptyState(
                        title: '还没有学生档案',
                        message: '使用页面顶部“添加学生”建立第一位学生。',
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
                title: '任课老师',
                count: '$activeAssignments 条有效',
                child: snapshot.studentTeacherAssignments.isEmpty
                    ? const _ManagementEmptyState(
                        title: '还没有任课关系',
                        message: '添加学生时会建立首个主责任课关系，后续交接在这里完成。',
                        icon: Icons.swap_horiz_outlined,
                      )
                    : Column(
                        children: [
                          for (final assignment
                              in snapshot.studentTeacherAssignments)
                            _StudentTeacherAssignmentTile(
                              assignment: assignment,
                              busy: busy,
                              onTransfer: assignment.isActive
                                  ? () => onTransferStudentTeacherAssignment(
                                      assignment,
                                    )
                                  : null,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ManagementAreaCard(
          icon: Icons.tune_outlined,
          title: '基础设置',
          description: '这里只保留影响日常教学闭环的基础配置，不扩展成复杂教务系统。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManagementSetupHint(
                options: snapshot.setupOptions,
                subjectCatalog: snapshot.subjectCatalog,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ManagementSection(
                title: '机构学科',
                count: '${snapshot.setupOptions.subjects.length} 门',
                action: TextButton.icon(
                  onPressed: busy ? null : onAddSubject,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加学科'),
                ),
                child: snapshot.setupOptions.subjects.isEmpty
                    ? const _ManagementEmptyState(
                        title: '还没有机构学科',
                        message: '只添加本机构实际教授的学科，后续再分配给对应老师。',
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
              if (canManageCaseTypes && onOpenCaseTypes != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _ManagementSection(
                  title: '问题类型',
                  count: '学习问题分类',
                  action: TextButton.icon(
                    onPressed: busy ? null : onOpenCaseTypes,
                    icon: const Icon(Icons.category_outlined, size: 18),
                    label: const Text('管理问题类型'),
                  ),
                  child: Text(
                    '统一常用的问题分类，帮助老师记录和回看学生长期变化；不用于给学生贴标签。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
