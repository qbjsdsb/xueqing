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
    this.initialMembershipId,
    super.key,
  });

  final List<OrganizationSetupTeacher> teachers;
  final List<OrganizationSetupSubject> subjects;
  final Set<String> activeScopeKeys;
  final String? initialMembershipId;

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

  bool get _teacherLocked => widget.initialMembershipId != null;

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
    final requestedMembershipId = widget.initialMembershipId;
    _selectedMembershipId =
        requestedMembershipId != null &&
            widget.teachers.any(
              (teacher) => teacher.membershipId == requestedMembershipId,
            )
        ? requestedMembershipId
        : widget.teachers.first.membershipId;
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
      title: Text(
        _teacherLocked
            ? '为 ${_selectedTeacher.displayName} 添加教学学科'
            : '添加老师教学学科',
      ),
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
                  '教学学科决定这位老师以后可以承担哪些学科的任课。老师工作台只会显示已授权并实际分配给自己的学生学科。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_teacherLocked)
                  _TeacherSubjectContext(
                    label: '老师',
                    value: _selectedTeacher.email.isEmpty
                        ? _selectedTeacher.displayName
                        : '${_selectedTeacher.displayName} · ${_selectedTeacher.email}',
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMembershipId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '老师'),
                    items: [
                      for (final teacher in widget.teachers)
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
                    onChanged: _selectTeacher,
                  ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSubjectId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '新增教学学科'),
                  items: [
                    for (final subject in availableSubjects)
                      DropdownMenuItem<String>(
                        value: subject.id,
                        child: Text(
                          subject.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  validator: (value) => value == null ? '这位老师暂无可添加的学科。' : null,
                  onChanged: (subjectId) {
                    setState(() => _selectedSubjectId = subjectId);
                  },
                ),
                if (availableSubjects.isEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '这位老师已经拥有本机构全部教学学科。',
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
          child: const Text('添加'),
        ),
      ],
    );
  }
}

class _TeacherSubjectContext extends StatelessWidget {
  const _TeacherSubjectContext({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

String _scopeKey(String membershipId, String subjectId) =>
    '$membershipId|$subjectId';
