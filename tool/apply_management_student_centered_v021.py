from pathlib import Path


def once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


areas_path = Path('lib/features/organization_management/presentation/organization_management_areas.dart')
areas = areas_path.read_text()
areas = once(
    areas,
    'enum _ManagementArea { people, students, settings }\n',
    'enum _ManagementArea { people, students, settings }\n\nenum _ManagementExportMode { students, teacher }\n',
    'export enum',
)
areas = once(
    areas,
    '  bool _showEndedTeacherScopes = false;\n  bool _showEndedAssignments = false;\n',
    '  bool _showEndedTeacherScopes = false;\n',
    'remove ended assignment toggle state',
)
method_anchor = '  _ManagementArea _initialArea(_OrganizationManagementSnapshot snapshot) {'
methods = r'''  Future<void> _showExportRecords() async {
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
              onPressed: () => Navigator.of(context).pop(
                _ManagementExportMode.students,
              ),
              child: const ListTile(
                leading: Icon(Icons.school_outlined),
                title: Text('按学生和学科导出'),
                subtitle: Text('可选择多名学生和多个学科，导出完整学情记录'),
              ),
            ),
          if (canExportTeachers)
            SimpleDialogOption(
              key: const Key('management-export-teacher-option'),
              onPressed: () => Navigator.of(context).pop(
                _ManagementExportMode.teacher,
              ),
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

'''
areas = once(areas, method_anchor, methods + method_anchor, 'insert management helpers')
areas = once(
    areas,
    "    final endedAssignments = widget.snapshot.studentTeacherAssignments\n        .where((assignment) => !assignment.isActive)\n        .toList(growable: false);\n\n    return Column(",
    "    final endedAssignments = widget.snapshot.studentTeacherAssignments\n        .where((assignment) => !assignment.isActive)\n        .toList(growable: false);\n    final setupNextStep = _buildSetupNextStep();\n\n    return Column(",
    'setup next step local',
)
areas = once(
    areas,
    "      children: [\n        _ManagementAreaSwitcher(",
    "      children: [\n        if (setupNextStep != null) ...[\n          setupNextStep,\n          const SizedBox(height: AppSpacing.md),\n        ],\n        _ManagementAreaSwitcher(",
    'render setup next step',
)
areas = once(
    areas,
    "        const SizedBox(height: AppSpacing.lg),\n        switch (_selectedArea) {",
    "        if (widget.onExportStudentRecords != null ||\n            widget.onExportTeacherRecords != null) ...[\n          const SizedBox(height: AppSpacing.sm),\n          Align(\n            alignment: Alignment.centerRight,\n            child: OutlinedButton.icon(\n              key: const Key('management-export-records'),\n              onPressed: widget.busy ? null : _showExportRecords,\n              icon: const Icon(Icons.download_outlined, size: 18),\n              label: const Text('导出记录'),\n            ),\n          ),\n        ],\n        const SizedBox(height: AppSpacing.lg),\n        switch (_selectedArea) {",
    'unified export entry',
)
old_people_action = r'''            action: widget.canInvite || widget.onExportTeacherRecords != null
                ? Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (widget.onExportTeacherRecords != null)
                        OutlinedButton.icon(
                          onPressed: widget.busy
                              ? null
                              : widget.onExportTeacherRecords,
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('导出老师记录'),
                        ),
                      if (widget.canInvite)
                        FilledButton.tonalIcon(
                          onPressed: widget.busy ? null : widget.onInviteMember,
                          icon: const Icon(Icons.group_add_outlined, size: 18),
                          label: const Text('邀请成员'),
                        ),
                    ],
                  )
                : null,
'''
new_people_action = r'''            action: widget.canInvite
                ? FilledButton.tonalIcon(
                    onPressed: widget.busy ? null : widget.onInviteMember,
                    icon: const Icon(Icons.group_add_outlined, size: 18),
                    label: const Text('邀请成员'),
                  )
                : null,
'''
areas = once(areas, old_people_action, new_people_action, 'remove teacher export from members')
areas = once(
    areas,
    "                  ...student.subjectServices.map(\n                    (service) => service.subjectName,\n                  ),",
    "                  ...student.subjectServices.map(\n                    (service) => service.subjectName,\n                  ),\n                  ...activeAssignments\n                      .where(\n                        (assignment) => assignment.studentId == student.studentId,\n                      )\n                      .map((assignment) => assignment.teacherName),",
    'search teacher names',
)
visible_active = r'''    final visibleActiveAssignments = normalizedQuery.isEmpty
        ? activeAssignments
        : activeAssignments
              .where(
                (assignment) =>
                    matchingStudentIds.contains(assignment.studentId),
              )
              .toList(growable: false);
'''
areas = once(areas, visible_active, '', 'remove current assignment list')
areas = once(
    areas,
    "      description: '先找学生，再处理档案或任课交接；历史任课默认收起。',",
    "      description: '学生、学科和当前负责老师都在这里处理；历史任课按需查看。',",
    'students description',
)
areas = once(
    areas,
    "                hintText: '搜索姓名、编号、年级、班级、校区或学科',",
    "                hintText: '搜索姓名、编号、年级、班级、校区、学科或老师',",
    'student search hint',
)
old_student_action = r'''            action: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (widget.onExportStudentRecords != null)
                  OutlinedButton.icon(
                    key: const Key('management-export-student-records'),
                    onPressed: widget.busy
                        ? null
                        : widget.onExportStudentRecords,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('导出学生记录'),
                  ),
                FilledButton.icon(
                  onPressed: widget.busy ? null : widget.onAddStudent,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('添加学生'),
                ),
              ],
            ),
'''
new_student_action = r'''            action: FilledButton.icon(
              onPressed: widget.busy ? null : widget.onAddStudent,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('添加学生'),
            ),
'''
areas = once(areas, old_student_action, new_student_action, 'remove student export from section')
areas = once(
    areas,
    "                          student: student,\n                          busy: widget.busy,",
    "                          student: student,\n                          busy: widget.busy,\n                          activeAssignments: activeAssignments\n                              .where(\n                                (assignment) =>\n                                    assignment.studentId == student.studentId,\n                              )\n                              .toList(growable: false),\n                          onTransferAssignment: (assignment) => widget\n                              .onTransferStudentTeacherAssignment(assignment),",
    'pass assignments into student tile',
)
old_assignment_section = r'''          const SizedBox(height: AppSpacing.md),
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
'''
new_assignment_section = r'''          if (visibleEndedAssignments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ExpansionTile(
              key: const PageStorageKey<String>('management-assignment-history'),
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
'''
areas = once(areas, old_assignment_section, new_assignment_section, 'student-centered assignment history')
areas_path.write_text(areas)

