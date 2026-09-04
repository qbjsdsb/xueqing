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
    required this.status,
  });

  final String operationId;
  final String studentId;
  final int expectedStudentVersion;
  final String name;
  final String? studentCode;
  final String status;
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
  ) onSubmit;

  @override
  State<OrganizationStudentEditDialog> createState() =>
      _OrganizationStudentEditDialogState();
}

class _OrganizationStudentEditDialogState
    extends State<OrganizationStudentEditDialog> {
  static const _statuses = <String>['active', 'inactive', 'archived'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _studentCodeController;
  late String _selectedStatus;
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
    _selectedStatus = _statuses.contains(widget.student.status)
        ? widget.student.status
        : 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }

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
          status: _selectedStatus,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(result);
      }
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
    final message = organizationStudentLifecycleErrorMessage(error);
    if (message != null) {
      return message;
    }
    if (error is AuthException && error.message.trim().isNotEmpty) {
      return '操作未完成：${error.message.trim()}';
    }
    return '保存未完成；表单内容仍保留，可以检查网络后重试。';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('编辑学生'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.58,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '修改姓名或编号会保留全部历史 Case；停用/归档只会退出教师工作台，不会删除历史记录。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
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
                    if (text.isEmpty) {
                      return '请输入学生姓名。';
                    }
                    if (text.length > 120) {
                      return '学生姓名不能超过 120 个字符。';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _studentCodeController,
                  maxLength: 80,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '学生编号',
                    hintText: '可选',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '教学可见状态 *'),
                  items: [
                    for (final status in _statuses)
                      DropdownMenuItem<String>(
                        value: status,
                        child: Text(_studentStatusLabel(status)),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (status) {
                          if (status != null) {
                            setState(() => _selectedStatus = status);
                          }
                        },
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '正常教学会出现在老师的学生和今日工作台；暂不教学与已归档学生仍保留在机构管理中。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存学生'),
        ),
      ],
    );
  }
}

String _studentStatusLabel(String status) {
  return switch (status) {
    'active' => '正常教学',
    'inactive' => '暂不教学',
    'archived' => '已归档',
    _ => '状态未知',
  };
}

String? _nullableText(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}