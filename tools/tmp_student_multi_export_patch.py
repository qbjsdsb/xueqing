from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Expected anchor not found in {path}: {old[:120]!r}")
    file_path.write_text(text.replace(old, new, 1), encoding="utf-8")


# Organization management dependency wiring.
replace_once(
    "lib/features/organization_management/presentation/organization_management_page.dart",
    "import '../../../cloud/teacher_learning_record_repository.dart';",
    "import '../../../cloud/student_learning_record_repository.dart';\n"
    "import '../../../cloud/teacher_learning_record_repository.dart';",
)
replace_once(
    "lib/features/organization_management/presentation/organization_management_page.dart",
    "import 'organization_student_edit_dialog.dart';",
    "import 'organization_student_edit_dialog.dart';\n"
    "import 'organization_student_record_export_dialog.dart';",
)
replace_once(
    "lib/features/organization_management/presentation/organization_management_page.dart",
    "    this.provisioningRepository,\n    this.teacherLearningRecordRepository,\n    super.key,",
    "    this.provisioningRepository,\n"
    "    this.teacherLearningRecordRepository,\n"
    "    this.studentLearningRecordRepository,\n"
    "    super.key,",
)
replace_once(
    "lib/features/organization_management/presentation/organization_management_page.dart",
    "  final TeacherLearningRecordRepository? teacherLearningRecordRepository;\n",
    "  final TeacherLearningRecordRepository? teacherLearningRecordRepository;\n"
    "  final StudentLearningRecordRepository? studentLearningRecordRepository;\n",
)
replace_once(
    "lib/features/organization_management/presentation/organization_management_page.dart",
    "                  final canExportTeacherRecords =\n"
    "                      widget.teacherLearningRecordRepository != null &&\n"
    "                      widget.roles.any(\n"
    "                        (role) => role == 'org_owner' || role == 'org_admin',\n"
    "                      );\n",
    "                  final canExportTeacherRecords =\n"
    "                      widget.teacherLearningRecordRepository != null &&\n"
    "                      widget.roles.any(\n"
    "                        (role) => role == 'org_owner' || role == 'org_admin',\n"
    "                      );\n"
    "                  final canExportStudentRecords =\n"
    "                      widget.studentLearningRecordRepository != null &&\n"
    "                      widget.roles.any(\n"
    "                        (role) => role == 'org_owner' || role == 'org_admin',\n"
    "                      );\n",
)
replace_once(
    "lib/features/organization_management/presentation/organization_management_page.dart",
    "                        onExportTeacherRecords: canExportTeacherRecords\n"
    "                            ? _exportTeacherRecords\n"
    "                            : null,\n",
    "                        onExportTeacherRecords: canExportTeacherRecords\n"
    "                            ? _exportTeacherRecords\n"
    "                            : null,\n"
    "                        onExportStudentRecords: canExportStudentRecords\n"
    "                            ? _exportStudentRecords\n"
    "                            : null,\n",
)

# Pass the already-created student export repository into management.
replace_once(
    "lib/features/teacher_workspace/presentation/teacher_workspace_page.dart",
    "      teacherLearningRecordRepository: widget.teacherLearningRecordRepository,\n"
    "      organizationId: organizationId,",
    "      teacherLearningRecordRepository: widget.teacherLearningRecordRepository,\n"
    "      studentLearningRecordRepository: widget.studentLearningRecordRepository,\n"
    "      organizationId: organizationId,",
)

# Management overview: expose student export only in the student area.
replace_once(
    "lib/features/organization_management/presentation/organization_management_areas.dart",
    "    this.onProvisionInvitation,\n    this.onExportTeacherRecords,\n    this.onEditMemberName,",
    "    this.onProvisionInvitation,\n"
    "    this.onExportTeacherRecords,\n"
    "    this.onExportStudentRecords,\n"
    "    this.onEditMemberName,",
)
replace_once(
    "lib/features/organization_management/presentation/organization_management_areas.dart",
    "  final Future<void> Function()? onExportTeacherRecords;\n",
    "  final Future<void> Function()? onExportTeacherRecords;\n"
    "  final Future<void> Function()? onExportStudentRecords;\n",
)
replace_once(
    "lib/features/organization_management/presentation/organization_management_areas.dart",
    "            action: FilledButton.icon(\n"
    "              onPressed: widget.busy ? null : widget.onAddStudent,\n"
    "              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),\n"
    "              label: const Text('添加学生'),\n"
    "            ),",
    "            action: Wrap(\n"
    "              spacing: AppSpacing.xs,\n"
    "              runSpacing: AppSpacing.xs,\n"
    "              children: [\n"
    "                if (widget.onExportStudentRecords != null)\n"
    "                  OutlinedButton.icon(\n"
    "                    key: const Key('management-export-student-records'),\n"
    "                    onPressed: widget.busy\n"
    "                        ? null\n"
    "                        : widget.onExportStudentRecords,\n"
    "                    icon: const Icon(Icons.download_outlined, size: 18),\n"
    "                    label: const Text('导出学生记录'),\n"
    "                  ),\n"
    "                FilledButton.icon(\n"
    "                  onPressed: widget.busy ? null : widget.onAddStudent,\n"
    "                  icon: const Icon(\n"
    "                    Icons.person_add_alt_1_outlined,\n"
    "                    size: 18,\n"
    "                  ),\n"
    "                  label: const Text('添加学生'),\n"
    "                ),\n"
    "              ],\n"
    "            ),",
)