rows_path = Path('lib/features/organization_management/presentation/organization_management_rows.dart')
rows = rows_path.read_text()
rows = once(
    rows,
    '    required this.student,\n    required this.busy,\n    required this.onAddSubject,',
    '    required this.student,\n    required this.busy,\n    required this.activeAssignments,\n    required this.onTransferAssignment,\n    required this.onAddSubject,',
    'student tile constructor assignments',
)
rows = once(
    rows,
    '  final OrganizationStudentRecord student;\n  final bool busy;\n  final VoidCallback? onAddSubject;',
    '  final OrganizationStudentRecord student;\n  final bool busy;\n  final List<OrganizationStudentTeacherAssignment> activeAssignments;\n  final Future<void> Function(OrganizationStudentTeacherAssignment assignment)\n  onTransferAssignment;\n  final VoidCallback? onAddSubject;',
    'student tile fields assignments',
)
rows = once(
    rows,
    '  @override\n  Widget build(BuildContext context) {\n    final details = <String>[',
    '''  OrganizationStudentTeacherAssignment? _assignmentFor(
    OrganizationStudentSubjectService service,
  ) {
    for (final assignment in activeAssignments) {
      if (assignment.isActive &&
          assignment.studentSubjectProfileId == service.profileId) {
        return assignment;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final details = <String>[''',
    'student assignment helper',
)
rows = once(
    rows,
    '''                  _StudentSubjectServiceRow(
                    service: service,
                    busy: busy,
                    onToggle:''',
    '''                  _StudentSubjectServiceRow(
                    service: service,
                    assignment: _assignmentFor(service),
                    busy: busy,
                    onTransfer: (assignment) => onTransferAssignment(assignment),
                    onToggle:''',
    'service row assignment args',
)
old_service_class = r'''class _StudentSubjectServiceRow extends StatelessWidget {
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
'''
new_service_class = r'''class _StudentSubjectServiceRow extends StatelessWidget {
  const _StudentSubjectServiceRow({
    required this.service,
    required this.assignment,
    required this.busy,
    required this.onTransfer,
    required this.onToggle,
  });

  final OrganizationStudentSubjectService service;
  final OrganizationStudentTeacherAssignment? assignment;
  final bool busy;
  final Future<void> Function(OrganizationStudentTeacherAssignment assignment)
  onTransfer;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final currentAssignment = assignment;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (service.isActive) ...[
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                Icon(
                  Icons.person_pin_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                Text(
                  currentAssignment == null
                      ? '暂未安排负责老师'
                      : '${_studentAssignmentRoleLabel(currentAssignment.assignmentRole)}：${currentAssignment.teacherName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (currentAssignment != null)
                  TextButton(
                    key: ValueKey<String>(
                      'student-assignment-transfer-${currentAssignment.assignmentId}',
                    ),
                    onPressed: busy
                        ? null
                        : () => onTransfer(currentAssignment),
                    child: const Text('交接老师'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
'''
rows = once(rows, old_service_class, new_service_class, 'replace student service row')
rows_path.write_text(rows)

