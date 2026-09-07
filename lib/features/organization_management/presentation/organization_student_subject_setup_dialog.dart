import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../cloud/learning_repository.dart';
import '../../../cloud/organization_management_repository.dart';

class OrganizationStudentSubjectSetupDraft {
  const OrganizationStudentSubjectSetupDraft({
    required this.operationId,
    required this.studentId,
    required this.organizationSubjectId,
    required this.teacherMembershipId,
    required this.subjectName,
    required this.teacherName,
  });

  final String operationId;
  final String studentId;
  final String organizationSubjectId;
  final String teacherMembershipId;
  final String subjectName;
  final String teacherName;
}

class OrganizationStudentSubjectSetupDialog extends StatefulWidget {
  const OrganizationStudentSubjectSetupDialog({
    required this.student,
    required this.subjects,
    required this.teachers,
    super.key,
  });

  final OrganizationStudentRecord student;
  final List<OrganizationSetupSubject> subjects;
  final List<OrganizationSetupTeacher> teachers;

  @override
  State<OrganizationStudentSubjectSetupDialog> createState() =>
      _OrganizationStudentSubjectSetupDialogState();
}

class _OrganizationStudentSubjectSetupDialogState
    extends State<OrganizationStudentSubjectSetupDialog> {
  late OrganizationSetupSubject _selectedSubject;
  late OrganizationSetupTeacher _selectedTeacher;
  final String _operationId = createOperationId();

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.subjects.first;
    _selectedTeacher = _teachersFor(_selectedSubject.id).first;
  }

  List<OrganizationSetupTeacher> _teachersFor(String organizationSubjectId) {
    return <OrganizationSetupTeacher>[
      for (final teacher in widget.teachers)
        if (teacher.supportsSubject(organizationSubjectId)) teacher,
    ];
  }

  void _selectSubject(OrganizationSetupSubject subject) {
    final teachers = _teachersFor(subject.id);
    if (teachers.isEmpty) return;
    setState(() {
      _selectedSubject = subject;
      if (!teachers.any(
        (teacher) => teacher.membershipId == _selectedTeacher.membershipId,
      )) {
        _selectedTeacher = teachers.first;
      }
    });
  }

  void _submit() {
    Navigator.of(context).pop(
      OrganizationStudentSubjectSetupDraft(
        operationId: _operationId,
        studentId: widget.student.studentId,
        organizationSubjectId: _selectedSubject.id,
        teacherMembershipId: _selectedTeacher.membershipId,
        subjectName: _selectedSubject.displayName,
        teacherName: _selectedTeacher.displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teachers = _teachersFor(_selectedSubject.id);
    return AlertDialog(
      title: Text('为 ${widget.student.studentName} 添加学科'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '只新增这一门学科和主负责老师；已有学科、任课关系和历史记录都不会改变。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<OrganizationSetupSubject>(
              key: const Key('student-subject-setup-subject'),
              initialValue: _selectedSubject,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '学科 *'),
              items: [
                for (final subject in widget.subjects)
                  DropdownMenuItem(
                    value: subject,
                    child: Text(
                      subject.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (subject) {
                if (subject != null) _selectSubject(subject);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<OrganizationSetupTeacher>(
              key: ValueKey<String>(
                'student-subject-setup-teacher-${_selectedSubject.id}',
              ),
              initialValue: _selectedTeacher,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '主负责老师 *'),
              items: [
                for (final teacher in teachers)
                  DropdownMenuItem(
                    value: teacher,
                    child: Text(
                      teacher.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (teacher) {
                if (teacher != null) {
                  setState(() => _selectedTeacher = teacher);
                }
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '同一位老师可以负责同一学生的多门学科，只要该老师已配置相应可教学科。',
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
          key: const Key('student-subject-setup-submit'),
          onPressed: _submit,
          child: const Text('添加学科'),
        ),
      ],
    );
  }
}