# Export action: reuse the provenance-aware one-profile RPC in bounded batches.
learning_actions_path = "lib/features/organization_management/presentation/organization_management_learning_actions.dart"
learning_actions = Path(learning_actions_path).read_text(encoding="utf-8")
anchor = "mixin _OrganizationManagementLearningActions on _OrganizationManagementCore {\n"
if anchor not in learning_actions:
    raise SystemExit("Learning actions mixin anchor not found")
student_export_method = r'''mixin _OrganizationManagementLearningActions on _OrganizationManagementCore {
  Future<void> _exportStudentRecords() async {
    if (_busy) return;
    final repository = widget.studentLearningRecordRepository;
    if (repository == null) return;

    try {
      final snapshot = await _snapshotFuture;
      if (!mounted) return;
      final hasExportableProfile = snapshot.students.any(
        (student) =>
            student.isActive &&
            !student.isMerged &&
            student.subjectServices.any((service) => service.isActive),
      );
      if (!hasExportableProfile) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前没有可导出的学生学科记录。')),
        );
        return;
      }

      final selection = await showDialog<OrganizationStudentRecordExportSelection>(
        context: context,
        builder: (context) => OrganizationStudentRecordExportDialog(
          students: snapshot.students,
        ),
      );
      if (!mounted || selection == null || selection.profiles.isEmpty) return;

      setState(() {
        _busy = true;
        _errorMessage = null;
      });

      final records = <StudentLearningRecord>[];
      const requestBatchSize = 4;
      for (var start = 0; start < selection.profiles.length; start += requestBatchSize) {
        final end = (start + requestBatchSize).clamp(
          0,
          selection.profiles.length,
        );
        final batch = selection.profiles.sublist(start, end);
        final batchRecords = await Future.wait([
          for (final profile in batch)
            repository.listStudentSubjectRecords(profileId: profile.profileId),
        ]);
        for (final profileRecords in batchRecords) {
          records.addAll(profileRecords);
        }
      }
      if (!mounted) return;
      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所选学生和学科还没有可导出的学情记录。')),
        );
        return;
      }

      final rows = LearningRecordExport.rowsForStudentRecords(records);
      final savedPath = await LearningRecordExport.saveAsXlsx(
        fileNameWithoutExtension: LearningRecordExport.studentBatchFileName(
          studentCount: selection.studentCount,
          profileCount: selection.profiles.length,
        ),
        rows: rows,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedPath == null
                ? '已取消导出。'
                : '已生成 ${selection.studentCount} 名学生、${selection.profiles.length} 个学科的学情记录表。',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            studentLearningRecordExportErrorMessage(error) ??
            '导出失败，请检查网络和账号状态后重试。';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

'''
Path(learning_actions_path).write_text(
    learning_actions.replace(anchor, student_export_method, 1),
    encoding="utf-8",
)

# Stable, concise batch filename.
replace_once(
    "lib/export/learning_record_export.dart",
    "  static String teacherFileName(String teacherName, {DateTime? exportedAt}) {\n"
    "    final now = exportedAt ?? DateTime.now();\n"
    "    return sanitizeFileName('${teacherName}_教学记录_${_formatDate(now)}');\n"
    "  }\n",
    "  static String teacherFileName(String teacherName, {DateTime? exportedAt}) {\n"
    "    final now = exportedAt ?? DateTime.now();\n"
    "    return sanitizeFileName('${teacherName}_教学记录_${_formatDate(now)}');\n"
    "  }\n\n"
    "  static String studentBatchFileName({\n"
    "    required int studentCount,\n"
    "    required int profileCount,\n"
    "    DateTime? exportedAt,\n"
    "  }) {\n"
    "    final now = exportedAt ?? DateTime.now();\n"
    "    return sanitizeFileName(\n"
    "      '学生学情记录_${studentCount}人_${profileCount}科_${_formatDate(now)}',\n"
    "    );\n"
    "  }\n",
)

