import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../cloud/learning_repository.dart';
import '../../../cloud/organization_management_repository.dart';

class OrganizationSubjectDraft {
  const OrganizationSubjectDraft({
    required this.operationId,
    required this.subjectId,
  });

  final String operationId;
  final String subjectId;
}

class OrganizationSubjectSetupDialog extends StatefulWidget {
  const OrganizationSubjectSetupDialog({
    required this.subjects,
    required this.onSubmit,
    super.key,
  });

  final List<OrganizationSubjectCatalogItem> subjects;
  final Future<OrganizationSubjectSetupResult> Function(
    OrganizationSubjectDraft draft,
  )
  onSubmit;

  @override
  State<OrganizationSubjectSetupDialog> createState() =>
      _OrganizationSubjectSetupDialogState();
}

class _OrganizationSubjectSetupDialogState
    extends State<OrganizationSubjectSetupDialog> {
  late OrganizationSubjectCatalogItem _selectedSubject;
  final String _operationId = createOperationId();
  bool _busy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.subjects.first;
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.onSubmit(
        OrganizationSubjectDraft(
          operationId: _operationId,
          subjectId: _selectedSubject.id,
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
    final message = organizationSubjectSetupErrorMessage(error);
    if (message != null) {
      return message;
    }
    if (error is AuthException && error.message.trim().isNotEmpty) {
      return '操作未完成：' + error.message.trim();
    }
    return '保存未完成；可以检查网络后重试。';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('添加学科'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '从全局活跃学科目录中选择一个加入本机构。全局目录不会被修改。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<OrganizationSubjectCatalogItem>(
              initialValue: _selectedSubject,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '学科 *'),
              items: [
                for (final subject in widget.subjects)
                  DropdownMenuItem(
                    value: subject,
                    child: Text(
                      subject.displayName + ' · ' + subject.code,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (subject) {
                      if (subject != null) {
                        setState(() => _selectedSubject = subject);
                      }
                    },
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
              : const Text('保存学科'),
        ),
      ],
    );
  }
}