transfer_path = Path('lib/features/organization_management/presentation/organization_student_teacher_assignment_transfer_dialog.dart')
transfer = transfer_path.read_text()
transfer = once(
    transfer,
    '学生已有的开放问题和待办不会自动换负责人；',
    '学生已有的正在跟进的问题和待办不会自动换负责人；',
    'teacher-facing handoff wording',
)
transfer_path.write_text(transfer)

test_path = Path('test/features/organization_management_test.dart')
test = test_path.read_text()
old_handoff = r'''    expect(find.text('任课老师与交接'), findsOneWidget);
    expect(find.text('交接老师'), findsNothing);
    final assignmentSection = find.text('任课老师与交接');
    await tester.ensureVisible(assignmentSection);
    await tester.tap(assignmentSection);
    await tester.pumpAndSettle();

    final transferButton = find.text('交接老师');
'''
new_handoff = r'''    expect(find.text('任课老师与交接'), findsNothing);
    expect(find.text('主责老师：原老师'), findsOneWidget);
    final transferButton = find.byKey(
      const ValueKey<String>('student-assignment-transfer-assignment-1'),
    );
'''
test = once(test, old_handoff, new_handoff, 'direct handoff test')
test = once(
    test,
    "expect(find.text('主责老师：新老师 · new-teacher@example.com'), findsOneWidget);",
    "expect(find.text('主责老师：新老师'), findsOneWidget);",
    'handoff result wording test',
)
test = once(
    test,
    "    expect(find.text('基础设置'), findsOneWidget);\n    expect(find.text('添加学科'), findsOneWidget);",
    "    expect(find.text('基础设置'), findsOneWidget);\n    expect(find.text('先添加机构学科'), findsOneWidget);\n    expect(find.byKey(const Key('management-next-step-action')), findsOneWidget);\n    expect(find.text('添加学科'), findsWidgets);",
    'missing subject next step test',
)
test = once(
    test,
    "    expect(find.text('机构成员'), findsOneWidget);\n    expect(find.text('老师可教学科'), findsOneWidget);",
    "    expect(find.text('机构成员'), findsOneWidget);\n    expect(find.text('老师可教学科'), findsOneWidget);\n    expect(find.text('下一步：配置老师可教学科'), findsOneWidget);\n    expect(find.widgetWithText(FilledButton, '配置老师学科'), findsOneWidget);",
    'missing teacher scope next step test',
)
test_path.write_text(test)

contract_path = Path('test/features/management_workflow_clarity_contract_test.dart')
contract_path.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('management keeps current teacher inside student context', () {
    final areas = File(
      'lib/features/organization_management/presentation/organization_management_areas.dart',
    ).readAsStringSync();
    final rows = File(
      'lib/features/organization_management/presentation/organization_management_rows.dart',
    ).readAsStringSync();

    expect(areas, isNot(contains("'任课老师与交接'")));
    expect(areas, contains("'历史任课记录'"));
    expect(rows, contains("'暂未安排负责老师'"));
    expect(rows, contains("'student-assignment-transfer-${currentAssignment.assignmentId}'"));
  });

  test('management exposes one export entry and concrete setup next steps', () {
    final areas = File(
      'lib/features/organization_management/presentation/organization_management_areas.dart',
    ).readAsStringSync();

    expect(areas, contains("label: const Text('导出记录')"));
    expect(areas, contains("title: const Text('导出记录')"));
    expect(areas, isNot(contains("label: const Text('导出老师记录')")));
    expect(areas, isNot(contains("label: const Text('导出学生记录')")));
    expect(areas, contains("title = '先添加机构学科';"));
    expect(areas, contains("title = '下一步：配置老师可教学科';"));
    expect(areas, contains("title = '准备完成，可以添加第一位学生';"));
  });
}
''')
