import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../cloud/learning_repository.dart';
import '../../../cloud/organization_management_repository.dart';

class OrganizationTeacherSubjectScopeDraft {
  const OrganizationTeacherSubjectScopeDraft({
    required this.operationId,
    required this.membershipId,
    required this.organizationSubjectId,
    required this.teacherName,
    required this.subjectName,
  });

  final String operationId;
  final String membershipId;
  final String organizationSubjectId;
  final String teacherName;
  final String subjectName;
}

class OrganizationTeacherSubjectScopeDialog extends StatefulWidget {
  const OrganizationTeacherSubjectScopeDialog({
    required this.teachers,
    required this.subjects,
    required this.activeScopeKeys,
    super.key,
  });

  final List<OrganizationSetupTeacher> teachers;
  final List<OrganizationSetupSubject> subjects;
  final Set<String> activeScopeKeys;

  @override
  State<OrganizationTeacherSubjectScopeDialog> createState() =>
      _OrganizationTeacherSubjectScopeDialogState();
}

class _OrganizationTeacherSubjectScopeDialogState
    extends State<OrganizationTeacherSubjectScopeDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedMembershipId;
  String? _selectedSubjectId;

  OrganizationSetupTeacher get _selectedTeacher => widget.teachers.firstWhere(
    (teacher) => teacher.membershipId == _selectedMembershipId,
  );

  List<OrganizationSetupSubject> get _availableSubjects {
    return [
      for (final subject in widget.subjects)
        if (!widget.activeScopeKeys.contains(
          _scopeKey(_selectedMembershipId, subject.id),
        ))
          subject,
    ];
  }

  @override
  void initState() {
    super.initState();
    _selectedMembershipId = widget.teachers.first.membershipId;
    final subjects = _availableSubjects;
    _selectedSubjectId = subjects.isEmpty ? null : subjects.first.id;
  }

  void _selectTeacher(String? membershipId) {
    if (membershipId == null) {
      return;
    }
    setState(() {
      _selectedMembershipId = membershipId;
      final subjects = _availableSubjects;
      _selectedSubjectId = subjects.isEmpty ? null : subjects.first.id;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final subject = _availableSubjects.firstWhere(
      (item) => item.id == _selectedSubjectId,
    );
    Navigator.of(context).pop(
      OrganizationTeacherSubjectScopeDraft(
        operationId: createOperationId(),
        membershipId: _selectedMembershipId,
        organizationSubjectId: subject.id,
        teacherName: _selectedTeacher.displayName,
        subjectName: subject.displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableSubjects = _availableSubjects;
    return AlertDialog(
      title: const Text('配置教师教学范围'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择一位在岗老师和一个活跃学科。启用后只影响新的教学授权，不会自动改变历史记录。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _selectedMembershipId,
                  decoration: const InputDecoration(labelText: '老师'),
                  items: [
                    for (final teacher in widget.teachers)
                      DropdownMenuItem<String>(
                        value: teacher.membershipId,
                        child: Text(
                          teacher.email.isEmpty
                              ? teacher.displayName
                              : '${teacher.displayName} · ${teacher.email}',
                        ),
                      ),
                  ],
                  onChanged: _selectTeacher,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSubjectId,
                  decoration: const InputDecoration(labelText: '学科'),
                  items: [
                    for (final subject in availableSubjects)
                      DropdownMenuItem<String>(
                        value: subject.id,
                        child: Text(subject.displayName),
                      ),
                  ],
                  validator: (value) => value == null ? '当前老师没有可配置的学科。' : null,
                  onChanged: (subjectId) {
                    setState(() => _selectedSubjectId = subjectId);
                  },
                ),
                if (availableSubjects.isEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '这位老师的所有活跃学科都已配置教学范围。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: availableSubjects.isEmpty ? null : _submit,
          child: const Text('保存教学范围'),
        ),
      ],
    );
  }
}

String _scopeKey(String membershipId, String subjectId) =>
    '$membershipId|$subjectId';
