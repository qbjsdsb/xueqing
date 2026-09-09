import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../cloud/organization_management_repository.dart';

class OrganizationStudentRecordExportProfile {
  const OrganizationStudentRecordExportProfile({
    required this.studentId,
    required this.studentName,
    required this.profileId,
    required this.subjectName,
  });

  final String studentId;
  final String studentName;
  final String profileId;
  final String subjectName;
}

class OrganizationStudentRecordExportSelection {
  const OrganizationStudentRecordExportSelection({required this.profiles});

  final List<OrganizationStudentRecordExportProfile> profiles;

  int get studentCount =>
      profiles.map((profile) => profile.studentId).toSet().length;
}

class OrganizationStudentRecordExportDialog extends StatefulWidget {
  const OrganizationStudentRecordExportDialog({
    required this.students,
    super.key,
  });

  final List<OrganizationStudentRecord> students;

  @override
  State<OrganizationStudentRecordExportDialog> createState() =>
      _OrganizationStudentRecordExportDialogState();
}

class _OrganizationStudentRecordExportDialogState
    extends State<OrganizationStudentRecordExportDialog> {
  final Set<String> _selectedProfileIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<OrganizationStudentRecord> get _students {
    final students = widget.students
        .where(
          (student) =>
              student.isActive &&
              !student.isMerged &&
              student.subjectServices.any((service) => service.isActive),
        )
        .toList(growable: false);
    students.sort(
      (left, right) => left.studentName.compareTo(right.studentName),
    );
    return students;
  }

  List<OrganizationStudentRecord> get _visibleStudents {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _students;
    return _students
        .where(
          (student) =>
              student.studentName.toLowerCase().contains(query) ||
              (student.studentCode ?? '').toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  List<OrganizationStudentSubjectService> _activeServices(
    OrganizationStudentRecord student,
  ) {
    final services = student.subjectServices
        .where((service) => service.isActive)
        .toList(growable: false);
    services.sort(
      (left, right) => left.subjectName.compareTo(right.subjectName),
    );
    return services;
  }

  void _toggleStudent(OrganizationStudentRecord student) {
    final profileIds = _activeServices(student)
        .map((service) => service.profileId)
        .toList(growable: false);
    final allSelected = profileIds.every(_selectedProfileIds.contains);
    setState(() {
      if (allSelected) {
        _selectedProfileIds.removeAll(profileIds);
      } else {
        _selectedProfileIds.addAll(profileIds);
      }
    });
  }

  void _toggleProfile(String profileId) {
    setState(() {
      if (!_selectedProfileIds.add(profileId)) {
        _selectedProfileIds.remove(profileId);
      }
    });
  }

  void _selectVisible() {
    setState(() {
      _selectedProfileIds.addAll(
        _visibleStudents.expand(
          (student) =>
              _activeServices(student).map((service) => service.profileId),
        ),
      );
    });
  }

  OrganizationStudentRecordExportSelection _selection() {
    final profiles = <OrganizationStudentRecordExportProfile>[];
    for (final student in _students) {
      for (final service in _activeServices(student)) {
        if (!_selectedProfileIds.contains(service.profileId)) continue;
        profiles.add(
          OrganizationStudentRecordExportProfile(
            studentId: student.studentId,
            studentName: student.studentName,
            profileId: service.profileId,
            subjectName: service.subjectName,
          ),
        );
      }
    }
    return OrganizationStudentRecordExportSelection(
      profiles: List<OrganizationStudentRecordExportProfile>.unmodifiable(
        profiles,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final students = _students;
    final visibleStudents = _visibleStudents;
    final selectedStudentCount = students
        .where(
          (student) => _activeServices(
            student,
          ).any((service) => _selectedProfileIds.contains(service.profileId)),
        )
        .length;

    return AlertDialog(
      title: const Text('导出学生记录'),
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.62,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '勾选需要导出的学生和学科。每个所选学科都会导出完整历史记录，并保留真实记录老师。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('student-record-export-search'),
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '搜索学生姓名或编号',
                  prefixIcon: const Icon(Icons.search_outlined),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除搜索',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xxs,
                children: [
                  Text(
                    '已选 $selectedStudentCount 名学生 · ${_selectedProfileIds.length} 个学科',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Wrap(
                    spacing: AppSpacing.xxs,
                    children: [
                      TextButton(
                        key: const Key('student-record-export-select-all'),
                        onPressed: visibleStudents.isEmpty
                            ? null
                            : _selectVisible,
                        child: Text(
                          _query.trim().isEmpty ? '全选' : '全选当前结果',
                        ),
                      ),
                      TextButton(
                        key: const Key('student-record-export-clear'),
                        onPressed: _selectedProfileIds.isEmpty
                            ? null
                            : () => setState(_selectedProfileIds.clear),
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: AppSpacing.md),
              Flexible(
                child: students.isEmpty
                    ? const Center(child: Text('当前没有可导出的学生学科记录。'))
                    : visibleStudents.isEmpty
                    ? const Center(child: Text('没有找到匹配的学生。'))
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: visibleStudents.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final student = visibleStudents[index];
                          final services = _activeServices(student);
                          final selectedCount = services
                              .where(
                                (service) => _selectedProfileIds.contains(
                                  service.profileId,
                                ),
                              )
                              .length;
                          final bool? studentValue = selectedCount == 0
                              ? false
                              : selectedCount == services.length
                              ? true
                              : null;
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.xs,
                                AppSpacing.xxs,
                                AppSpacing.sm,
                                AppSpacing.sm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CheckboxListTile(
                                    key: Key(
                                      'student-record-export-student-${student.studentId}',
                                    ),
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    tristate: true,
                                    value: studentValue,
                                    title: Text(student.studentName),
                                    subtitle: Text('${services.length} 个可导出学科'),
                                    onChanged: (_) => _toggleStudent(student),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: AppSpacing.sm,
                                    ),
                                    child: Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xs,
                                      children: [
                                        for (final service in services)
                                          FilterChip(
                                            key: Key(
                                              'student-record-export-profile-${service.profileId}',
                                            ),
                                            label: Text(service.subjectName),
                                            selected: _selectedProfileIds
                                                .contains(service.profileId),
                                            onSelected: (_) => _toggleProfile(
                                              service.profileId,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
        FilledButton.icon(
          key: const Key('student-record-export-confirm'),
          onPressed: _selectedProfileIds.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selection()),
          icon: const Icon(Icons.download_outlined),
          label: const Text('导出'),
        ),
      ],
    );
  }
}
