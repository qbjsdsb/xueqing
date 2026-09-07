import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../cloud/organization_management_repository.dart';

class OrganizationStudentSubjectRestoreDialog extends StatefulWidget {
  const OrganizationStudentSubjectRestoreDialog({
    required this.student,
    required this.service,
    required this.teachers,
    super.key,
  });

  final OrganizationStudentRecord student;
  final OrganizationStudentSubjectService service;
  final List<OrganizationSetupTeacher> teachers;

  @override
  State<OrganizationStudentSubjectRestoreDialog> createState() =>
      _OrganizationStudentSubjectRestoreDialogState();
}

class _OrganizationStudentSubjectRestoreDialogState
    extends State<OrganizationStudentSubjectRestoreDialog> {
  late OrganizationSetupTeacher _selectedTeacher;

  @override
  void initState() {
    super.initState();
    assert(widget.teachers.isNotEmpty);
    _selectedTeacher = widget.teachers.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '恢复 ${widget.student.studentName} · ${widget.service.subjectName}',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '恢复会继续使用原来的学科档案和全部历史记录，并建立一条新的主负责老师关系。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<OrganizationSetupTeacher>(
              key: const Key('student-subject-restore-teacher'),
              initialValue: _selectedTeacher,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '主负责老师 *'),
              items: [
                for (final teacher in widget.teachers)
                  DropdownMenuItem(
                    value: teacher,
                    child: Text(
                      teacher.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (teacher) {
                if (teacher != null) setState(() => _selectedTeacher = teacher);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '只会列出当前在岗且已配置这门可教学科的老师。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('student-subject-restore-submit'),
          onPressed: () => Navigator.of(context).pop(_selectedTeacher),
          child: const Text('恢复学科'),
        ),
      ],
    );
  }
}
