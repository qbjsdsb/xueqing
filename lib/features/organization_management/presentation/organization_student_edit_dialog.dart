import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../cloud/learning_repository.dart';
import '../../../cloud/organization_management_repository.dart';

class OrganizationStudentEditDraft {
  const OrganizationStudentEditDraft({
    required this.operationId,
    required this.studentId,
    required this.expectedStudentVersion,
    required this.name,
    required this.studentCode,
    required this.grade,
    required this.className,
    required this.campus,
  });

  final String operationId;
  final String studentId;
  final int expectedStudentVersion;
  final String name;
  final String? studentCode;
  final String grade;
  final String? className;
  final String? campus;
}

class OrganizationStudentEditDialog extends StatefulWidget {
  const OrganizationStudentEditDialog({
    required this.student,
    required this.onSubmit,
    super.key,
  });

  final OrganizationStudentRecord student;
  final Future<OrganizationStudentUpdateResult> Function(
    OrganizationStudentEditDraft draft,
  )
  onSubmit;

  @override
  State<OrganizationStudentEditDialog> createState() =>
      _OrganizationStudentEditDialogState();
}

class _OrganizationStudentEditDialogState
    extends State<OrganizationStudentEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _studentCodeController;
  late final TextEditingController _gradeController;
  late final TextEditingController _classNameController;
  late final TextEditingController _campusController;
  final String _operationId = createOperationId();
  bool _busy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.studentName);
    _studentCodeController = TextEditingController(
      text: widget.student.studentCode ?? '',
    );
    _gradeController = TextEditingController(text: widget.student.grade ?? '');
    _classNameController = TextEditingController(
      text: widget.student.className ?? '',
    );
    _campusController = TextEditingController(
      text: widget.student.campus ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentCodeController.dispose();
    _gradeController.dispose();
    _classNameController.dispose();
    _campusController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.onSubmit(
        OrganizationStudentEditDraft(
          operationId: _operationId,
          studentId: widget.student.studentId,
          expectedStudentVersion: widget.student.version,
          name: _nameController.text.trim(),
          studentCode: _nullableText(_studentCodeController.text),
          grade: _gradeController.text.trim(),
          className: _nullableText(_classNameController.text),
          campus: _nullableText(_campusController.text),
        ),
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _describeError(error);
          _busy = false;
        });
      }
    }
  }

  String _describeError(Object error) {
    final compatibilityMessage = organizationBackendCompatibilityErrorMessage(
      error,
    );
    if (compatibilityMessage != null) return compatibilityMessage;
    final message = organizationStudentLifecycleErrorMessage(error);
    if (message != null) return message;
    if (error is AuthException && error.message.trim().isNotEmpty) {
      return '操作未完成：${error.message.trim()}';
    }
    return '保存未完成；表单内容仍保留，可以检查网络后重试。';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('编辑学生资料'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.68,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '修改姓名、编号和在读信息，不会改变教学状态、学科、任课关系、问题或历史记录。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('student-edit-name-field'),
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '学生姓名 *',
                    hintText: '例如：林雨桐',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return '请输入学生姓名。';
                    if (text.length > 120) return '学生姓名不能超过 120 个字符。';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  key: const Key('student-edit-code-field'),
                  controller: _studentCodeController,
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '学生编号',
                    hintText: '可选，例如 S-001',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  key: const Key('student-edit-grade-field'),
                  controller: _gradeController,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '年级 *',
                    hintText: '例如：初三',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return '请输入年级。';
                    if (text.length > 120) return '年级不能超过 120 个字符。';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  key: const Key('student-edit-class-field'),
                  controller: _classNameController,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '班级',
                    hintText: '可选，例如 3 班',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  key: const Key('student-edit-campus-field'),
                  controller: _campusController,
                  maxLength: 120,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: '校区',
                    hintText: '可选，例如 思明校区',
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('student-edit-submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存资料'),
        ),
      ],
    );
  }
}

String? _nullableText(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
