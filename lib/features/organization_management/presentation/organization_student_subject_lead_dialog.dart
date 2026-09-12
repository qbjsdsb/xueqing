import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../cloud/learning_repository.dart';
import '../../../cloud/organization_management_repository.dart';

class OrganizationStudentSubjectLeadDraft {
  const OrganizationStudentSubjectLeadDraft({
    required this.operationId,
    required this.teacherMembershipId,
    required this.teacherName,
  });

  final String operationId;
  final String teacherMembershipId;
  final String teacherName;
}

class OrganizationStudentSubjectLeadDialog extends StatefulWidget {
  const OrganizationStudentSubjectLeadDialog({
    required this.studentName,
    required this.service,
    required this.candidates,
    super.key,
  });

  final String studentName;
  final OrganizationStudentSubjectService service;
  final List<OrganizationSetupTeacher> candidates;

  @override
  State<OrganizationStudentSubjectLeadDialog> createState() =>
      _OrganizationStudentSubjectLeadDialogState();
}

class _OrganizationStudentSubjectLeadDialogState
    extends State<OrganizationStudentSubjectLeadDialog> {
  String? _selectedMembershipId;

  OrganizationSetupTeacher? get _selectedTeacher {
    final membershipId = _selectedMembershipId;
    if (membershipId == null) return null;
    for (final teacher in widget.candidates) {
      if (teacher.membershipId == membershipId) return teacher;
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
    if (teacher == null) return;
    Navigator.of(context).pop(
      OrganizationStudentSubjectLeadDraft(
        operationId: createOperationId(),
        teacherMembershipId: teacher.membershipId,
        teacherName: teacher.displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTeacher = _selectedTeacher;
    return AlertDialog(
      title: const Text('设置主责老师'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.studentName} · ${widget.service.subjectName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '当前这门学科尚未明确主责老师。正式学情需要有人持续负责。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _selectedMembershipId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '主责老师'),
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
              const SizedBox(height: AppSpacing.md),
              Text(
                selectedTeacher == null
                    ? '当前没有可负责这门学科的在岗老师。请先配置老师的可教学科。'
                    : '这位老师将负责该学科后续新建立的问题。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '已有问题的主责、待办负责人和历史记录不会自动修改。',
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('student-subject-set-lead-confirm'),
          onPressed: selectedTeacher == null ? null : _submit,
          child: const Text('设置主责'),
        ),
      ],
    );
  }
}