# Selection dialog deliberately works only with currently active student-subject
# profiles because the existing teaching gate is the source of truth.
Path(
    "lib/features/organization_management/presentation/organization_student_record_export_dialog.dart"
).write_text(
    r'''import 'package:flutter/material.dart';

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

  int get studentCount => profiles.map((profile) => profile.studentId).toSet().length;
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

  List<OrganizationStudentRecord> get _students {
    final students = widget.students
        .where(
          (student) =>
              student.isActive &&
              !student.isMerged &&
              student.subjectServices.any((service) => service.isActive),
        )
        .toList(growable: false);
    students.sort((left, right) => left.studentName.compareTo(right.studentName));
    return students;
  }

  List<OrganizationStudentSubjectService> _activeServices(
    OrganizationStudentRecord student,
  ) {
    final services = student.subjectServices
        .where((service) => service.isActive)
        .toList(growable: false);
    services.sort((left, right) => left.subjectName.compareTo(right.subjectName));
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

  void _selectAll() {
    setState(() {
      _selectedProfileIds
        ..clear()
        ..addAll(
          _students.expand(
            (student) => _activeServices(student).map((service) => service.profileId),
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
      profiles: List<OrganizationStudentRecordExportProfile>.unmodifiable(profiles),
    );
  }

  @override
  Widget build(BuildContext context) {
    final students = _students;
    final selectedStudentCount = students
        .where(
          (student) => _activeServices(student).any(
            (service) => _selectedProfileIds.contains(service.profileId),
          ),
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
              Row(
                children: [
                  Text(
                    '已选 $selectedStudentCount 名学生 · ${_selectedProfileIds.length} 个学科',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('student-record-export-select-all'),
                    onPressed: students.isEmpty ? null : _selectAll,
                    child: const Text('全选'),
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
              const Divider(height: AppSpacing.md),
              Flexible(
                child: students.isEmpty
                    ? const Center(child: Text('当前没有可导出的学生学科记录。'))
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: students.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final student = students[index];
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
                                color: Theme.of(context).colorScheme.outlineVariant,
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
                                            selected: _selectedProfileIds.contains(
                                              service.profileId,
                                            ),
                                            onSelected: (_) =>
                                                _toggleProfile(service.profileId),
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
''',
    encoding="utf-8",
)

# Focused widget test for whole-student selection plus per-subject deselection.
Path("test/features/organization_student_record_export_dialog_test.dart").write_text(
    r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/organization_management_repository.dart';
import 'package:xueqing/features/organization_management/presentation/organization_student_record_export_dialog.dart';

void main() {
  testWidgets('selects a student, then allows one subject to be excluded', (
    tester,
  ) async {
    OrganizationStudentRecordExportSelection? selection;
    final student = OrganizationStudentRecord(
      studentId: 'student-1',
      studentName: '林同学',
      studentCode: 'S001',
      status: 'active',
      version: 1,
      grade: '初三',
      className: null,
      campus: null,
      startsOn: null,
      endsOn: null,
      subjectNames: const ['语文', '数学'],
      subjectServices: const [
        OrganizationStudentSubjectService(
          profileId: 'profile-chinese',
          organizationSubjectId: 'subject-chinese',
          subjectName: '语文',
          status: 'active',
          version: 1,
        ),
        OrganizationStudentSubjectService(
          profileId: 'profile-math',
          organizationSubjectId: 'subject-math',
          subjectName: '数学',
          status: 'active',
          version: 1,
        ),
        OrganizationStudentSubjectService(
          profileId: 'profile-history',
          organizationSubjectId: 'subject-history',
          subjectName: '历史学科',
          status: 'inactive',
          version: 2,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                selection =
                    await showDialog<OrganizationStudentRecordExportSelection>(
                      context: context,
                      builder: (context) => OrganizationStudentRecordExportDialog(
                        students: [student],
                      ),
                    );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('语文'), findsOneWidget);
    expect(find.text('数学'), findsOneWidget);
    expect(find.text('历史学科'), findsNothing);

    await tester.tap(
      find.byKey(const Key('student-record-export-student-student-1')),
    );
    await tester.pump();
    expect(find.text('已选 1 名学生 · 2 个学科'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('student-record-export-profile-profile-math')),
    );
    await tester.pump();
    expect(find.text('已选 1 名学生 · 1 个学科'), findsOneWidget);

    await tester.tap(find.byKey(const Key('student-record-export-confirm')));
    await tester.pumpAndSettle();

    expect(selection, isNotNull);
    expect(selection!.studentCount, 1);
    expect(selection!.profiles, hasLength(1));
    expect(selection!.profiles.single.profileId, 'profile-chinese');
    expect(selection!.profiles.single.subjectName, '语文');
  });
}
''',
    encoding="utf-8",
)

# Pure filename contract for the merged workbook.
Path("test/export/student_batch_file_name_test.dart").write_text(
    r'''import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/export/learning_record_export.dart';

void main() {
  test('student batch export filename is concise and deterministic', () {
    expect(
      LearningRecordExport.studentBatchFileName(
        studentCount: 2,
        profileCount: 3,
        exportedAt: DateTime(2026, 9, 9),
      ),
      '学生学情记录_2人_3科_2026-09-09',
    );
  });
}
''',
    encoding="utf-8",
)
