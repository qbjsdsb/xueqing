import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/app_motion.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../cloud/learning_repository.dart';
import '../../../cloud/organization_management_repository.dart';

class OrganizationStudentDraft {
  const OrganizationStudentDraft({
    required this.operationId,
    required this.name,
    required this.studentCode,
    required this.grade,
    required this.className,
    required this.campus,
    required this.organizationSubjectId,
    required this.teacherMembershipId,
    required this.positioning,
    required this.strengths,
    required this.cadenceNote,
  });

  final String operationId;
  final String name;
  final String? studentCode;
  final String? grade;
  final String? className;
  final String? campus;
  final String organizationSubjectId;
  final String teacherMembershipId;
  final String? positioning;
  final String? strengths;
  final String? cadenceNote;
}

class OrganizationStudentSetupDialog extends StatefulWidget {
  const OrganizationStudentSetupDialog({
    required this.options,
    required this.onSubmit,
    super.key,
  });

  final OrganizationSetupOptions options;
  final Future<OrganizationStudentSetupResult> Function(
    OrganizationStudentDraft draft,
  )
  onSubmit;

  @override
  State<OrganizationStudentSetupDialog> createState() =>
      _OrganizationStudentSetupDialogState();
}

class _OrganizationStudentSetupDialogState
    extends State<OrganizationStudentSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _studentCodeController = TextEditingController();
  final _gradeController = TextEditingController();
  final _classNameController = TextEditingController();
  final _campusController = TextEditingController();
  final _positioningController = TextEditingController();
  final _strengthsController = TextEditingController();
  final _cadenceNoteController = TextEditingController();
  late OrganizationSetupSubject _selectedSubject;
  late OrganizationSetupTeacher _selectedTeacher;
  final String _operationId = createOperationId();
  bool _busy = false;
  bool _showOptionalDetails = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.options.subjectsWithAvailableTeachers.first;
    final availableTeachers = widget.options.teachersForSubject(
      _selectedSubject.id,
    );
    _selectedTeacher = availableTeachers.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentCodeController.dispose();
    _gradeController.dispose();
    _classNameController.dispose();
    _campusController.dispose();
    _positioningController.dispose();
    _strengthsController.dispose();
    _cadenceNoteController.dispose();
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
        OrganizationStudentDraft(
          operationId: _operationId,
          name: _nameController.text.trim(),
          studentCode: _nullableText(_studentCodeController.text),
          grade: _nullableText(_gradeController.text),
          className: _nullableText(_classNameController.text),
          campus: _nullableText(_campusController.text),
          organizationSubjectId: _selectedSubject.id,
          teacherMembershipId: _selectedTeacher.membershipId,
          positioning: _nullableText(_positioningController.text),
          strengths: _nullableText(_strengthsController.text),
          cadenceNote: _nullableText(_cadenceNoteController.text),
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
    final message = organizationStudentSetupErrorMessage(error);
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
    final availableSubjects = widget.options.subjectsWithAvailableTeachers;
    final availableTeachers = widget.options.teachersForSubject(
      _selectedSubject.id,
    );
    return AlertDialog(
      title: const Text('添加学生'),
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
                  '先填写学生姓名、年级、服务学科和负责老师；保存后会一次完成建档和首个负责关系。其他资料需要时再展开填写。',
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
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  key: const Key('student-setup-grade-field'),
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
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<OrganizationSetupSubject>(
                  initialValue: _selectedSubject,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '服务学科 *'),
                  items: [
                    for (final subject in availableSubjects)
                      DropdownMenuItem(
                        value: subject,
                        child: Text(
                          subject.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (subject) {
                          if (subject != null) {
                            setState(() {
                              _selectedSubject = subject;
                              final availableTeachers = widget.options
                                  .teachersForSubject(subject.id);
                              _selectedTeacher = availableTeachers.first;
                            });
                          }
                        },
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<OrganizationSetupTeacher>(
                  key: ValueKey(_selectedSubject.id),
                  initialValue: _selectedTeacher,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '负责老师 *'),
                  items: [
                    for (final teacher in availableTeachers)
                      DropdownMenuItem(
                        value: teacher,
                        child: Text(
                          teacher.email.isEmpty
                              ? teacher.displayName
                              : '${teacher.displayName} · ${teacher.email}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (teacher) {
                          if (teacher != null) {
                            setState(() => _selectedTeacher = teacher);
                          }
                        },
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('student-setup-optional-toggle'),
                    onPressed: _busy
                        ? null
                        : () => setState(
                            () => _showOptionalDetails = !_showOptionalDetails,
                          ),
                    icon: Icon(
                      _showOptionalDetails
                          ? Icons.expand_less
                          : Icons.add_circle_outline,
                      size: 18,
                    ),
                    label: Text(_showOptionalDetails ? '收起补充信息' : '补充信息（可选）'),
                  ),
                ),
                AnimatedSize(
                  duration: AppMotion.effectiveDuration(context),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _showOptionalDetails
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '学生编号、班级、校区和学情背景都不是必填项；如果现在已知，可以一起保存。',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              key: const Key('student-setup-code-field'),
                              controller: _studentCodeController,
                              maxLength: 80,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: '学生编号',
                                hintText: '可选',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextFormField(
                              controller: _classNameController,
                              maxLength: 120,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: '班级',
                                hintText: '可选',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextFormField(
                              controller: _campusController,
                              maxLength: 120,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: '校区',
                                hintText: '可选',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              '学情背景（可选）',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextFormField(
                              controller: _positioningController,
                              maxLength: 2000,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: '当前定位',
                                hintText: '例如：函数基础需要持续巩固',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              controller: _strengthsController,
                              maxLength: 2000,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: '已有优势',
                                hintText: '例如：愿意复盘错题',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              controller: _cadenceNoteController,
                              maxLength: 160,
                              maxLines: 1,
                              decoration: const InputDecoration(
                                labelText: '跟进节奏',
                                hintText: '例如：每周一次',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
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
          key: const Key('student-setup-submit'),
          onPressed: _busy ? null : _submit,
          child: AnimatedSwitcher(
            duration: AppMotion.effectiveDuration(context, AppMotion.quick),
            child: _busy
                ? const SizedBox(
                    key: ValueKey<String>('student-setup-saving'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '添加学生',
                    key: ValueKey<String>('student-setup-ready'),
                  ),
          ),
        ),
      ],
    );
  }
}

String? _nullableText(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
