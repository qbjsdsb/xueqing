import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../cloud/learning_repository.dart';
import '../../../cloud/organization_management_repository.dart';

class OrganizationStudentTeacherAssignmentTransferDraft {
  const OrganizationStudentTeacherAssignmentTransferDraft({
    required this.operationId,
    required this.replacementMembershipId,
    required this.replacementTeacherName,
  });

  final String operationId;
  final String replacementMembershipId;
  final String replacementTeacherName;
}

class OrganizationStudentTeacherAssignmentTransferDialog
    extends StatefulWidget {
  const OrganizationStudentTeacherAssignmentTransferDialog({
    required this.assignment,
    required this.candidates,
    super.key,
  });

  final OrganizationStudentTeacherAssignment assignment;
  final List<OrganizationSetupTeacher> candidates;

  @override
  State<OrganizationStudentTeacherAssignmentTransferDialog> createState() =>
      _OrganizationStudentTeacherAssignmentTransferDialogState();
}

class _OrganizationStudentTeacherAssignmentTransferDialogState
    extends State<OrganizationStudentTeacherAssignmentTransferDialog> {
  String? _selectedMembershipId;

  OrganizationSetupTeacher? get _selectedTeacher {
    final membershipId = _selectedMembershipId;
    if (membershipId == null) {
      return null;
    }
    for (final teacher in widget.candidates) {
      if (teacher.membershipId == membershipId) {
        return teacher;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.candidates.isNotEmpty) {
      _selectedMembershipId = widget.candidates.first.membershipId;
    }
  }

  void _submit() {
    final teacher = _selectedTeacher;
    if (teacher == null) {
      return;
    }
    Navigator.of(context).pop(
      OrganizationStudentTeacherAssignmentTransferDraft(
        operationId: createOperationId(),
        replacementMembershipId: teacher.membershipId,
        replacementTeacherName: teacher.displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignment = widget.assignment;
    final selectedTeacher = _selectedTeacher;
    return AlertDialog(
      title: const Text('交接学生任课老师'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${assignment.studentName} · ${assignment.subjectName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '当前${_assignmentRoleLabel(assignment.assignmentRole)}：'
                '${assignment.teacherName}'
                '${assignment.teacherEmail.isEmpty ? '' : ' · ${assignment.teacherEmail}'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '交接会在同一个事务中结束当前关系并建立新的历史关系，保留版本和操作记录。开放案件与待办行动的负责人不会自动改变；如需停用原老师的教学范围，还要单独完成那些事项的交接。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _selectedMembershipId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '接收老师'),
                items: [
                  for (final teacher in widget.candidates)
                    DropdownMenuItem<String>(
                      value: teacher.membershipId,
                      child: Text(
                        teacher.email.isEmpty
                            ? teacher.displayName
                            : '${teacher.displayName} · ${teacher.email}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: widget.candidates.isEmpty
                    ? null
                    : (membershipId) {
                        setState(() => _selectedMembershipId = membershipId);
                      },
              ),
              if (widget.candidates.isEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '当前没有同时满足“在岗、老师角色、该学科教学范围有效”的接收老师。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else if (selectedTeacher != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '接收老师：${selectedTeacher.displayName}；仅改变这条${_assignmentRoleLabel(assignment.assignmentRole)}任课关系。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: selectedTeacher == null ? null : _submit,
          child: const Text('确认交接'),
        ),
      ],
    );
  }
}

String _assignmentRoleLabel(String role) {
  return switch (role) {
    'lead' => '主责老师',
    'collaborator' => '协作老师',
    _ => '任课老师',
  };
}
