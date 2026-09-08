part of 'organization_management_page.dart';

enum _LearningExportMode { studentSubject, teacher }

class _OrganizationLearningExportDialog extends StatefulWidget {
  const _OrganizationLearningExportDialog({
    required this.organizationId,
    required this.snapshot,
    required this.repository,
  });

  final String organizationId;
  final _OrganizationManagementSnapshot snapshot;
  final LearningExportRepository repository;

  @override
  State<_OrganizationLearningExportDialog> createState() =>
      _OrganizationLearningExportDialogState();
}

class _OrganizationLearningExportDialogState
    extends State<_OrganizationLearningExportDialog> {
  _LearningExportMode _mode = _LearningExportMode.studentSubject;
  String? _studentId;
  String? _profileId;
  String? _membershipId;
  bool _exporting = false;
  String? _error;

  List<OrganizationStudentRecord> get _students {
    final result = widget.snapshot.students
        .where((student) => student.subjectServices.isNotEmpty)
        .toList(growable: false);
    result.sort((left, right) => left.studentName.compareTo(right.studentName));
    return result;
  }

  List<OrganizationMember> get _teachers {
    final result = widget.snapshot.members.where((member) {
      return member.roles.any(
        (role) =>
            role == 'teacher' || role == 'org_owner' || role == 'org_admin',
      );
    }).toList(growable: false);
    result.sort((left, right) => _memberName(left).compareTo(_memberName(right)));
    return result;
  }

  OrganizationStudentRecord? get _selectedStudent {
    final id = _studentId;
    if (id == null) return null;
    for (final student in _students) {
      if (student.studentId == id) return student;
    }
    return null;
  }

  List<OrganizationStudentSubjectService> get _selectedStudentServices {
    final student = _selectedStudent;
    if (student == null) return const <OrganizationStudentSubjectService>[];
    final result = student.subjectServices.toList(growable: false);
    result.sort((left, right) {
      if (left.isActive != right.isActive) return left.isActive ? -1 : 1;
      return left.subjectName.compareTo(right.subjectName);
    });
    return result;
  }

  OrganizationStudentSubjectService? get _selectedService {
    final id = _profileId;
    if (id == null) return null;
    for (final service in _selectedStudentServices) {
      if (service.profileId == id) return service;
    }
    return null;
  }

  OrganizationMember? get _selectedTeacher {
    final id = _membershipId;
    if (id == null) return null;
    for (final member in _teachers) {
      if (member.membershipId == id) return member;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final students = _students;
    if (students.isNotEmpty) {
      _studentId = students.first.studentId;
      final services = students.first.subjectServices.toList(growable: false)
        ..sort((left, right) {
          if (left.isActive != right.isActive) return left.isActive ? -1 : 1;
          return left.subjectName.compareTo(right.subjectName);
        });
      if (services.isNotEmpty) _profileId = services.first.profileId;
    }
    final teachers = _teachers;
    if (teachers.isNotEmpty) _membershipId = teachers.first.membershipId;
  }

  Map<String, String> _teacherNames() {
    return <String, String>{
      for (final member in widget.snapshot.members)
        member.membershipId: _memberName(member),
    };
  }

  String _memberName(OrganizationMember member) {
    final displayName = member.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return member.email.trim().isEmpty ? '未命名老师' : member.email.trim();
  }

  String _serviceLabel(OrganizationStudentSubjectService service) {
    final suffix = switch (service.status) {
      'inactive' => '（已结束）',
      'archived' => '（已归档）',
      _ => '',
    };
    return '${service.subjectName}$suffix';
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      late final LearningHistoryExportData data;
      if (_mode == _LearningExportMode.studentSubject) {
        final student = _selectedStudent;
        final service = _selectedService;
        if (student == null || service == null) {
          setState(() => _error = '请先选择学员和学科。');
          return;
        }
        data = await widget.repository.loadStudentSubjectHistory(
          organizationId: widget.organizationId,
          profileId: service.profileId,
          studentName: student.studentName,
          subjectName: service.subjectName,
          teacherNamesByMembershipId: _teacherNames(),
        );
      } else {
        final teacher = _selectedTeacher;
        if (teacher == null) {
          setState(() => _error = '请先选择老师。');
          return;
        }
        data = await widget.repository.loadTeacherHistory(
          organizationId: widget.organizationId,
          membershipId: teacher.membershipId,
          teacherName: _memberName(teacher),
          teacherNamesByMembershipId: _teacherNames(),
        );
      }
      final bytes = const LearningHistoryWorkbookBuilder().build(data);
      final savedPath = await FileSaver.instance.saveAs(
        name: data.suggestedFileName,
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (!mounted || savedPath == null) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出 ${data.records.length} 条记录。')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _describeExportError(error));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _describeExportError(Object error) {
    final detail = error.toString().toLowerCase();
    if (detail.contains('permission') ||
        detail.contains('row-level') ||
        detail.contains('rls')) {
      return '当前账号无权导出这个范围的学情记录。';
    }
    if (detail.contains('network') ||
        detail.contains('socket') ||
        detail.contains('timeout')) {
      return '网络暂时不可用，未生成不完整的导出文件；请稍后重试。';
    }
    return '导出失败，没有改动任何学情记录。请重试。';
  }

  @override
  Widget build(BuildContext context) {
    final students = _students;
    final services = _selectedStudentServices;
    final teachers = _teachers;
    return AlertDialog(
      title: const Text('导出学情记录'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '导出的是教师可读的完整记录，不是数据库日志；一次教学操作只保留一条主要记录。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<_LearningExportMode>(
                segments: const <ButtonSegment<_LearningExportMode>>[
                  ButtonSegment<_LearningExportMode>(
                    value: _LearningExportMode.studentSubject,
                    icon: Icon(Icons.school_outlined),
                    label: Text('学员 + 学科'),
                  ),
                  ButtonSegment<_LearningExportMode>(
                    value: _LearningExportMode.teacher,
                    icon: Icon(Icons.person_outline),
                    label: Text('单独老师'),
                  ),
                ],
                selected: <_LearningExportMode>{_mode},
                showSelectedIcon: false,
                onSelectionChanged: _exporting
                    ? null
                    : (selection) {
                        if (selection.isEmpty) return;
                        setState(() {
                          _mode = selection.first;
                          _error = null;
                        });
                      },
              ),
              const SizedBox(height: AppSpacing.md),
              if (_mode == _LearningExportMode.studentSubject) ...[
                DropdownButtonFormField<String>(
                  initialValue: _studentId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '学员'),
                  items: [
                    for (final student in students)
                      DropdownMenuItem<String>(
                        value: student.studentId,
                        child: Text(student.studentName),
                      ),
                  ],
                  onChanged: _exporting
                      ? null
                      : (value) {
                          setState(() {
                            _studentId = value;
                            final nextServices = _selectedStudentServices;
                            _profileId = nextServices.isEmpty
                                ? null
                                : nextServices.first.profileId;
                            _error = null;
                          });
                        },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  key: ValueKey('export-subject-$_studentId'),
                  initialValue: services.any(
                    (service) => service.profileId == _profileId,
                  )
                      ? _profileId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '学科'),
                  items: [
                    for (final service in services)
                      DropdownMenuItem<String>(
                        value: service.profileId,
                        child: Text(_serviceLabel(service)),
                      ),
                  ],
                  onChanged: _exporting
                      ? null
                      : (value) => setState(() {
                          _profileId = value;
                          _error = null;
                        }),
                ),
              ] else
                DropdownButtonFormField<String>(
                  initialValue: _membershipId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '老师'),
                  items: [
                    for (final teacher in teachers)
                      DropdownMenuItem<String>(
                        value: teacher.membershipId,
                        child: Text(_memberName(teacher)),
                      ),
                  ],
                  onChanged: _exporting
                      ? null
                      : (value) => setState(() {
                          _membershipId = value;
                          _error = null;
                        }),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Excel 包含：发生时间、学员、学科、跟进问题、记录类型、具体内容、检查结果、下一步、记录老师、附件说明和当前状态。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _exporting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _exporting ? null : _export,
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          label: Text(_exporting ? '正在生成…' : '导出 Excel'),
        ),
      ],
    );
  }
}
